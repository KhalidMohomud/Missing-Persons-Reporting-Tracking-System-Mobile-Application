import admin from "firebase-admin";
import dotenv from "dotenv";
import { createPrivateKey } from "crypto";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const defaultServiceAccountPath = path.resolve(
  __dirname,
  "../mpts.json"
);

const configuredServiceAccountPath =
  process.env.FIREBASE_SERVICE_ACCOUNT_PATH || process.env.GOOGLE_APPLICATION_CREDENTIALS;

const normalizePrivateKey = (privateKey = "") =>
  privateKey.replace(/\\n/g, "\n").trim();

const normalizeServiceAccount = (serviceAccount) => ({
  projectId: serviceAccount.projectId || serviceAccount.project_id,
  clientEmail: serviceAccount.clientEmail || serviceAccount.client_email,
  privateKey: normalizePrivateKey(serviceAccount.privateKey || serviceAccount.private_key || ""),
});

const assertValidPrivateKey = (privateKey, source) => {
  try {
    createPrivateKey(privateKey);
  } catch {
    throw new Error(
      `Firebase private key loaded from ${source} is not a valid PEM private key. If you use .env, put FIREBASE_PRIVATE_KEY on one line with escaped newlines (\\n), or set FIREBASE_SERVICE_ACCOUNT_PATH to a valid service-account JSON file.`
    );
  }
};

const readServiceAccountFromEnv = () => {
  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  const privateKey = process.env.FIREBASE_PRIVATE_KEY;

  if (!projectId || !clientEmail || !privateKey) {
    return null;
  }

  return {
    source: "environment variables",
    serviceAccount: normalizeServiceAccount({ projectId, clientEmail, privateKey }),
  };
};

const readServiceAccountFromFile = (configuredPath = defaultServiceAccountPath) => {
  const serviceAccountPath = path.isAbsolute(configuredPath)
    ? configuredPath
    : path.resolve(process.cwd(), configuredPath);

  if (!fs.existsSync(serviceAccountPath)) {
    return null;
  }

  try {
    const fileContents = fs.readFileSync(serviceAccountPath, "utf8");
    return {
      source: `service account file (${serviceAccountPath})`,
      serviceAccount: normalizeServiceAccount(JSON.parse(fileContents)),
    };
  } catch (error) {
    throw new Error(
      `Failed to read Firebase service account file at ${serviceAccountPath}: ${error.message}`
    );
  }
};

const resolveFirebaseCredentials = () => {
  let envCredentialsError = null;

  if (configuredServiceAccountPath) {
    const configuredFileCredentials = readServiceAccountFromFile(configuredServiceAccountPath);
    if (configuredFileCredentials) {
      assertValidPrivateKey(
        configuredFileCredentials.serviceAccount.privateKey,
        configuredFileCredentials.source
      );
      return configuredFileCredentials;
    }

    throw new Error(
      `Firebase service account file was not found at ${configuredServiceAccountPath}. Check FIREBASE_SERVICE_ACCOUNT_PATH / GOOGLE_APPLICATION_CREDENTIALS.`
    );
  }

  try {
    const envCredentials = readServiceAccountFromEnv();
    if (envCredentials) {
      assertValidPrivateKey(envCredentials.serviceAccount.privateKey, envCredentials.source);
      return envCredentials;
    }
  } catch (error) {
    envCredentialsError = error;
  }

  const fileCredentials = readServiceAccountFromFile();
  if (fileCredentials) {
    assertValidPrivateKey(fileCredentials.serviceAccount.privateKey, fileCredentials.source);
    return fileCredentials;
  }

  if (envCredentialsError) {
    throw envCredentialsError;
  }

  throw new Error(
    "Firebase Admin credentials were not found. Set FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, and FIREBASE_PRIVATE_KEY, or point FIREBASE_SERVICE_ACCOUNT_PATH / GOOGLE_APPLICATION_CREDENTIALS to a valid service-account JSON file."
  );
};

const initializeFirebase = () => {
  if (admin.apps.length > 0) {
    return admin.app();
  }

  const { source, serviceAccount } = resolveFirebaseCredentials();

  if (!serviceAccount.projectId || !serviceAccount.clientEmail || !serviceAccount.privateKey) {
    throw new Error(
      `Firebase Admin credentials loaded from ${source} are incomplete. Expected projectId, clientEmail, and privateKey.`
    );
  }

  const app = admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: serviceAccount.projectId,
  });

  console.info(
    `[firebase] Initialized Admin SDK for project "${serviceAccount.projectId}" using ${source}.`
  );

  return app;
};

initializeFirebase();

const db = admin.firestore();

export { db, admin };
