
import { db } from "../firebase/admin.js";
import admin from "firebase-admin";
import { v2 as cloudinary } from "cloudinary";
import dotenv from "dotenv";

dotenv.config();

const missingReportsRef = db.collection("missingReports");

const normalizePhone = (phone) => String(phone || "").trim();
const isDataUrl = (value) => /^data:image\/[a-zA-Z]+;base64,/.test(value || "");
const isHttpUrl = (value) => /^https?:\/\//i.test(value || "");

/**
 * CREATE a missing report
 */
export const createMissingReport = async (req, res) => {
    try {
        const reporterId = req.auth?.userId || req.body?.reportedBy || 'anonymous';

        const {
            fullName,
            age,
            gender,
            lastSeenLocation,
            lastSeenDate,
            contactName,
            contactPhone,
            description,
            status,
            photo,
        } = req.body;

        if (!fullName || !age || !gender || !lastSeenLocation || !lastSeenDate || !contactName || !contactPhone) {
            return res.status(400).json({ error: "Missing required fields" });
        }

        const parsedAge = Number(age);
        if (!Number.isFinite(parsedAge) || parsedAge <= 0) {
            return res.status(400).json({ error: "Invalid age" });
        }

        // Format date
        const dateStr = String(lastSeenDate).trim();
        let formattedDate = dateStr;
        const ddmmyyyyRegex = /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/;
        const match = dateStr.match(ddmmyyyyRegex);
        if (match) {
            const [, day, month, year] = match;
            formattedDate = `${year}-${month.padStart(2, '0')}-${day.padStart(2, '0')}`;
        }
        const dateRegex = /^\d{4}-\d{2}-\d{2}$/;
        if (!dateRegex.test(formattedDate)) {
            return res.status(400).json({ error: "Invalid lastSeenDate format (YYYY-MM-DD or dd/mm/yyyy)" });
        }

        // Normalize phone
        const normalizedPhone = normalizePhone(contactPhone);
        const e164 = /^\+[1-9]\d{1,14}$/;
        let finalPhone = normalizedPhone;
        if (!e164.test(normalizedPhone)) {
            const digits = normalizedPhone.replaceAll(/\D/g, '');
            if (digits.startsWith('252') && digits.length >= 10) {
                finalPhone = `+${digits}`;
            } else if (digits.length >= 8) {
                finalPhone = `+252${digits}`;
            } else {
                return res.status(400).json({
                    error: "Invalid phone number format. Please use E.164 format (e.g. +252612000111)"
                });
            }
        }

        // Upload photo to Cloudinary
        let imageUrl = "";
        if (photo && (isDataUrl(photo) || isHttpUrl(photo))) {
            try {
                const uploadRes = await cloudinary.uploader.upload(photo, {
                    folder: "missing_reports",
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
            fullName: String(fullName).trim(),
            age: parsedAge,
            gender: String(gender).trim().toLowerCase(),
            photo: imageUrl,
            lastSeenLocation: String(lastSeenLocation).trim(),
            lastSeenDate: formattedDate,
            contactName: String(contactName).trim(),
            contactPhone: finalPhone,
            description: description ? String(description).trim() : "",
            status: status ? String(status).trim() : "pending",
            reportedBy: reporterId,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        const created = await missingReportsRef.add(reportPayload);

        return res.status(201).json({
            message: "Missing report created",
            reportId: created.id,
            data: { id: created.id, ...reportPayload },
        });
    } catch (err) {
        console.error("Create missing report error:", err);
        return res.status(500).json({ error: "Failed to create report" });
    }
};

/**
 * GET all missing reports
 */
export const getMissingReports = async (req, res) => {
    try {
        const snapshot = await missingReportsRef.orderBy("createdAt", "desc").get();
        if (snapshot.empty) {
            return res.status(404).json({ error: "No missing reports found" });
        }

        const reports = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        return res.status(200).json({ success: true, count: reports.length, data: reports });
    } catch (err) {
        console.error("Get missing reports error:", err);
        return res.status(500).json({ error: "Failed to fetch reports" });
    }
};

/**
 * GET a single missing report by ID
 */
export const getMissingReportById = async (req, res) => {
    try {
        const { id } = req.params;
        const doc = await missingReportsRef.doc(id).get();
        if (!doc.exists) {
            return res.status(404).json({ error: "Report not found" });
        }
        return res.status(200).json({ success: true, data: { id: doc.id, ...doc.data() } });
    } catch (err) {
        console.error("Get report by ID error:", err);
        return res.status(500).json({ error: "Failed to fetch report" });
    }
};

/**
 * UPDATE a missing report by ID
 */
export const updateMissingReport = async (req, res) => {
    try {
        const { id } = req.params;
        const updateData = { ...req.body };

        const docRef = missingReportsRef.doc(id);
        const doc = await docRef.get();
        if (!doc.exists) {
            return res.status(404).json({ error: "Report not found" });
        }

        // If photo is updated, upload to Cloudinary
        if (updateData.photo && (isDataUrl(updateData.photo) || isHttpUrl(updateData.photo))) {
            try {
                const uploadRes = await cloudinary.uploader.upload(updateData.photo, {
                    folder: "missing_reports",
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
        return res.status(200).json({ success: true, data: { id: updatedDoc.id, ...updatedDoc.data() } });
    } catch (err) {
        console.error("Update report error:", err);
        return res.status(500).json({ error: "Failed to update report" });
    }
};

/**
 * DELETE a missing report by ID
 */
export const deleteMissingReport = async (req, res) => {
    try {
        const { id } = req.params;
        const docRef = missingReportsRef.doc(id);
        const doc = await docRef.get();
        if (!doc.exists) {
            return res.status(404).json({ error: "Report not found" });
        }

        await docRef.delete();
        return res.status(200).json({ success: true, message: `Report ${id} deleted successfully` });
    } catch (err) {
        console.error("Delete report error:", err);
        return res.status(500).json({ error: "Failed to delete report" });
    }
};
