import { db, admin } from "../firebase/admin.js";
import { getAdminUserIds } from "../controller/access.js";

const usersRef = db.collection("users");

const EARTH_RADIUS_KM = 6371;

const haversineKm = (lat1, lng1, lat2, lng2) => {
    const toRad = (deg) => (deg * Math.PI) / 180;
    const dLat = toRad(lat2 - lat1);
    const dLng = toRad(lng2 - lng1);
    const a =
        Math.sin(dLat / 2) ** 2 +
        Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
    return 2 * EARTH_RADIUS_KM * Math.asin(Math.sqrt(a));
};

const uniqueStrings = (values) =>
    [...new Set(values.filter((value) => typeof value === "string" && value.trim().length > 0))];

const chunkArray = (items, size = 500) => {
    const chunks = [];
    for (let i = 0; i < items.length; i += size) {
        chunks.push(items.slice(i, i + size));
    }
    return chunks;
};

const normalizeTokens = (tokens) => uniqueStrings(tokens);

const resolveUserDoc = async (identifier) => {
    const cleaned = String(identifier || "").trim();
    if (!cleaned) return null;

    const direct = await usersRef.doc(cleaned).get();
    if (direct.exists) {
        return { id: direct.id, data: direct.data() || {} };
    }

    const email = cleaned.toLowerCase();
    const byEmail = await usersRef.where("email", "==", email).limit(1).get();
    if (!byEmail.empty) {
        const doc = byEmail.docs[0];
        return { id: doc.id, data: doc.data() || {} };
    }

    return null;
};

export const getTokensForUserIdentifier = async (identifier) => {
    const user = await resolveUserDoc(identifier);
    if (!user) return [];
    const tokens = user.data?.fcmTokens;
    return Array.isArray(tokens) ? normalizeTokens(tokens) : [];
};

export const getTokensForUserIdentifiers = async (identifiers = []) => {
    const tokenSets = await Promise.all(
        identifiers.map((identifier) => getTokensForUserIdentifier(identifier))
    );
    return normalizeTokens(tokenSets.flat());
};

export const getAdminPushTokens = async () => {
    const adminIds = await getAdminUserIds();
    if (adminIds.length === 0) return [];
    return getTokensForUserIdentifiers(adminIds);
};

export const getNearbyUserPushTokens = async (lat, lng, radiusKm, excludeUserIds = []) => {
    const parsedLat = Number(lat);
    const parsedLng = Number(lng);
    const parsedRadius = Number(radiusKm);

    if (!Number.isFinite(parsedLat) || !Number.isFinite(parsedLng) || !Number.isFinite(parsedRadius)) {
        return [];
    }

    const excluded = new Set(
        excludeUserIds
            .map((value) => String(value || "").trim().toLowerCase())
            .filter(Boolean)
    );

    const snapshot = await usersRef.get();
    if (snapshot.empty) return [];

    const tokens = [];
    snapshot.docs.forEach((doc) => {
        const data = doc.data() || {};
        const userLat = Number(data.lastKnownLat);
        const userLng = Number(data.lastKnownLng);
        if (!Number.isFinite(userLat) || !Number.isFinite(userLng)) return;

        const docId = doc.id.toLowerCase();
        const email = String(data.email || "").trim().toLowerCase();
        if (excluded.has(docId) || (email && excluded.has(email))) return;

        const distance = haversineKm(parsedLat, parsedLng, userLat, userLng);
        if (distance <= parsedRadius) {
            if (Array.isArray(data.fcmTokens)) {
                tokens.push(...data.fcmTokens);
            }
        }
    });

    return normalizeTokens(tokens);
};

export const getAllUserPushTokens = async (excludeUserIds = []) => {
    const excluded = new Set(
        excludeUserIds
            .map((value) => String(value || "").trim().toLowerCase())
            .filter(Boolean)
    );

    const snapshot = await usersRef.get();
    if (snapshot.empty) return [];

    const tokens = [];
    snapshot.docs.forEach((doc) => {
        const data = doc.data() || {};
        const docId = doc.id.toLowerCase();
        const email = String(data.email || "").trim().toLowerCase();
        if (excluded.has(docId) || (email && excluded.has(email))) return;

        if (Array.isArray(data.fcmTokens)) {
            tokens.push(...data.fcmTokens);
        }
    });

    return normalizeTokens(tokens);
};

