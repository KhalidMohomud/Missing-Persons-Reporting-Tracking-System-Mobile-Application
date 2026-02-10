import { db } from "../firebase/admin.js";

const usersRef = db.collection("users");
const missingReportsRef = db.collection("missingReports");
const foundReportsRef = db.collection("foundReports");

const normalize = (value) => String(value || "").trim().toLowerCase();

const readHeader = (req, key) => {
    if (!req?.headers) return "";
    const direct = req.headers[key];
    if (direct) return String(direct);
    const lower = req.headers[key.toLowerCase()];
    if (lower) return String(lower);
    return "";
};

export const normalizeReportType = (value) => {
    const cleaned = normalize(value);
    if (cleaned === "missing") return "missing";
    if (cleaned === "found") return "found";
    return null;
};

export const getUserRole = async (userId) => {
    if (!userId) return "public";
    const doc = await usersRef.doc(userId).get();
    if (!doc.exists) return "public";
    const role = doc.data()?.role;
    if (typeof role === "string" && role.trim().length > 0) {
        return role.trim().toLowerCase();
    }
    return "public";
};

export const isAdminUser = async (userId) => {
    const role = await getUserRole(userId);
    return role === "admin";
};

export const resolveRequestIdentity = (req) => {
    const headerUserId = readHeader(req, "x-user-id");
    const headerEmail = readHeader(req, "x-user-email");
    const headerRole = normalize(readHeader(req, "x-user-role"));
    const authUserId = req?.auth?.userId || "";
    const userId = authUserId || headerUserId;
    return {
        userId: userId ? String(userId).trim() : "",
        email: headerEmail ? String(headerEmail).trim().toLowerCase() : "",
        role: headerRole,
    };
};

export const isAdminRequest = async (req) => {
    const identity = resolveRequestIdentity(req);
    if (identity.role === "admin") return true;
    if (!identity.userId) return false;
    return isAdminUser(identity.userId);
};

export const ownerMatchesIdentity = (ownerId, identity) => {
    const cleanedOwner = String(ownerId || "").trim().toLowerCase();
    if (!cleanedOwner || cleanedOwner === "anonymous") return false;
    if (identity?.userId && cleanedOwner === identity.userId.trim().toLowerCase()) {
        return true;
    }
    if (identity?.email && cleanedOwner === identity.email.trim().toLowerCase()) {
        return true;
    }
    return false;
};

export const getAdminUserIds = async () => {
    const snapshot = await usersRef.where("role", "==", "admin").get();
    if (snapshot.empty) return [];
    return snapshot.docs.map((doc) => doc.id);
};

const fetchReport = async (ref, type, reportId) => {
    const doc = await ref.doc(reportId).get();
    if (!doc.exists) return null;
    return { type, report: { id: doc.id, ...doc.data() } };
};

export const resolveReportById = async (reportId, reportType) => {
    if (!reportId) return null;
    const cleanedId = String(reportId).trim();
    if (!cleanedId) return null;

    if (reportType === "missing") {
        return fetchReport(missingReportsRef, "missing", cleanedId);
    }
    if (reportType === "found") {
        return fetchReport(foundReportsRef, "found", cleanedId);
    }

    const missing = await fetchReport(missingReportsRef, "missing", cleanedId);
    if (missing) return missing;
    return fetchReport(foundReportsRef, "found", cleanedId);
};
