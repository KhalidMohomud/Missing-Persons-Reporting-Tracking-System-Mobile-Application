import { db } from "../firebase/admin.js";
import admin from "firebase-admin";

const missingReportsRef = db.collection("missingReports");
const foundReportsRef = db.collection("foundReports");

const toIsoDate = (date) => date.toISOString().slice(0, 10);

const getLastMonthRangeUtc = () => {
  const now = new Date();
  const start = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - 1, 1));
  const end = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
  return { start, end };
};

const formatMonthLabel = (date) => {
  return date.toLocaleString("en-US", { month: "long", year: "numeric", timeZone: "UTC" });
};

export const getMonthlyReports = async (req, res) => {
  try {
    const { start, end } = getLastMonthRangeUtc();
    const startTs = admin.firestore.Timestamp.fromDate(start);
    const endTs = admin.firestore.Timestamp.fromDate(end);

    const [missingSnap, foundSnap] = await Promise.all([
      missingReportsRef
        .where("createdAt", ">=", startTs)
        .where("createdAt", "<", endTs)
        .orderBy("createdAt", "desc")
        .get(),
      foundReportsRef
        .where("createdAt", ">=", startTs)
        .where("createdAt", "<", endTs)
        .orderBy("createdAt", "desc")
        .get(),
    ]);

    const missing = missingSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
    const found = foundSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));

    return res.status(200).json({
      success: true,
      range: {
        start: toIsoDate(start),
        end: toIsoDate(end),
        label: formatMonthLabel(start),
      },
      count: {
        missing: missing.length,
        found: found.length,
        total: missing.length + found.length,
      },
      data: {
        missing,
        found,
      },
    });
  } catch (err) {
    console.error("Get monthly reports error:", err);
    return res.status(500).json({ error: "Failed to fetch monthly reports" });
  }
};
