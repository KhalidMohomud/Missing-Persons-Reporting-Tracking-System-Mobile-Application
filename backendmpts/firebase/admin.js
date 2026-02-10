
import admin from "firebase-admin";
import fs from "fs";

// Load Firebase credentials
const serviceAccount = JSON.parse(
  fs.readFileSync(new URL("../mpts-997aa-firebase-adminsdk-fbsvc-015fda2129.json", import.meta.url)) // adjust path if needed
);

// Initialize Firebase admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

export { db, admin };

