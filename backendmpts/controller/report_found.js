import { db } from "../firebase/admin.js";
import admin from "firebase-admin";
import { v2 as cloudinary } from "cloudinary";
import dotenv from "dotenv";
import {
    reporterEmailFromPayload,
    reporterNameFromPayload,
    resolveReporterName,
    withReporterName,
    withReporterNames,
} from "../services/report_reporters.js";

dotenv.config();

const foundReportsRef = db.collection("foundReports");



const isDataUrl = (value) => /^data:image\/[a-zA-Z]+;base64,/.test(value || "");
const isHttpUrl = (value) => /^https?:\/\//i.test(value || "");

/**
 * CREATE a found report
 */
export const createFoundReport = async (req, res) => {
    try {
        const reporterId = req.auth?.userId || req.body?.reportedBy || "anonymous";
        const reporterName = await resolveReporterName(
            reporterId,
            reporterNameFromPayload(req.body),
        );
        const reporterEmail = reporterEmailFromPayload(req.body);

        const {
            description,
            estimatedAge,
            foundLat,
            foundLng,
            gender,
            locationFound,
            photo,
        } = req.body;

        if (
            estimatedAge === undefined ||
            estimatedAge === null ||
            foundLat === undefined ||
            foundLat === null ||
            foundLng === undefined ||
            foundLng === null ||
            !gender ||
            !locationFound
        ) {
            return res.status(400).json({ error: "Missing required fields" });
        }

        const parsedAge = Number(estimatedAge);
        if (!Number.isFinite(parsedAge) || parsedAge <= 0) {
            return res.status(400).json({ error: "Invalid estimatedAge" });
        }

        const parsedLat = Number(foundLat);
        if (!Number.isFinite(parsedLat) || parsedLat < -90 || parsedLat > 90) {
            return res.status(400).json({ error: "Invalid foundLat" });
        }

        const parsedLng = Number(foundLng);
        if (!Number.isFinite(parsedLng) || parsedLng < -180 || parsedLng > 180) {
            return res.status(400).json({ error: "Invalid foundLng" });
        }

        // Upload photo to Cloudinary
        let imageUrl = "";
        if (photo && (isDataUrl(photo) || isHttpUrl(photo))) {
            try {
                const uploadRes = await cloudinary.uploader.upload(photo, {
                    folder: "found_reports",
                    resource_type: "image",
                    secure: true,
                });
                imageUrl = uploadRes.secure_url;
            } catch (uploadErr) {
                console.error("Cloudinary upload error:", uploadErr);
                return res.status(400).json({ error: "Failed to upload photo. Please try again." });
            }
        }

        if (!imageUrl) {
            return res.status(400).json({ error: "Photo is required (data URL or image URL)" });
        }

        const reportPayload = {
            description: description ? String(description).trim() : "",
            estimatedAge: parsedAge,
            foundLat: parsedLat,
            foundLng: parsedLng,
            gender: String(gender).trim().toLowerCase(),
            locationFound: String(locationFound).trim(),
            photo: imageUrl,
            reportedBy: reporterId,
            ...(reporterName ? { reportedByName: reporterName } : {}),
            ...(reporterEmail ? { reportedByEmail: reporterEmail } : {}),
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        const created = await foundReportsRef.add(reportPayload);

        return res.status(201).json({
            message: "Found report created",
            reportId: created.id,
            data: { id: created.id, ...reportPayload },
        });
    } catch (err) {
        console.error("Create found report error:", err);
        return res.status(500).json({ error: "Failed to create report" });
    }
};

/**
 * GET all found reports
 */
export const getFoundReports = async (req, res) => {
    try {
        const snapshot = await foundReportsRef.orderBy("createdAt", "desc").get();
        if (snapshot.empty) {
            return res.status(404).json({ error: "No found reports found" });
        }

        const reports = await withReporterNames(
            snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })),
        );
        return res.status(200).json({ success: true, count: reports.length, data: reports });
    } catch (err) {
        console.error("Get found reports error:", err);
        return res.status(500).json({ error: "Failed to fetch reports" });
    }
};

/**
 * GET a single found report by ID
 */
export const getFoundReportById = async (req, res) => {
    try {
        const { id } = req.params;
        const doc = await foundReportsRef.doc(id).get();
        if (!doc.exists) {
            return res.status(404).json({ error: "Report not found" });
        }
        const report = await withReporterName({ id: doc.id, ...doc.data() });
        return res.status(200).json({ success: true, data: report });
    } catch (err) {
        console.error("Get found report by ID error:", err);
        return res.status(500).json({ error: "Failed to fetch report" });
    }
};

/**
 * UPDATE a found report by ID
 */
export const updateFoundReport = async (req, res) => {
    try {
        const { id } = req.params;
        const updateData = { ...req.body };

        const docRef = foundReportsRef.doc(id);
        const doc = await docRef.get();
        if (!doc.exists) {
            return res.status(404).json({ error: "Report not found" });
        }

        // If photo is updated, upload to Cloudinary
        if (updateData.photo && (isDataUrl(updateData.photo) || isHttpUrl(updateData.photo))) {
            try {
                const uploadRes = await cloudinary.uploader.upload(updateData.photo, {
                    folder: "found_reports",
                    resource_type: "image",
                    secure: true,
                });
                updateData.photo = uploadRes.secure_url;
            } catch (err) {
                console.error("Cloudinary upload error:", err);
                return res.status(400).json({ error: "Failed to upload photo" });
            }
        }

        updateData.updatedAt = admin.firestore.FieldValue.serverTimestamp();
        await docRef.update(updateData);

        const updatedDoc = await docRef.get();
        const report = await withReporterName({ id: updatedDoc.id, ...updatedDoc.data() });
        return res.status(200).json({ success: true, data: report });
    } catch (err) {
        console.error("Update found report error:", err);
        return res.status(500).json({ error: "Failed to update report" });
    }
};

/**
 * DELETE a found report by ID
 */
export const deleteFoundReport = async (req, res) => {
    try {
        const { id } = req.params;
        const docRef = foundReportsRef.doc(id);
        const doc = await docRef.get();
        if (!doc.exists) {
            return res.status(404).json({ error: "Report not found" });
        }

        await docRef.delete();
        return res.status(200).json({ success: true, message: `Report ${id} deleted successfully` });
    } catch (err) {
        console.error("Delete found report error:", err);
        return res.status(500).json({ error: "Failed to delete report" });
    }
};