export const sendPushNotification = async ({
    tokens = [],
    title,
    body,
    data = {},
}) => {
    const cleanedTokens = normalizeTokens(tokens);
    if (cleanedTokens.length === 0) {
        return { successCount: 0, failureCount: 0, skipped: true };
    }

    const payloadData = Object.fromEntries(
        Object.entries(data).map(([key, value]) => [key, String(value ?? "")])
    );

    let successCount = 0;
    let failureCount = 0;

    const tokenChunks = chunkArray(cleanedTokens, 500);
    for (const tokenChunk of tokenChunks) {
        try {
            const response = await admin.messaging().sendEachForMulticast({
                tokens: tokenChunk,
                notification: {
                    title: String(title || "MPTS Alert"),
                    body: String(body || ""),
                },
                data: payloadData,
                android: {
                    priority: "high",
                    notification: {
                        channelId: "mpts_alerts",
                        sound: "default",
                    },
                },
                apns: {
                    payload: {
                        aps: {
                            sound: "default",
                            badge: 1,
                        },
                    },
                },
            });

            successCount += response.successCount;
            failureCount += response.failureCount;

            response.responses.forEach((item, index) => {
                if (item.success) return;
                const code = item.error?.code || "";
                if (
                    code === "messaging/invalid-registration-token" ||
                    code === "messaging/registration-token-not-registered"
                ) {
                    void removeInvalidToken(tokenChunk[index]);
                }
            });
        } catch (err) {
            console.error("FCM send error:", err);
            failureCount += tokenChunk.length;
        }
    }

    return { successCount, failureCount, skipped: false };
};

const removeInvalidToken = async (token) => {
    if (!token) return;
    try {
        const snapshot = await usersRef.where("fcmTokens", "array-contains", token).get();
        if (snapshot.empty) return;

        const batch = db.batch();
        snapshot.docs.forEach((doc) => {
            batch.update(doc.ref, {
                fcmTokens: admin.firestore.FieldValue.arrayRemove(token),
            });
        });
        await batch.commit();
    } catch (err) {
        console.error("Failed to remove invalid FCM token:", err);
    }
};

export const notifyNewTip = async ({ reportId, reportType, ownerId, message, location }) => {
    const adminTokens = await getAdminPushTokens();
    const ownerTokens = ownerId ? await getTokensForUserIdentifier(ownerId) : [];
    const tokens = normalizeTokens([...adminTokens, ...ownerTokens]);

    return sendPushNotification({
        tokens,
        title: "New tip received",
        body: message || `New tip for ${reportType || "missing"} report near ${location || "unknown location"}.`,
        data: {
            type: "new_tip",
            reportId: reportId || "",
            reportType: reportType || "",
        },
    });
};

export const notifyVerificationMessage = async ({
    reportId,
    reportName,
    toReporter,
    preview,
}) => {
    const tokens = toReporter
        ? await getTokensForUserIdentifier(toReporter)
        : await getAdminPushTokens();

    return sendPushNotification({
        tokens,
        title: toReporter ? "Message from Admin" : "New verification evidence",
        body: preview || `Update on verification for ${reportName || "missing person report"}.`,
        data: {
            type: toReporter ? "verification_message" : "verification_evidence",
            reportId: reportId || "",
            reportType: "missing",
        },
    });
};

export const notifyVerificationDecision = async ({
    reportId,
    reportName,
    ownerId,
    verified,
    note,
}) => {
    const tokens = await getTokensForUserIdentifier(ownerId);
    return sendPushNotification({
        tokens,
        title: verified ? "Report verified" : "Report rejected",
        body: note ||
            (verified
                ? `${reportName || "Your report"} was verified by admin.`
                : `${reportName || "Your report"} was rejected. Please send new evidence.`),
        data: {
            type: verified ? "verification_verified" : "verification_rejected",
            reportId: reportId || "",
            reportType: "missing",
        },
    });
};

export const notifyNearbyAlert = async ({
    alertId,
    reportId,
    reportType,
    alertMessage,
    alertLat,
    alertLng,
    radiusKm,
    excludeUserIds = [],
}) => {
    const nearbyTokens = await getNearbyUserPushTokens(
        alertLat,
        alertLng,
        radiusKm,
        excludeUserIds,
    );
    const allTokens = nearbyTokens.length > 0
        ? []
        : await getAllUserPushTokens(excludeUserIds);
    const tokens = nearbyTokens.length > 0 ? nearbyTokens : allTokens;
    const deliveryMode = nearbyTokens.length > 0 ? "nearby" : "all_registered_fallback";

    const result = await sendPushNotification({
        tokens,
        title: reportType === "found" ? "Found person alert" : "Missing person alert",
        body: alertMessage || "A missing person alert was sent near your area.",
        data: {
            type: "nearby_alert",
            alertId: alertId || "",
            reportId: reportId || "",
            reportType: reportType || "missing",
            deliveryMode,
        },
    });

    return {
        ...result,
        targetCount: tokens.length,
        deliveryMode,
        nearbyTargetCount: nearbyTokens.length,
    };
};

export const notifyReportStatusChanged = async ({
    reportId,
    reportName,
    ownerId,
    newStatus,
}) => {
    const tokens = await getTokensForUserIdentifier(ownerId);
    return sendPushNotification({
        tokens,
        title: "Report status updated",
        body: `${reportName || "Your report"} is now ${newStatus || "updated"}.`,
        data: {
            type: "report_status_changed",
            reportId: reportId || "",
            reportType: "missing",
            status: newStatus || "",
        },
    });
};
