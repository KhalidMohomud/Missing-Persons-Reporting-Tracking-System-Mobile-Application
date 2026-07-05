import { db } from "../firebase/admin.js";
import admin from "firebase-admin";
import { v2 as cloudinary } from "cloudinary";
import dotenv from "dotenv";
import {
    isAdminRequest,
    ownerMatchesIdentity,
    resolveRequestIdentity,
} from "./access.js";
import {
    notifyVerificationMessage,
    notifyVerificationDecision,
} from "../services/push_notifications.js";

dotenv.config();

const missingReportsRef = db.collection("missingReports");

const VALID_VERIFICATION_STATUSES = new Set([
    "pending",
    "under_review",
    "verified",
    "rejected",
]);

const isDataUrl = (value) => /^data:image\/[a-zA-Z]+;base64,/.test(value || "");
const isHttpUrl = (value) => /^https?:\/\//i.test(value || "");

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
    if (!cleaned || cleaned.toLowerCase() === "anonymous") return null;
    return cleaned;
};

const messagesRefFor = (reportId) =>
    missingReportsRef.doc(reportId).collection("verificationMessages");

const getReportOr404 = async (reportId) => {
    const doc = await missingReportsRef.doc(reportId).get();
    if (!doc.exists) return null;
    return { id: doc.id, ...doc.data() };
};

const canAccessVerificationChat = async (req, report) => {
    const identity = resolveRequestIdentity(req);
    if (!identity.userId && !identity.email) {
        return { allowed: false, status: 401, message: "Login required" };
    }

    const isAdmin = await isAdminRequest(req);
    if (isAdmin) {
        return { allowed: true, identity, isAdmin: true };
    }

    const ownerId = resolveOwnerId(report?.reportedBy);
    if (ownerMatchesIdentity(ownerId, identity)) {
        return { allowed: true, identity, isAdmin: false };
    }

    return { allowed: false, status: 403, message: "Not allowed to access verification chat" };
};

const uploadImage = async (photo) => {
    const uploadRes = await cloudinary.uploader.upload(photo, {
        folder: "verification_evidence",
        resource_type: "image",
        secure: true,
    });
    return uploadRes.secure_url;
};

const addSystemMessage = async (reportId, text) => {
    await messagesRefFor(reportId).add({
        type: "system",
        text: String(text).trim(),
        imageUrl: null,
        senderId: "system",
        senderRole: "system",
        senderName: "System",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
};

export const getVerificationStatus = async (req, res) => {
    try {
        const { id } = req.params;
        const report = await getReportOr404(id);
        if (!report) {
            return res.status(404).json({ error: "Report not found" });
        }

        const access = await canAccessVerificationChat(req, report);
        if (!access.allowed) {
            return res.status(access.status).json({ error: access.message });
        }

        return res.status(200).json({
            success: true,
            data: {
                reportId: id,
                verificationStatus: report.verificationStatus || "pending",
                verificationNote: report.verificationNote || "",
                verifiedAt: report.verifiedAt || null,
                verifiedBy: report.verifiedBy || null,
                rejectedAt: report.rejectedAt || null,
                rejectedBy: report.rejectedBy || null,
            },
        });
    } catch (err) {
        console.error("Get verification status error:", err);
        return res.status(500).json({ error: "Failed to fetch verification status" });
    }
};

export const getVerificationMessages = async (req, res) => {
    try {
        const { id } = req.params;
        const report = await getReportOr404(id);
        if (!report) {
            return res.status(404).json({ error: "Report not found" });
        }

        const access = await canAccessVerificationChat(req, report);
        if (!access.allowed) {
            return res.status(access.status).json({ error: access.message });
        }

        const snapshot = await messagesRefFor(id).orderBy("createdAt", "asc").get();
        const messages = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));

        return res.status(200).json({
            success: true,
            count: messages.length,
            verificationStatus: report.verificationStatus || "pending",
            data: messages,
        });
    } catch (err) {
        console.error("Get verification messages error:", err);
        return res.status(500).json({ error: "Failed to fetch verification messages" });
    }
};

