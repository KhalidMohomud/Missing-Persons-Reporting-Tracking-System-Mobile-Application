
import express from "express";
import {
    createNewUser,
    forgotPassword,
    getAllUsers,
    getUserById,
    resetPassword,
    signInUser,
    socialLogin,
    updateUser,
    deleteUser,
} from "../controller/users.js";
import { requireAuth } from "@clerk/express";


const router = express.Router();
router.get("/user", getAllUsers);
router.get("/user/:id", getUserById);
router.patch("/user/:id", updateUser);
router.delete("/user/:id", deleteUser);


router.get("/social-login", requireAuth(), socialLogin);
router.post("/user/signup", createNewUser);
router.post("/user/signin", signInUser);
router.post("/user/forgot-password", forgotPassword);
router.post("/user/reset-password", resetPassword);

export default router;
