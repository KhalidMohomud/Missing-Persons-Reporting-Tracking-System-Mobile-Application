


import admin from "firebase-admin";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";


const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const serviceAccount = JSON.parse(
    fs.readFileSync(
        path.join(__dirname, "./mpts-997aa-firebase-adminsdk-fbsvc-015fda2129.json"),
        "utf8"
    )
);

console.log("🔥 Using Firebase Project:", serviceAccount.project_id);


admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
});


const db = admin.firestore();


const usersData = [
    {
        fullName: "Admin User",
        email: "admin@gmail.com",
        phone: "+252610000000",
        password: "123456",
        role: "admin",
    },
    {
        fullName: "Public Reporter",
        email: "user@gmail.com",
        phone: "+252612345678",
        password: "123456",
        role: "public",
    },
];

const missingReportsData = [
    {
        fullName: "Hassan Mohamed",
        age: 12,
        gender: "male",
        photo: "https://via.placeholder.com/150",
        lastSeenLocation: "Bakara Market, Mogadishu",
        lastSeenLat: 2.0469,
        lastSeenLng: 45.3182,
        lastSeenDate: "2026-01-20",
        contactName: "Mother",
        contactPhone: "+252612000111",
        description: "Wearing blue shirt and jeans.",
        status: "pending",
    },
];

const foundReportsData = [
    {
        estimatedAge: 30,
        gender: "female",
        photo: "https://via.placeholder.com/150",
        locationFound: "Hodan District, Mogadishu",
        foundLat: 2.0333,
        foundLng: 45.35,
        description: "Found walking alone near mosque.",
    },
];


async function seedMissingPersonsSystem() {
    try {
        console.log("\n🌱 Starting Firestore Seeding...\n");


        console.log("👤 Seeding Users...");

        const createdUsers = [];

        for (const user of usersData) {
            const userRef = await db.collection("users").add({
                ...user,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            createdUsers.push({
                id: userRef.id,
                role: user.role,
            });

            console.log(`✅ User Created: ${user.fullName} (ID: ${userRef.id})`);
        }

        const adminUserId = createdUsers.find((u) => u.role === "admin").id;
        const publicUserId = createdUsers.find((u) => u.role === "public").id;


        console.log("\n🚨 Seeding Missing Reports...");

        const createdMissingReports = [];

        for (const report of missingReportsData) {
            const reportRef = await db.collection("missingReports").add({
                ...report,
                reportedBy: publicUserId,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            createdMissingReports.push(reportRef.id);

            console.log(
                `✅ Missing Report Created: ${report.fullName} (ID: ${reportRef.id})`
            );
        }

        const missingReportId = createdMissingReports[0];

        console.log("\n🧍 Seeding Found Reports...");

        for (const report of foundReportsData) {
            const foundRef = await db.collection("foundReports").add({
                ...report,
                reportedBy: adminUserId,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            console.log(`✅ Found Report Created (ID: ${foundRef.id})`);
        }


        console.log("\n💡 Seeding Tips...");

        const tipRef = await db.collection("tips").add({
            reportId: missingReportId,
            message: "I saw this child near KM4 yesterday evening.",
            location: "KM4, Mogadishu",
            anonymous: true,
            senderId: null,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(`✅ Tip Created (ID: ${tipRef.id})`);


        console.log("\n📢 Seeding Alerts...");

        const alertRef = await db.collection("alerts").add({
            reportId: missingReportId,
            alertMessage: "🚨 Missing Child Alert in Bakara Area!",
            alertLocation: "Bakara Market",
            alertLat: 2.0469,
            alertLng: 45.3182,
            radiusKm: 5,
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(`✅ Alert Created (ID: ${alertRef.id})`);


        console.log("\n🎉 Firestore Seeding Completed Successfully!\n");
        process.exit();
    } catch (error) {
        console.error("\n❌ Error During Seeding:", error);
        process.exit(1);
    }
}

seedMissingPersonsSystem();
