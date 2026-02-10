import express from "express";
// import { requireAuth } from "@clerk/express";
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
import { getMonthlyReports } from "../controller/admin_reports.js";

const router = express.Router();


router.post("/missingreports", createMissingReport);
router.post("/foundreports", createFoundReport);


router.get("/reports/monthly", getMonthlyReports);


router.get("/missingreports", getMissingReports);
router.get("/missingreports/:id", getMissingReportById);
router.patch("/missingreports/:id", updateMissingReport);
router.delete("/missingreports/:id", deleteMissingReport);

router.get("/foundreports", getFoundReports);
router.get("/foundreports/:id", getFoundReportById);
router.patch("/foundreports/:id", updateFoundReport);
router.delete("/foundreports/:id", deleteFoundReport);




export default router;
