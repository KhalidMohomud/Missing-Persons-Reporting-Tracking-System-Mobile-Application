import { db } from "../firebase/admin.js";
import admin from "firebase-admin";
import {
    isAdminRequest,
    normalizeReportType,
    ownerMatchesIdentity,
    resolveReportById,
    resolveRequestIdentity,
} from "./access.js";

const tipsRef = db.collection("tips");
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

const resolveOwnerId = (value) => {
    const cleaned = String(value || "").trim();
    if (!cleaned) return null;
    if (cleaned.toLowerCase() === "anonymous") return null;
    return cleaned;
};

const resolveAlertCoords = (tipLat, tipLng, reportInfo) => {
    if (Number.isFinite(tipLat) && Number.isFinite(tipLng)) {
        return { lat: tipLat, lng: tipLng };
    }
    if (reportInfo?.type === "found") {
        const reportLat = Number(reportInfo.report?.foundLat);
        const reportLng = Number(reportInfo.report?.foundLng);
        if (Number.isFinite(reportLat) && Number.isFinite(reportLng)) {
            return { lat: reportLat, lng: reportLng };
        }
    }
    return null;
};

export const createTip = async (req, res) => {
    try {
        const {
            reportId,
            reportType,
            message,
            location,
            anonymous,
            tipLat,
            tipLng,
        } = req.body;

        if (!reportId || !message || !location) {
            return res.status(400).json({ error: "Missing required fields" });
        }

        const identity = resolveRequestIdentity(req);
        const isAnonymous = anonymous === undefined ? true : Boolean(anonymous);
        if (!isAnonymous && !identity.userId && !identity.email) {
            return res.status(401).json({ error: "Login required for non-anonymous tip" });
        }
        const senderId = isAnonymous ? null : (identity.userId || identity.email || null);

        const normalizedType = normalizeReportType(reportType);
        const reportInfo = await resolveReportById(reportId, normalizedType);
        if (!reportInfo) {
            return res.status(404).json({ error: "Report not found" });
        }

        const ownerId = resolveOwnerId(reportInfo.report?.reportedBy);

        const payload = {
            reportId: String(reportId).trim(),
            reportType: reportInfo.type,
            reportOwnerId: ownerId,
            message: String(message).trim(),
            location: String(location).trim(),
            anonymous: isAnonymous,
            senderId,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        if (tipLat !== undefined && tipLng !== undefined) {
            const parsedLat = Number(tipLat);
            const parsedLng = Number(tipLng);
            if (Number.isFinite(parsedLat) && Number.isFinite(parsedLng)) {
                payload.tipLat = parsedLat;
                payload.tipLng = parsedLng;
            }
        }

        const created = await tipsRef.add(payload);
        const tipId = created.id;

        let alertId = null;
        try {
            const coords = resolveAlertCoords(payload.tipLat, payload.tipLng, reportInfo);
            if (coords) {
                const alertMessage = `New tip received for this ${reportInfo.type} report.`;
                const alertPayload = {
                    reportId: payload.reportId,
                    reportType: reportInfo.type,
                    alertMessage,
                    alertLat: coords.lat,
                    alertLng: coords.lng,
                    radiusKm: 5,
                    audience: "owner_admin",
                    targetUserId: ownerId,
                    tipId,
                    source: "tip",
                    createdBy: senderId,
                    sentAt: admin.firestore.FieldValue.serverTimestamp(),
                };
                const alertCreated = await alertsRef.add(alertPayload);
                alertId = alertCreated.id;
                await tipsRef.doc(tipId).set({ alertId }, { merge: true });
            }
        } catch (err) {
            console.error("Create tip alert error:", err);
        }

        return res.status(201).json({
            success: true,
            tipId,
            alertId,
            data: { id: tipId, alertId, ...payload },
        });
    } catch (err) {
        console.error("Create tip error:", err);
        return res.status(500).json({ error: "Failed to create tip" });
    }
};

export const getTips = async (req, res) => {
    try {
        const identity = resolveRequestIdentity(req);
        if (!identity.userId && !identity.email) {
            return res.status(401).json({ error: "Login required" });
        }

        const { reportId, reportType } = req.query || {};
        const isAdmin = await isAdminRequest(req);

        if (!reportId) {
            if (!isAdmin) {
                return res.status(403).json({ error: "Admin access required" });
            }
            const snapshot = await tipsRef.orderBy("createdAt", "desc").get();
            if (snapshot.empty) {
                return res.status(200).json({ success: true, count: 0, data: [] });
            }
            const tips = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
            return res.status(200).json({ success: true, count: tips.length, data: tips });
        }

        const normalizedType = normalizeReportType(reportType);
        const reportInfo = await resolveReportById(reportId, normalizedType);
        if (!reportInfo) {
            return res.status(404).json({ error: "Report not found" });
        }

        const ownerId = resolveOwnerId(reportInfo.report?.reportedBy);
        if (!isAdmin && !ownerMatchesIdentity(ownerId, identity)) {
            return res.status(403).json({ error: "Not allowed to view tips" });
        }

        const snapshot = await tipsRef
            .where("reportId", "==", String(reportId).trim())
            .get();

        if (snapshot.empty) {
            return res.status(200).json({ success: true, count: 0, data: [] });
        }

        const tips = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
        tips.sort((a, b) => toMillis(b.createdAt) - toMillis(a.createdAt));
        return res.status(200).json({ success: true, count: tips.length, data: tips });
    } catch (err) {
        console.error("Get tips error:", err);
        return res.status(500).json({ error: "Failed to fetch tips" });
    }
};
