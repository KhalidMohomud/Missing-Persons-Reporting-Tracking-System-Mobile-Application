import { db } from "../firebase/admin.js";
import admin from "firebase-admin";
import { isAdminRequest, resolveRequestIdentity, resolveReportById } from "./access.js";
import { notifyNearbyAlert } from "../services/push_notifications.js";

const alertsRef = db.collection("alerts");

const toMillis = (value) => {
    if (!value) return 0;
    if (typeof value?.toDate === "function") {
        return value.toDate().getTime();
    }
    if (typeof value?._seconds === "number") {
        return value._seconds * 1000;
    }
    return 0;
};

const normalizeAudience = (value) => {
    const cleaned = String(value || "").trim().toLowerCase();
    if (cleaned === "public") return "public";
    if (cleaned === "owner_admin") return "owner_admin";
    return null;
};

const buildReportSummary = (reportInfo) => {
    if (!reportInfo?.report) return null;

    const report = reportInfo.report;
    if (reportInfo.type === "missing") {
        return {
            type: "missing",
            title: report.fullName || "Missing person",
            locationLabel: report.lastSeenLocation || "Unknown location",
            photo: report.photo || "",
            age: report.age ?? null,
            gender: report.gender || "",
            dateLabel: report.lastSeenDate || "",
            report,
        };
    }

    return {
        type: "found",
        title: "Found person",
        locationLabel: report.locationFound || "Unknown location",
        photo: report.photo || "",
        age: report.estimatedAge ?? null,
        gender: report.gender || "",
        dateLabel: report.createdAt || "",
        report,
    };
};

const enrichAlert = async (alert) => {
    const reportInfo = await resolveReportById(alert.reportId, alert.reportType);
    const reportSummary = buildReportSummary(reportInfo);
    return {
        ...alert,
        reportSummary,
    };
};

const enrichAlerts = async (alerts) => {
    if (!alerts.length) return alerts;
    return Promise.all(alerts.map((alert) => enrichAlert(alert)));
};

export const createAlert = async (req, res) => {
    try {
        const isAdmin = await isAdminRequest(req);
        if (!isAdmin) {
            return res.status(403).json({ error: "Admin only" });
        }

        const {
            reportId,
            reportType,
            alertMessage,
            alertLat,
            alertLng,
            radiusKm,
            audience,
            targetUserId,
            source,
            tipId,
        } = req.body;

        if (!reportId || !alertMessage || alertLat === undefined || alertLng === undefined) {
            return res.status(400).json({ error: "Missing required fields" });
        }

        const parsedLat = Number(alertLat);
        const parsedLng = Number(alertLng);
        const parsedRadius = Number(radiusKm);

        if (!Number.isFinite(parsedLat) || !Number.isFinite(parsedLng)) {
            return res.status(400).json({ error: "Invalid alertLat/alertLng" });
        }

        if (!Number.isFinite(parsedRadius) || parsedRadius <= 0) {
            return res.status(400).json({ error: "Invalid radiusKm" });
        }

        const payload = {
            reportId: String(reportId).trim(),
            reportType: reportType ? String(reportType).trim().toLowerCase() : null,
            alertMessage: String(alertMessage).trim(),
            alertLat: parsedLat,
            alertLng: parsedLng,
            radiusKm: parsedRadius,
            audience: normalizeAudience(audience) || "public",
            targetUserId: targetUserId ? String(targetUserId).trim() : null,
            source: source ? String(source).trim().toLowerCase() : "manual",
            tipId: tipId ? String(tipId).trim() : null,
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        const created = await alertsRef.add(payload);

        if (payload.audience === "public") {
            try {
                await notifyNearbyAlert({
                    reportId: payload.reportId,
                    reportType: payload.reportType,
                    alertMessage: payload.alertMessage,
                    alertLat: payload.alertLat,
                    alertLng: payload.alertLng,
                    radiusKm: payload.radiusKm,
                });
            } catch (pushErr) {
                console.error("Nearby alert push error:", pushErr);
            }
        }

        return res.status(201).json({
            success: true,
            alertId: created.id,
            data: { id: created.id, ...payload },
        });
    } catch (err) {
        console.error("Create alert error:", err);
        return res.status(500).json({ error: "Failed to create alert" });
    }
};

export const getAlerts = async (req, res) => {
    try {
        const identity = resolveRequestIdentity(req);
        if (!identity.userId && !identity.email) {
            return res.status(401).json({ error: "Login required" });
        }

        const isAdmin = await isAdminRequest(req);
        const { reportId } = req.query || {};

        let alerts = [];

        if (isAdmin) {
            let snapshot;
            if (reportId) {
                snapshot = await alertsRef
                    .where("reportId", "==", String(reportId).trim())
                    .get();
            } else {
                snapshot = await alertsRef.orderBy("sentAt", "desc").get();
            }
            if (!snapshot.empty) {
                alerts = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
            }
        } else {
            const ownedQuery = alertsRef
                .where("targetUserId", "==", identity.userId);
            const ownedByEmailQuery = identity.email
                ? alertsRef.where("targetUserId", "==", identity.email)
                : null;
            const publicQuery = alertsRef.where("audience", "==", "public");

            const snapshots = await Promise.all([
                identity.userId ? ownedQuery.get() : Promise.resolve(null),
                ownedByEmailQuery ? ownedByEmailQuery.get() : Promise.resolve(null),
                publicQuery.get(),
            ]);

            const [ownedSnap, ownedEmailSnap, publicSnap] = snapshots;

            const byId = new Map();
            if (ownedSnap && !ownedSnap.empty) {
                ownedSnap.docs.forEach((doc) => {
                    byId.set(doc.id, { id: doc.id, ...doc.data() });
                });
            }
            if (ownedEmailSnap && !ownedEmailSnap.empty) {
                ownedEmailSnap.docs.forEach((doc) => {
                    byId.set(doc.id, { id: doc.id, ...doc.data() });
                });
            }
            if (publicSnap && !publicSnap.empty) {
                publicSnap.docs.forEach((doc) => {
                    byId.set(doc.id, { id: doc.id, ...doc.data() });
                });
            }

            alerts = Array.from(byId.values());
        }

        if (alerts.length > 1) {
            alerts.sort((a, b) => toMillis(b.sentAt) - toMillis(a.sentAt));
        }

        alerts = await enrichAlerts(alerts);

        return res.status(200).json({ success: true, count: alerts.length, data: alerts });
    } catch (err) {
        console.error("Get alerts error:", err);
        return res.status(500).json({ error: "Failed to fetch alerts" });
    }
};
