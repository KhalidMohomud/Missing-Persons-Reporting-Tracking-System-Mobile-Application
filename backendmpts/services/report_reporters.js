import { db } from "../firebase/admin.js";

const usersRef = db.collection("users");

const safeString = (value) => String(value || "").trim();

const nameFields = [
    "reportedByName",
    "reporterName",
    "reporterFullName",
    "reportedByFullName",
];

const emailFields = [
    "reportedByEmail",
    "reporterEmail",
    "email",
];

const looksLikeTechnicalId = (value) => {
    const text = safeString(value);
    if (!text) return false;
    if (/^user_[a-zA-Z0-9]+$/.test(text)) return true;
    return !text.includes("@") && /^[a-zA-Z0-9]{20,}$/.test(text);
};

export const reporterNameFromPayload = (payload = {}) => {
    const owner = safeString(payload?.reportedBy);
    for (const field of nameFields) {
        const value = safeString(payload?.[field]);
        if (value && value !== owner && !looksLikeTechnicalId(value)) {
            return value;
        }
    }
    return "";
};

export const reporterEmailFromPayload = (payload = {}) => {
    for (const field of emailFields) {
        const value = safeString(payload?.[field]);
        if (value && value.includes("@")) return value.toLowerCase();
    }
    return "";
};

const displayNameForUser = (user, fallback = "") => {
    if (!user) return fallback;

    const fullName = safeString(user.fullName);
    if (fullName) return fullName;

    const name = safeString(user.name || user.username);
    if (name) return name;

    const firstName = safeString(user.firstName);
    const lastName = safeString(user.lastName);
    const joinedName = [firstName, lastName].filter(Boolean).join(" ").trim();
    if (joinedName) return joinedName;

    const email = safeString(user.email);
    if (email) return email;

    return fallback;
};

const findUserByIdOrEmail = async (key, cache) => {
    const lookupKey = safeString(key);
    if (!lookupKey || lookupKey.toLowerCase() === "anonymous") return null;

    const cacheKey = lookupKey.toLowerCase();
    if (cache?.has(cacheKey)) return cache.get(cacheKey);

    let user = null;

    if (!lookupKey.includes("/")) {
        const doc = await usersRef.doc(lookupKey).get();
        if (doc.exists) {
            user = { id: doc.id, ...doc.data() };
        }
    }

    if (!user && lookupKey.includes("@")) {
        const emailCandidates = [...new Set([lookupKey, lookupKey.toLowerCase()])];
        for (const email of emailCandidates) {
            const snapshot = await usersRef.where("email", "==", email).limit(1).get();
            if (!snapshot.empty) {
                const doc = snapshot.docs[0];
                user = { id: doc.id, ...doc.data() };
                break;
            }
        }
    }

    if (cache) cache.set(cacheKey, user);
    return user;
};

export const resolveReporterName = async (ownerIdOrEmail, fallbackName = "", cache) => {
    const directName = safeString(fallbackName);
    if (directName && !looksLikeTechnicalId(directName)) {
        return directName;
    }

    const user = await findUserByIdOrEmail(ownerIdOrEmail, cache);
    return displayNameForUser(user, "");
};

export const withReporterName = async (report, cache = new Map()) => {
    if (!report) return report;

    const existingName = reporterNameFromPayload(report);
    const candidates = [
        report.reportedBy,
        report.reportedByEmail,
        report.reporterEmail,
    ];

    let reportedByName = existingName;
    for (const candidate of candidates) {
        if (reportedByName) break;
        reportedByName = await resolveReporterName(candidate, "", cache);
    }

    if (!reportedByName) return report;
    return { ...report, reportedByName };
};

export const withReporterNames = async (reports) => {
    const cache = new Map();
    return Promise.all(reports.map((report) => withReporterName(report, cache)));
};
