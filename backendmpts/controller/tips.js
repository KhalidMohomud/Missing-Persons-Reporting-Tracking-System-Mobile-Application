import { db } from "../firebase/admin.js";
import admin from "firebase-admin";

const tipsRef = db.collection("tips");

export const createTip = async (req, res) => {
    try {
        const { reportId, message, location } = req.body;

        if (!reportId || !message || !location) {
            return res.status(400).json({ error: "Missing required fields" });
        }

        const isAnonymous = true;
        const senderId = null;

        const payload = {
            reportId: String(reportId).trim(),
            message: String(message).trim(),
            location: String(location).trim(),
            anonymous: isAnonymous,
            senderId,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        const created = await tipsRef.add(payload);

        return res.status(201).json({
            success: true,
            tipId: created.id,
            data: { id: created.id, ...payload },
        });
    } catch (err) {
        console.error("Create tip error:", err);
        return res.status(500).json({ error: "Failed to create tip" });
    }
};