export const sendVerificationMessage = async (req, res) => {
    try {
        const { id } = req.params;
        const { text, image } = req.body;

        const report = await getReportOr404(id);
        if (!report) {
            return res.status(404).json({ error: "Report not found" });
        }

        const access = await canAccessVerificationChat(req, report);
        if (!access.allowed) {
            return res.status(access.status).json({ error: access.message });
        }

        const trimmedText = text ? String(text).trim() : "";
        let imageUrl = null;

        if (image && (isDataUrl(image) || isHttpUrl(image))) {
            try {
                imageUrl = await uploadImage(image);
            } catch (uploadErr) {
                console.error("Verification image upload error:", uploadErr);
                return res.status(400).json({ error: "Failed to upload image" });
            }
        }

        if (!trimmedText && !imageUrl) {
            return res.status(400).json({ error: "Message text or image is required" });
        }

        const identity = access.identity;
        const senderRole = access.isAdmin ? "admin" : "owner";
        const senderName = access.isAdmin ? "Admin" : "Reporter";

        const messagePayload = {
            type: imageUrl ? (trimmedText ? "text_image" : "image") : "text",
            text: trimmedText,
            imageUrl,
            senderId: identity.userId || identity.email || "unknown",
            senderRole,
            senderName,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        const created = await messagesRefFor(id).add(messagePayload);

        const reportUpdate = {
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        const currentStatus = report.verificationStatus || "pending";
        if (currentStatus === "pending" && access.isAdmin) {
            reportUpdate.verificationStatus = "under_review";
        } else if (currentStatus === "rejected" && !access.isAdmin) {
            reportUpdate.verificationStatus = "under_review";
            if (report.status === "closed") {
                reportUpdate.status = "pending";
            }
        }

        await missingReportsRef.doc(id).update(reportUpdate);

        try {
            const ownerId = resolveOwnerId(report.reportedBy);
            const preview = trimmedText || (imageUrl ? "New image/document uploaded" : "New message");
            await notifyVerificationMessage({
                reportId: id,
                reportName: report.fullName,
                toReporter: access.isAdmin ? ownerId : null,
                preview,
            });
        } catch (pushErr) {
            console.error("Verification message push error:", pushErr);
        }

        return res.status(201).json({
            success: true,
            messageId: created.id,
            data: { id: created.id, ...messagePayload },
        });
    } catch (err) {
        console.error("Send verification message error:", err);
        return res.status(500).json({ error: "Failed to send message" });
    }
};

export const requestEvidence = async (req, res) => {
    try {
        const { id } = req.params;
        const { message } = req.body;

        const isAdmin = await isAdminRequest(req);
        if (!isAdmin) {
            return res.status(403).json({ error: "Admin only" });
        }

        const report = await getReportOr404(id);
        if (!report) {
            return res.status(404).json({ error: "Report not found" });
        }

        const defaultMessage =
            "Fadlan soo dir caddeymo dheeraad ah: sawirka qofka lumay, ID card, iyo macluumaadka xiriirka si aan u xaqiijino report-ka.";
        const requestText = message ? String(message).trim() : defaultMessage;

        const identity = resolveRequestIdentity(req);
        const messagePayload = {
            type: "text",
            text: requestText,
            imageUrl: null,
            senderId: identity.userId || identity.email || "admin",
            senderRole: "admin",
            senderName: "Admin",
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        const created = await messagesRefFor(id).add(messagePayload);

        await missingReportsRef.doc(id).update({
            verificationStatus: "under_review",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        try {
            const ownerId = resolveOwnerId(report.reportedBy);
            await notifyVerificationMessage({
                reportId: id,
                reportName: report.fullName,
                toReporter: ownerId,
                preview: requestText,
            });
        } catch (pushErr) {
            console.error("Request evidence push error:", pushErr);
        }

        return res.status(201).json({
            success: true,
            messageId: created.id,
            data: { id: created.id, ...messagePayload },
        });
    } catch (err) {
        console.error("Request evidence error:", err);
        return res.status(500).json({ error: "Failed to request evidence" });
    }
};

export const verifyReport = async (req, res) => {
    try {
        const { id } = req.params;
        const { note } = req.body;

        const isAdmin = await isAdminRequest(req);
        if (!isAdmin) {
            return res.status(403).json({ error: "Admin only" });
        }

        const report = await getReportOr404(id);
        if (!report) {
            return res.status(404).json({ error: "Report not found" });
        }

        const identity = resolveRequestIdentity(req);
        const adminId = identity.userId || identity.email || "admin";
        const verificationNote = note ? String(note).trim() : "";

        await missingReportsRef.doc(id).update({
            status: "resolved",
            verificationStatus: "verified",
            verificationNote,
            verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
            verifiedBy: adminId,
            rejectedAt: null,
            rejectedBy: null,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        const systemText = verificationNote
            ? `Report verified ✓. ${verificationNote}`
            : "Report verified ✓. Caddeymaha waa la xaqiijiyay.";
        await addSystemMessage(id, systemText);

        try {
            const ownerId = resolveOwnerId(report.reportedBy);
            await notifyVerificationDecision({
                reportId: id,
                reportName: report.fullName,
                ownerId,
                verified: true,
                note: verificationNote,
            });
        } catch (pushErr) {
            console.error("Verify report push error:", pushErr);
        }

        return res.status(200).json({
            success: true,
            message: "Report verified",
            data: {
                reportId: id,
                verificationStatus: "verified",
                verificationNote,
            },
        });
    } catch (err) {
        console.error("Verify report error:", err);
        return res.status(500).json({ error: "Failed to verify report" });
    }
};

export const rejectReport = async (req, res) => {
    try {
        const { id } = req.params;
        const { reason } = req.body;

        const isAdmin = await isAdminRequest(req);
        if (!isAdmin) {
            return res.status(403).json({ error: "Admin only" });
        }

        const report = await getReportOr404(id);
        if (!report) {
            return res.status(404).json({ error: "Report not found" });
        }

        const rejectionReason = reason ? String(reason).trim() : "";
        if (!rejectionReason) {
            return res.status(400).json({ error: "Rejection reason is required" });
        }

        const identity = resolveRequestIdentity(req);
        const adminId = identity.userId || identity.email || "admin";

        await missingReportsRef.doc(id).update({
            status: "closed",
            verificationStatus: "rejected",
            verificationNote: rejectionReason,
            rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
            rejectedBy: adminId,
            verifiedAt: null,
            verifiedBy: null,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        await addSystemMessage(
            id,
            `Report rejected ✗. Sabab: ${rejectionReason}. Fadlan soo dir caddeymo cusub.`
        );

        try {
            const ownerId = resolveOwnerId(report.reportedBy);
            await notifyVerificationDecision({
                reportId: id,
                reportName: report.fullName,
                ownerId,
                verified: false,
                note: rejectionReason,
            });
        } catch (pushErr) {
            console.error("Reject report push error:", pushErr);
        }

        return res.status(200).json({
            success: true,
            message: "Report rejected",
            data: {
                reportId: id,
                verificationStatus: "rejected",
                verificationNote: rejectionReason,
            },
        });
    } catch (err) {
        console.error("Reject report error:", err);
        return res.status(500).json({ error: "Failed to reject report" });
    }
};
