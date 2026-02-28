// ============================================================================
// Firebase Client SDK — direct browser-to-Firebase Storage uploads
// ============================================================================

import { initializeApp, getApps } from 'firebase/app';
import { getStorage, ref as storageRef, uploadBytes } from 'firebase/storage';

const firebaseConfig = {
  apiKey: 'AIzaSyDzt-DL35e3Ttknv7rH_1C3Fg0C4Hoy6iM',
  authDomain: 'python-hosting-server.firebaseapp.com',
  projectId: 'python-hosting-server',
  storageBucket: 'python-hosting-server.firebasestorage.app',
};

function getFirebaseStorage() {
  const app = getApps().length ? getApps()[0] : initializeApp(firebaseConfig);
  return getStorage(app);
}

/**
 * Upload a file directly from the browser to Firebase Storage.
 * Returns the storage path (not a URL).
 */
export async function uploadToFirebaseStorage(
  storagePath: string,
  file: File,
): Promise<string> {
  const storage = getFirebaseStorage();
  const fileRef = storageRef(storage, storagePath);
  await uploadBytes(fileRef, file, { contentType: file.type || 'application/pdf' });
  return storagePath;
}
