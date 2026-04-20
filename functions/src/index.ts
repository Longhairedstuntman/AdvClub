import {onCall, HttpsError} from "firebase-functions/v2/https";
import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {getFirestore, FieldValue} from "firebase-admin/firestore";

initializeApp();

export const createUser = onCall(async (request) => {
  const caller = request.auth;
  if (!caller) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }

  const db = getFirestore();
  const callerDoc = await db.collection("users").doc(caller.uid).get();

  if (!callerDoc.exists) {
    throw new HttpsError(
      "permission-denied",
      "Caller profile not found.",
    );
  }

  const callerData = callerDoc.data();
  if (!callerData || callerData.role !== "admin") {
    throw new HttpsError(
      "permission-denied",
      "Only admins can create users.",
    );
  }

  const email = String(request.data.email ?? "").trim().toLowerCase();
  const password = String(request.data.password ?? "").trim();
  const displayName = String(request.data.displayName ?? "").trim();
  const role = String(request.data.role ?? "member").trim().toLowerCase();

  if (!email) {
    throw new HttpsError("invalid-argument", "Email is required.");
  }

  if (!password) {
    throw new HttpsError("invalid-argument", "Password is required.");
  }

  if (!displayName) {
    throw new HttpsError("invalid-argument", "Display name is required.");
  }

  if (role !== "member" && role !== "admin") {
    throw new HttpsError(
      "invalid-argument",
      "Role must be member or admin.",
    );
  }

  try {
    const userRecord = await getAuth().createUser({
      email,
      password,
      displayName,
      disabled: false,
    });

    await db.collection("users").doc(userRecord.uid).set({
      email,
      displayName,
      role,
      isActive: true,
      quarterlyAllowance: 30,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    return {
      uid: userRecord.uid,
      email,
      displayName,
      role,
      isActive: true,
      quarterlyAllowance: 30,
    };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : "Unknown error";
    throw new HttpsError("already-exists", message);
  }
});
