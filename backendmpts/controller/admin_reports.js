import { db } from "../firebase/admin.js";
import admin from "firebase-admin";
import { withReporterNames } from "../services/report_reporters.js";

const missingReportsRef = db.collection("missingReports");
const foundReportsRef = db.collection("foundReports");

const toIsoDate = (date) => date.toISOString().slice(0, 10);

const getCurrentMonthRangeUtc = () => {
  const now = new Date();
  const start = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
  const end = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1));
  return { start, end };
};

const getCurrentYearRangeUtc = () => {
  const now = new Date();
  const start = new Date(Date.UTC(now.getUTCFullYear(), 0, 1));
  const end = new Date(Date.UTC(now.getUTCFullYear() + 1, 0, 1));
  return { start, end };
};

const formatMonthLabel = (date) => {
  return date.toLocaleString("en-US", { month: "long", year: "numeric", timeZone: "UTC" });
};

const formatYearLabel = (date) => {
  return date.toLocaleString("en-US", { year: "numeric", timeZone: "UTC" });
};

const buildReportRangePayload = async ({ start, end, label }) => {
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

  const missing = await withReporterNames(
    missingSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() })),
  );
  const found = await withReporterNames(
    foundSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() })),
  );

  return {
    success: true,
    range: {
      start: toIsoDate(start),
      end: toIsoDate(end),
      label,
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
  };
};

export const getMonthlyReports = async (req, res) => {
  try {
    const { start, end } = getCurrentMonthRangeUtc();
    const payload = await buildReportRangePayload({
      start,
      end,
      label: formatMonthLabel(start),
    });

    return res.status(200).json(payload);
  } catch (err) {
    console.error("Get monthly reports error:", err);
    return res.status(500).json({ error: "Failed to fetch monthly reports" });
  }
};

export const getYearlyReports = async (req, res) => {
  try {
    const { start, end } = getCurrentYearRangeUtc();
    const payload = await buildReportRangePayload({
      start,
      end,
      label: formatYearLabel(start),
    });

    return res.status(200).json(payload);
  } catch (err) {
    console.error("Get yearly reports error:", err);
    return res.status(500).json({ error: "Failed to fetch yearly reports" });
  }
};
