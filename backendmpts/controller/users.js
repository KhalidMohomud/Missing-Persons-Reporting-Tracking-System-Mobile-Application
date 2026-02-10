
import { Clerk } from "@clerk/clerk-sdk-node";
import { db, admin } from "../firebase/admin.js";
import bcrypt from "bcryptjs";
import crypto from "crypto";
import nodemailer from "nodemailer";


import dotenv from "dotenv";

dotenv.config();

const usersRef = db.collection("users");
const passwordResetsRef = db.collection("password_resets");


const clerk = new Clerk({
    secretKey: process.env.CLERK_SECRET_KEY || process.env.CLERK_API_KEY,
});

const RESET_CODE_TTL_MINUTES = Number.parseInt(process.env.RESET_CODE_TTL_MINUTES || "15", 10);
const RESET_CODE_RESEND_SECONDS = Number.parseInt(process.env.RESET_CODE_RESEND_SECONDS || "60", 10);
const RESET_CODE_MAX_ATTEMPTS = Number.parseInt(process.env.RESET_CODE_MAX_ATTEMPTS || "5", 10);
const RESET_CODE_SECRET = process.env.RESET_CODE_SECRET || "";

const smtpTransporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: Number.parseInt(process.env.SMTP_PORT || "587", 10),
    secure: process.env.SMTP_SECURE === "true",
    auth: process.env.SMTP_USER && process.env.SMTP_PASS
        ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS }
        : undefined,
});

const normalizeEmail = (email) => String(email || "").trim().toLowerCase();

const resolveUserEmail = (user, fallbackEmail) => {
    const normalized = normalizeEmail(fallbackEmail);
    const addresses = user?.emailAddresses || [];
    const match = addresses.find(addr => normalizeEmail(addr.emailAddress) === normalized);
    return match?.emailAddress || addresses[0]?.emailAddress || fallbackEmail;
};

const canSendResetCode = (resetData) => {
    if (!resetData?.lastSentAt?.toDate) return true;
    const lastSentAt = resetData.lastSentAt.toDate().getTime();
    return (Date.now() - lastSentAt) / 1000 >= RESET_CODE_RESEND_SECONDS;
};

const buildResetEmail = (code) => ({
    subject: "Your password reset code",
    text: `Your password reset code is ${code}. It expires in ${RESET_CODE_TTL_MINUTES} minutes.`,
    html: `<p>Your password reset code is <strong>${code}</strong>.</p><p>It expires in ${RESET_CODE_TTL_MINUTES} minutes.</p>`
});

// Get all users from Firestore
export const getAllUsers = async (req, res) => {
    try {
        const snapshot = await usersRef.orderBy("createdAt", "desc").get();

        if (snapshot.empty) {
            return res.status(200).json({
                success: true,
                data: [],
                message: "No users found"
            });
        }

        const users = snapshot.docs.map(doc => {
            const data = doc.data();
            return {
                id: doc.id,
                ...data,
                createdAt: data.createdAt?.toDate ? data.createdAt.toDate() : data.createdAt
            };
        });

        res.status(200).json({
            success: true,
            count: users.length,
            data: users,
        });

    } catch (err) {
        console.error("Error fetching users:", err);
        res.status(500).json({
            success: false,
            error: "Internal Server Error",
            message: err.message
        });
    }
};


export const createNewUser = async (req, res) => {
    try {
        const { email, fullName, password, phone, role } = req.body;

        if (!email || !password || !fullName) {
            return res.status(400).json({ error: "Missing required fields" });
        }

        const createUserPayload = {
            emailAddress: [email],
            password: password,
            firstName: fullName.split(" ")[0] || fullName,
            lastName: fullName.split(" ")[1] || "",
            publicMetadata: { role },
        };

        // Validate phone as E.164 if provided (e.g. +14155552671)
        if (phone) {
            const e164 = /^\+[1-9]\d{1,14}$/;
            if (!e164.test(phone)) {
                return res.status(400).json({
                    error: "Phone number must be in E.164 format (e.g. +252619006007)."
                });
            }
            createUserPayload.phoneNumber = [phone];
        }

        console.log("Clerk createUser payload:", JSON.stringify(createUserPayload, null, 2));

        const user = await clerk.users.createUser(createUserPayload);

        try {
            const firestoreUserRaw = {
                id: user.id,
                fullName,
                firstName: createUserPayload.firstName,
                lastName: createUserPayload.lastName,
                email: user.emailAddresses?.[0]?.emailAddress || null,
                phone: user.phoneNumbers?.[0]?.phoneNumber || null,
                role: role || null,
                createdAt: new Date(),
            };

            const firestoreUser = Object.fromEntries(
                Object.entries(firestoreUserRaw).filter(([_, v]) => v !== undefined)
            );

            await usersRef.doc(user.id).set(firestoreUser);
        } catch (fsErr) {
            console.error('Failed to write user to Firestore:', fsErr);
        }

        return res.status(201).json({
            message: "User created successfully",
            userId: user.id,
            email: user.emailAddresses?.[0]?.emailAddress || null,
            createdAt: user.createdAt,
        });
    } catch (err) {
        console.error(err);
        const status = err?.status || 500;
        const message = err?.errors?.[0]?.longMessage || err?.message || "Failed to create user";
        return res.status(status).json({ error: message });
    }
};


