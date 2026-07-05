import { db } from "../firebase/admin.js";
import admin from "firebase-admin";
import { resolveRequestIdentity } from "./access.js";

const usersRef = db.collection("users");

const normalizeToken = (value) => String(value || "").trim();

export const registerFcmToken = async (req, res) => {
    try {
        const identity = resolveRequestIdentity(req);
        if (!identity.userId && !identity.email) {
            return res.status(401).json({ error: "Login required" });
        }

        const token = normalizeToken(req.body?.token);
        if (!token) {
            return res.status(400).json({ error: "Missing FCM token" });
        }

        const userId = identity.userId || identity.email;
        const userRef = usersRef.doc(userId);
        const existing = await userRef.get();

        if (existing.exists) {
            await userRef.set(
                {
                    fcmTokens: admin.firestore.FieldValue.arrayUnion(token),
                    fcmUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
                },
                { merge: true }
            );
        } else {
            await userRef.set(
                {
                    id: userId,
                    email: identity.email || null,
                    role: identity.role || "public",
                    fcmTokens: [token],
                    fcmUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                },
                { merge: true }
            );
        }

        return res.status(200).json({ success: true, message: "FCM token registered" });
    } catch (err) {
        console.error("Register FCM token error:", err);
        return res.status(500).json({ error: "Failed to register FCM token" });
    }
};

export const removeFcmToken = async (req, res) => {
    try {
        const identity = resolveRequestIdentity(req);
        if (!identity.userId && !identity.email) {
            return res.status(401).json({ error: "Login required" });
        }

        const token = normalizeToken(req.body?.token);
        if (!token) {
            return res.status(400).json({ error: "Missing FCM token" });
        }

        const userId = identity.userId || identity.email;
        const userRef = usersRef.doc(userId);
        const existing = await userRef.get();
        if (!existing.exists) {
            return res.status(200).json({ success: true, message: "Token removed" });
        }

        await userRef.set(
            {
                fcmTokens: admin.firestore.FieldValue.arrayRemove(token),
                fcmUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
        );

        return res.status(200).json({ success: true, message: "FCM token removed" });
    } catch (err) {
        console.error("Remove FCM token error:", err);
        return res.status(500).json({ error: "Failed to remove FCM token" });
    }
};

export const updateUserLocation = async (req, res) => {
    try {
        const identity = resolveRequestIdentity(req);
        if (!identity.userId && !identity.email) {
            return res.status(401).json({ error: "Login required" });
        }

        const lat = Number(req.body?.lat);
        const lng = Number(req.body?.lng);
        if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
            return res.status(400).json({ error: "Invalid lat/lng" });
        }

        const userId = identity.userId || identity.email;
        await usersRef.doc(userId).set(
            {
                id: userId,
                email: identity.email || null,
                lastKnownLat: lat,
                lastKnownLng: lng,
                lastLocationUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
        );

        return res.status(200).json({ success: true, message: "Location updated" });
    } catch (err) {
        console.error("Update user location error:", err);
        return res.status(500).json({ error: "Failed to update location" });
    }
};
