// ============================================================================
// FIREBASE ADMIN — signed URLs, backup/restore to Realtime DB
// ============================================================================

import admin from 'firebase-admin';
import path from 'path';
import fs from 'fs';

let _init = false;

export function initFirebase() {
  if (_init) return;
  const saPath = path.resolve(process.env.FIREBASE_SERVICE_ACCOUNT_PATH || './firebase-service-account.json');
  const opts: admin.AppOptions = {
    storageBucket: process.env.FIREBASE_STORAGE_BUCKET,
    databaseURL: process.env.FIREBASE_DATABASE_URL,
  };
  if (fs.existsSync(saPath)) {
    opts.credential = admin.credential.cert(JSON.parse(fs.readFileSync(saPath, 'utf-8')));
  }
  admin.initializeApp(opts);
  _init = true;
}

export async function getSignedUrl(firebasePath: string): Promise<string> {
  initFirebase();
  const [url] = await admin.storage().bucket().file(firebasePath).getSignedUrl({
    action: 'read',
    expires: Date.now() + 15 * 60_000,
  });
  return url;
}

export async function uploadToFirebase(storagePath: string, data: Buffer, contentType: string = 'application/pdf'): Promise<void> {
  initFirebase();
  const bucket = admin.storage().bucket();
  const file = bucket.file(storagePath);
  await file.save(data, {
    metadata: { contentType },
    resumable: false,
  });
}

export async function backupToFirebase(data: Record<string, any[]>): Promise<string> {
  initFirebase();
  const db = admin.database();
  const ts = new Date().toISOString().replace(/[:.]/g, '-');
  await db.ref(`backups/${ts}`).set(data);

  // keep last 30 backups only
  const snap = await db.ref('backups').orderByKey().once('value');
  const keys = Object.keys(snap.val() || {}).sort();
  if (keys.length > 30) {
    const updates: Record<string, null> = {};
    for (const k of keys.slice(0, keys.length - 30)) updates[`backups/${k}`] = null;
    await db.ref().update(updates);
  }
  return ts;
}

export async function listBackups(): Promise<string[]> {
  initFirebase();
  const snap = await admin.database().ref('backups').orderByKey().once('value');
  return Object.keys(snap.val() || {}).sort().reverse();
}

export async function getBackupData(ts: string): Promise<Record<string, any[]>> {
  initFirebase();
  const snap = await admin.database().ref(`backups/${ts}`).once('value');
  return snap.val() || {};
}

/**
 * Publish server connection config to Firebase Realtime DB.
 * Flutter clients read /config on startup to discover WS and HTTP URLs.
 */
export async function publishServerConfig(): Promise<void> {
  initFirebase();
  const ip = process.env.SERVER_IP;
  const wsPort = process.env.WS_PORT || '3001';
  const httpPort = process.env.NUXT_PORT || '3000';
  if (!ip) {
    console.warn('[Firebase] SERVER_IP not set — skipping config publish');
    return;
  }
  await admin.database().ref('config').set({
    wsUrl: `ws://${ip}:${wsPort}`,
    serverDomain: `http://${ip}:${httpPort}`,
    updatedAt: new Date().toISOString(),
  });
  console.log(`[Firebase] Published server config: ws://${ip}:${wsPort}, http://${ip}:${httpPort}`);
}
