import express from "express";
import {
    createMissingReport,
    getMissingReports,
    getMissingReportById,
    updateMissingReport,
    deleteMissingReport,
} from "../controller/reports.js";
import {
    createFoundReport,
    getFoundReports,
    getFoundReportById,
    updateFoundReport,
    deleteFoundReport,
} from "../controller/report_found.js";
import { getMonthlyReports, getYearlyReports } from "../controller/admin_reports.js";
import { createTip, getTips } from "../controller/tips.js";
import { createAlert, getAlerts } from "../controller/alerts.js";
import {
    getVerificationStatus,
    getVerificationMessages,
    sendVerificationMessage,
    requestEvidence,
    verifyReport,
    rejectReport,
} from "../controller/verification_chat.js";

const router = express.Router();


router.post("/missingreports", createMissingReport);
router.post("/foundreports", createFoundReport);


router.get("/reports/monthly", getMonthlyReports);
router.get("/reports/yearly", getYearlyReports);

router.post("/tips", createTip);
router.get("/tips", getTips);
router.post("/alerts", createAlert);
router.get("/alerts", getAlerts);


router.get("/missingreports", getMissingReports);
router.get("/missingreports/:id/verification", getVerificationStatus);
router.get("/missingreports/:id/verification/messages", getVerificationMessages);
router.post("/missingreports/:id/verification/messages", sendVerificationMessage);
router.post("/missingreports/:id/verification/request-evidence", requestEvidence);
router.post("/missingreports/:id/verification/verify", verifyReport);
router.post("/missingreports/:id/verification/reject", rejectReport);
router.get("/missingreports/:id", getMissingReportById);
router.patch("/missingreports/:id", updateMissingReport);
router.delete("/missingreports/:id", deleteMissingReport);

router.get("/foundreports", getFoundReports);
router.get("/foundreports/:id", getFoundReportById);
router.patch("/foundreports/:id", updateFoundReport);
router.delete("/foundreports/:id", deleteFoundReport);




export default router;