export const signInUser = async (req, res) => {
    try {
        const { email, password } = req.body;

        if (!email || !password) {
            return res.status(400).json({ error: 'Missing email or password' });
        }

        // Find user by email
        const matchedUsers = await clerk.users.getUserList({ emailAddress: [email] });
        const foundUser = Array.isArray(matchedUsers) ? matchedUsers[0] : matchedUsers?.data?.[0];

        if (!foundUser) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        // Verify password server-side
        try {
            await clerk.users.verifyPassword({ userId: foundUser.id, password });
        } catch (verifyErr) {
            console.error('Password verification failed:', verifyErr);
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        // Look up additional profile/role info from Firestore
        let role = 'public';
        let fullName = `${foundUser.firstName || ''} ${foundUser.lastName || ''}`.trim();

        try {
            const firestoreSnap = await usersRef.doc(foundUser.id).get();
            if (firestoreSnap.exists) {
                const data = firestoreSnap.data() || {};
                if (typeof data.fullName === 'string' && data.fullName.trim().length > 0) {
                    fullName = data.fullName.trim();
                }
                if (typeof data.role === 'string' && data.role.trim().length > 0) {
                    role = data.role.trim();
                }
            }
        } catch (profileErr) {
            console.error('Failed to read user profile from Firestore:', profileErr);
        }

        return res.status(200).json({
            message: 'User signed in (password verified)',
            userId: foundUser.id,
            email: email,
            fullName,
            role,
        });
    } catch (err) {
        console.error(err);
        return res.status(401).json({ error: "Invalid credentials" });
    }
};

export const forgotPassword = async (req, res) => {
    try {
        const { email } = req.body;

        if (!email) {
            return res.status(400).json({ error: "Missing email" });
        }

        if (!process.env.SMTP_HOST || !process.env.SMTP_FROM) {
            return res.status(500).json({ error: "Email service is not configured" });
        }

        const normalizedEmail = normalizeEmail(email);

        const matchedUsers = await clerk.users.getUserList({ emailAddress: [normalizedEmail] });
        const foundUser = Array.isArray(matchedUsers) ? matchedUsers[0] : matchedUsers?.data?.[0];

        if (!foundUser) {
            return res.status(200).json({
                message: "If an account exists for that email, a reset code has been sent."
            });
        }

        const resetDocRef = passwordResetsRef.doc(foundUser.id);
        const existingReset = await resetDocRef.get();
        const existingData = existingReset.exists ? existingReset.data() : null;

        if (existingData && !canSendResetCode(existingData)) {
            return res.status(200).json({
                message: "If an account exists for that email, a reset code has been sent."
            });
        }

        const code = crypto.randomInt(0, 1_000_000).toString().padStart(6, "0");
        const codeHash = await bcrypt.hash(code + RESET_CODE_SECRET, 10);
        const expiresAt = new Date(Date.now() + RESET_CODE_TTL_MINUTES * 60 * 1000);
        const targetEmail = resolveUserEmail(foundUser, normalizedEmail);

        await resetDocRef.set({
            userId: foundUser.id,
            email: targetEmail,
            codeHash,
            attempts: 0,
            expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
            createdAt: admin.firestore.Timestamp.now(),
            lastSentAt: admin.firestore.Timestamp.now(),
        }, { merge: true });

        const message = buildResetEmail(code);
        await smtpTransporter.sendMail({
            from: process.env.SMTP_FROM,
            to: targetEmail,
            subject: message.subject,
            text: message.text,
            html: message.html,
        });

        return res.status(200).json({
            message: "If an account exists for that email, a reset code has been sent."
        });
    } catch (err) {
        console.error("Forgot password error:", err);
        return res.status(500).json({ error: "Failed to send reset code" });
    }
};

export const resetPassword = async (req, res) => {
    try {
        const { email, code, newPassword } = req.body;

        if (!email || !code || !newPassword) {
            return res.status(400).json({ error: "Missing email, code, or newPassword" });
        }

        const normalizedEmail = normalizeEmail(email);
        const matchedUsers = await clerk.users.getUserList({ emailAddress: [normalizedEmail] });
        const foundUser = Array.isArray(matchedUsers) ? matchedUsers[0] : matchedUsers?.data?.[0];

        if (!foundUser) {
            return res.status(400).json({ error: "Invalid or expired code" });
        }

        const resetDocRef = passwordResetsRef.doc(foundUser.id);
        const resetSnap = await resetDocRef.get();
        if (!resetSnap.exists) {
            return res.status(400).json({ error: "Invalid or expired code" });
        }

        const resetData = resetSnap.data();
        const expiresAt = resetData?.expiresAt?.toDate ? resetData.expiresAt.toDate() : new Date(0);

        if (expiresAt.getTime() < Date.now()) {
            await resetDocRef.delete();
            return res.status(400).json({ error: "Invalid or expired code" });
        }

        if ((resetData?.attempts || 0) >= RESET_CODE_MAX_ATTEMPTS) {
            await resetDocRef.delete();
            return res.status(429).json({ error: "Too many invalid attempts. Request a new code." });
        }

        const isValid = await bcrypt.compare(String(code) + RESET_CODE_SECRET, resetData.codeHash || "");
        if (!isValid) {
            await resetDocRef.update({
                attempts: (resetData?.attempts || 0) + 1,
            });
            return res.status(400).json({ error: "Invalid or expired code" });
        }

        await clerk.users.updateUser(foundUser.id, {
            password: newPassword,
            signOutOfOtherSessions: true,
        });

        await resetDocRef.delete();

        return res.status(200).json({ message: "Password updated successfully" });
    } catch (err) {
        console.error("Reset password error:", err);
        const status = err?.status || 500;
        const message = err?.errors?.[0]?.longMessage || err?.message || "Failed to reset password";
        return res.status(status).json({ error: message });
    }
};
// export const socialLogin = async (req, res) => {
//     try {
//         // `req.auth` is added by requireAuth() middleware
//         const { userId, sessionId } = req.auth;

//         const user = await clerk.users.getUser(userId);

//         // Sync with Firestore if needed
//         const firestoreUser = await usersRef.doc(userId).get();
//         if (!firestoreUser.exists) {
//             await usersRef.doc(userId).set({
//                 id: user.id,
//                 fullName: user.firstName + " " + user.lastName,
//                 firstName: user.firstName,
//                 lastName: user.lastName,
//                 email: user.emailAddresses?.[0]?.emailAddress || null,
//                 phone: user.phoneNumbers?.[0]?.phoneNumber || null,
//                 role: user.publicMetadata?.role || "public",
//                 createdAt: new Date(),
//             });
//         }

//         res.status(200).json({
//             message: "Social login successful",
//             userId: user.id,
//             email: user.emailAddresses?.[0]?.emailAddress,
//             fullName: user.firstName + " " + user.lastName,
//             sessionId,
//         });
//     } catch (err) {
//         console.error(err);
//         res.status(500).json({ error: "Social login failed", message: err.message });
//     }
// };


export const socialLogin = async (req, res) => {
    try {
        const { sessionToken } = req.body;
        if (!sessionToken) return res.status(400).json({ error: "Missing sessionToken" });

        // Verify token with Clerk
        const session = await clerk.sessions.verifySessionToken(sessionToken);
        const user = await clerk.users.getUser(session.userId);

        // Sync with Firestore if new
        const firestoreUser = await usersRef.doc(user.id).get();
        if (!firestoreUser.exists) {
            await usersRef.doc(user.id).set({
                id: user.id,
                fullName: user.firstName + " " + user.lastName,
                firstName: user.firstName,
                lastName: user.lastName,
                email: user.emailAddresses?.[0]?.emailAddress || null,
                phone: user.phoneNumbers?.[0]?.phoneNumber || null,
                role: user.publicMetadata?.role || "public",
                createdAt: new Date(),
            });
        }

        res.status(200).json({
            message: "User verified",
            userId: user.id,
            email: user.emailAddresses?.[0]?.emailAddress,
            fullName: user.firstName + " " + user.lastName,
        });
    } catch (err) {
        console.error(err);
        res.status(401).json({ error: "Invalid session token", message: err.message });
    }
};
