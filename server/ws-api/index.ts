// ============================================================================
// WS-API SERVER — Single WebSocket server for ALL Flutter client communication
// 
// Protocol:
//   Client → Server: { rid: "uuid", action: "getPdfs", token: "jwt", data: {...} }
//   Server → Client: { rid: "uuid", status: "ok"|"error", data: {...}, error: null|"msg" }
//   Server Push:     { rid: null, event: "eventName", data: {...} }
//
// Actions: register, login, getPdfs, searchPdfs, getSubjects, getClasses,
//          getPdfUrl, checkSubscription, updateProfile, ping
// ============================================================================

import 'dotenv/config';
import { WebSocketServer, WebSocket } from 'ws';
import { v4 as uuid } from 'uuid';
import { getDb, getActiveSubscription, expireOldSubscriptions } from '../shared/db';
import { getSignedUrl, initFirebase } from '../shared/firebase';
import { hashPwd, checkPwd, signJwt, verifyJwt, TokenPayload } from '../shared/auth';
import http from 'http';
import os from 'os';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface ClientMsg {
  rid: string;
  action: string;
  token?: string;
  data?: any;
}

interface ServerMsg {
  rid: string | null;
  status?: 'ok' | 'error';
  event?: string;
  data?: any;
  error?: string | null;
}

interface ConnState {
  ws: WebSocket;
  userId: string | null;
  email: string | null;
  isAdmin: boolean;
  connectedAt: number;
  lastActive: number;
  msgCount: number;
  sessionId: string | null;
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

const PORT = parseInt(process.env.WS_PORT || '3001');
const connections = new Map<WebSocket, ConnState>();

// Rate limiter — max 60 messages per 10 seconds per connection
const RATE_WINDOW = 10_000;
const RATE_MAX = 60;
const rateBuckets = new Map<WebSocket, { count: number; resetAt: number }>();

function checkRate(ws: WebSocket): boolean {
  const now = Date.now();
  let bucket = rateBuckets.get(ws);
  if (!bucket || now > bucket.resetAt) {
    bucket = { count: 0, resetAt: now + RATE_WINDOW };
    rateBuckets.set(ws, bucket);
  }
  bucket.count++;
  return bucket.count <= RATE_MAX;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function send(ws: WebSocket, msg: ServerMsg) {
  if (ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(msg));
  }
}

function ok(ws: WebSocket, rid: string, data: any = {}) {
  send(ws, { rid, status: 'ok', data, error: null });
}

function err(ws: WebSocket, rid: string, error: string) {
  send(ws, { rid, status: 'error', data: null, error });
}

function push(ws: WebSocket, event: string, data: any = {}) {
  send(ws, { rid: null, event, data });
}

// Push to a specific user by userId (if connected)
function pushToUser(userId: string, event: string, data: any = {}) {
  for (const [, conn] of connections) {
    if (conn.userId === userId) push(conn.ws, event, data);
  }
}

// ---------------------------------------------------------------------------
// Action Handlers
// ---------------------------------------------------------------------------

const PUBLIC_ACTIONS = new Set(['register', 'login', 'ping']);

type Handler = (ws: WebSocket, conn: ConnState, rid: string, data: any) => void | Promise<void>;

const handlers: Record<string, Handler> = {

  // --- PING ---
  ping(ws, _conn, rid) {
    ok(ws, rid, { pong: true, time: Date.now() });
  },

  // --- REGISTER ---
  register(ws, conn, rid, data) {
    const { name, email, phone, password } = data || {};
    if (!name || !email || !password) return err(ws, rid, 'name, email, password required');
    if (typeof email !== 'string' || !email.includes('@')) return err(ws, rid, 'Invalid email');
    if (password.length < 6) return err(ws, rid, 'Password must be at least 6 characters');

    const db = getDb();
    const existing = db.prepare('SELECT id FROM users WHERE email = ?').get(email.toLowerCase().trim());
    if (existing) return err(ws, rid, 'Email already registered');

    const userId = uuid();
    const emailClean = email.toLowerCase().trim();
    db.prepare(`INSERT INTO users (id, name, email, phone, password_hash) VALUES (?, ?, ?, ?, ?)`)
      .run(userId, name.trim(), emailClean, phone || '', hashPwd(password));

    // Auto-create 'none' subscription
    db.prepare(`INSERT INTO subscriptions (id, user_id, status) VALUES (?, ?, 'none')`)
      .run(uuid(), userId);

    const token = signJwt({ userId, email: emailClean, isAdmin: false });
    const sessionId = uuid();
    db.prepare(`INSERT INTO sessions (id, user_id, device_info) VALUES (?, ?, ?)`)
      .run(sessionId, userId, data.deviceInfo || '');

    conn.userId = userId;
    conn.email = emailClean;
    conn.isAdmin = false;
    conn.sessionId = sessionId;

    ok(ws, rid, { token, user: { id: userId, name: name.trim(), email: emailClean, phone: phone || '' } });
  },

  // --- LOGIN ---
  login(ws, conn, rid, data) {
    const { email, password, token: existingToken } = data || {};

    const db = getDb();
    let user: any;

    // Token-based re-login (app restart)
    if (existingToken) {
      const payload = verifyJwt(existingToken);
      if (!payload) return err(ws, rid, 'Token expired, please login again');
      user = db.prepare('SELECT * FROM users WHERE id = ?').get(payload.userId);
      if (!user) return err(ws, rid, 'User not found');
    } else {
      // Email+password login
      if (!email || !password) return err(ws, rid, 'email and password required');
      user = db.prepare('SELECT * FROM users WHERE email = ?').get(email.toLowerCase().trim());
      if (!user) return err(ws, rid, 'Invalid email or password');
      if (!checkPwd(password, user.password_hash)) return err(ws, rid, 'Invalid email or password');
    }

    const token = signJwt({ userId: user.id, email: user.email, isAdmin: !!user.is_admin });
    const sessionId = uuid();
    db.prepare(`INSERT INTO sessions (id, user_id, device_info) VALUES (?, ?, ?)`)
      .run(sessionId, user.id, data.deviceInfo || '');

    conn.userId = user.id;
    conn.email = user.email;
    conn.isAdmin = !!user.is_admin;
    conn.sessionId = sessionId;

    // Check subscription
    const sub = getActiveSubscription(user.id);

    ok(ws, rid, {
      token,
      user: { id: user.id, name: user.name, email: user.email, phone: user.phone },
      subscription: sub ? { status: 'active', expiresAt: sub.expires_at } : { status: 'none', expiresAt: null },
    });
  },

  // --- GET SUBJECTS ---
  getSubjects(ws, _conn, rid) {
    const rows = getDb().prepare('SELECT id, name, icon_name, display_order FROM subjects ORDER BY display_order').all();
    ok(ws, rid, { subjects: rows });
  },

  // --- GET CLASSES (with PDF counts) ---
  getClasses(ws, _conn, rid, data) {
    const db = getDb();
    let rows: any[];
    if (data?.subjectId) {
      // Classes that have PDFs for a specific subject
      rows = db.prepare(`
        SELECT class_level, COUNT(*) as pdf_count
        FROM pdfs WHERE subject_id = ? AND is_active = 1
        GROUP BY class_level ORDER BY class_level
      `).all(data.subjectId);
    } else {
      // All classes with any PDFs
      rows = db.prepare(`
        SELECT class_level, COUNT(*) as pdf_count
        FROM pdfs WHERE is_active = 1
        GROUP BY class_level ORDER BY class_level
      `).all();
    }
    ok(ws, rid, { classes: rows });
  },

  // --- GET PDFS ---
  getPdfs(ws, _conn, rid, data) {
    const db = getDb();
    const { classLevel, subjectId, page = 1, limit = 30 } = data || {};
    const offset = (Math.max(1, page) - 1) * limit;

    let where = 'WHERE is_active = 1';
    const params: any[] = [];
    if (classLevel) { where += ' AND class_level = ?'; params.push(classLevel); }
    if (subjectId) { where += ' AND subject_id = ?'; params.push(subjectId); }

    const total = (db.prepare(`SELECT COUNT(*) as c FROM pdfs ${where}`).get(...params) as any).c;
    const pdfs = db.prepare(`
      SELECT p.id, p.title, p.description, p.class_level, p.subject_id, s.name as subject_name,
             p.thumbnail_url, p.page_count, p.file_size_kb, p.created_at
      FROM pdfs p JOIN subjects s ON p.subject_id = s.id
      ${where} ORDER BY p.created_at DESC LIMIT ? OFFSET ?
    `).all(...params, limit, offset);

    ok(ws, rid, { pdfs, total, page, limit });
  },

  // --- SEARCH PDFS ---
  searchPdfs(ws, _conn, rid, data) {
    const { query, page = 1, limit = 30 } = data || {};
    if (!query || query.length < 2) return err(ws, rid, 'Search query must be at least 2 characters');

    const db = getDb();
    const q = `%${query}%`;
    const offset = (Math.max(1, page) - 1) * limit;

    const total = (db.prepare(`SELECT COUNT(*) as c FROM pdfs WHERE is_active = 1 AND (title LIKE ? OR description LIKE ?)`).get(q, q) as any).c;
    const pdfs = db.prepare(`
      SELECT p.id, p.title, p.description, p.class_level, p.subject_id, s.name as subject_name,
             p.thumbnail_url, p.page_count, p.file_size_kb, p.created_at
      FROM pdfs p JOIN subjects s ON p.subject_id = s.id
      WHERE p.is_active = 1 AND (p.title LIKE ? OR p.description LIKE ?)
      ORDER BY p.created_at DESC LIMIT ? OFFSET ?
    `).all(q, q, limit, offset);

    ok(ws, rid, { pdfs, total, page, limit });
  },

  // --- GET PDF URL (subscription gated) ---
  async getPdfUrl(ws, conn, rid, data) {
    if (!data?.pdfId) return err(ws, rid, 'pdfId required');

    const sub = getActiveSubscription(conn.userId!);
    if (!sub) return err(ws, rid, 'SUBSCRIPTION_REQUIRED');

    const pdf = getDb().prepare('SELECT * FROM pdfs WHERE id = ? AND is_active = 1').get(data.pdfId) as any;
    if (!pdf) return err(ws, rid, 'PDF not found');

    try {
      const url = await getSignedUrl(pdf.firebase_path);
      ok(ws, rid, { url, expiresInSec: 900 }); // 15 min
    } catch (e: any) {
      err(ws, rid, 'Failed to generate download URL');
    }
  },

  // --- CHECK SUBSCRIPTION ---
  checkSubscription(ws, conn, rid) {
    const sub = getActiveSubscription(conn.userId!);
    ok(ws, rid, sub
      ? { status: 'active', expiresAt: sub.expires_at, razorpayId: sub.razorpay_subscription_id }
      : { status: 'none', expiresAt: null, razorpayId: null }
    );
  },

  // --- UPDATE PROFILE ---
  updateProfile(ws, conn, rid, data) {
    const { name, phone } = data || {};
    if (!name && !phone) return err(ws, rid, 'Nothing to update');

    const db = getDb();
    const sets: string[] = [];
    const params: any[] = [];
    if (name) { sets.push('name = ?'); params.push(name.trim()); }
    if (phone !== undefined) { sets.push('phone = ?'); params.push(phone); }
    sets.push("updated_at = datetime('now')");
    params.push(conn.userId!);

    db.prepare(`UPDATE users SET ${sets.join(', ')} WHERE id = ?`).run(...params);
    const user = db.prepare('SELECT id, name, email, phone FROM users WHERE id = ?').get(conn.userId!) as any;
    ok(ws, rid, { user });
  },

  // --- CHANGE PASSWORD ---
  changePassword(ws, conn, rid, data) {
    const { currentPassword, newPassword } = data || {};
    if (!currentPassword || !newPassword) return err(ws, rid, 'currentPassword and newPassword required');
    if (newPassword.length < 6) return err(ws, rid, 'Password must be at least 6 characters');

    const db = getDb();
    const user = db.prepare('SELECT password_hash FROM users WHERE id = ?').get(conn.userId!) as any;
    if (!checkPwd(currentPassword, user.password_hash)) return err(ws, rid, 'Current password is wrong');

    db.prepare('UPDATE users SET password_hash = ?, updated_at = datetime(\'now\') WHERE id = ?')
      .run(hashPwd(newPassword), conn.userId!);
    ok(ws, rid, { changed: true });
  },
};

// ---------------------------------------------------------------------------
// Server setup
// ---------------------------------------------------------------------------

const server = http.createServer((_req, res) => {
  // Health check endpoint for Nginx
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ status: 'ok', connections: connections.size }));
});

const wss = new WebSocketServer({ server, maxPayload: 64 * 1024 }); // 64KB max message

wss.on('connection', (ws, req) => {
  const conn: ConnState = {
    ws,
    userId: null,
    email: null,
    isAdmin: false,
    connectedAt: Date.now(),
    lastActive: Date.now(),
    msgCount: 0,
    sessionId: null,
  };
  connections.set(ws, conn);

  // Heartbeat — detect dead connections
  let alive = true;
  ws.on('pong', () => { alive = true; });
  const heartbeat = setInterval(() => {
    if (!alive) { ws.terminate(); return; }
    alive = false;
    ws.ping();
  }, 30_000);

  ws.on('message', async (raw) => {
    conn.lastActive = Date.now();
    conn.msgCount++;

    // Rate limit
    if (!checkRate(ws)) {
      return send(ws, { rid: null, event: 'rate_limited', data: { message: 'Too many requests, slow down' } });
    }

    // Parse
    let msg: ClientMsg;
    try {
      msg = JSON.parse(raw.toString());
    } catch {
      return send(ws, { rid: null, event: 'parse_error', data: { message: 'Invalid JSON' } });
    }

    const { rid, action, token, data } = msg;
    if (!rid || !action) {
      return send(ws, { rid: rid || null, status: 'error', data: null, error: 'rid and action required' });
    }

    // Auth check (skip for public actions)
    if (!PUBLIC_ACTIONS.has(action)) {
      if (!conn.userId) {
        // Try to auth from token in message
        if (token) {
          const payload = verifyJwt(token);
          if (payload) {
            conn.userId = payload.userId;
            conn.email = payload.email;
            conn.isAdmin = payload.isAdmin;
          }
        }
        if (!conn.userId) {
          return err(ws, rid, 'AUTH_REQUIRED');
        }
      }
      // Update session activity
      if (conn.sessionId) {
        getDb().prepare("UPDATE sessions SET last_active = datetime('now') WHERE id = ?").run(conn.sessionId);
      }
    }

    // Route to handler
    const handler = handlers[action];
    if (!handler) return err(ws, rid, `Unknown action: ${action}`);

    try {
      await handler(ws, conn, rid, data || {});
    } catch (e: any) {
      console.error(`[WS] Error in ${action}:`, e.message);
      err(ws, rid, 'Internal server error');
    }
  });

  ws.on('close', () => {
    clearInterval(heartbeat);
    rateBuckets.delete(ws);
    // Mark session closed
    if (conn.sessionId) {
      try { getDb().prepare("UPDATE sessions SET last_active = datetime('now') WHERE id = ?").run(conn.sessionId); } catch {}
    }
    connections.delete(ws);
  });

  ws.on('error', () => {
    clearInterval(heartbeat);
    connections.delete(ws);
  });
});

// ---------------------------------------------------------------------------
// Background jobs
// ---------------------------------------------------------------------------

// Expire subscriptions every 5 minutes
setInterval(() => {
  try { expireOldSubscriptions(); } catch (e) { console.error('[CRON] expireSubscriptions:', e); }
}, 5 * 60_000);

// Collect metrics every minute
setInterval(() => {
  try {
    const cpus = os.cpus();
    const cpuPercent = cpus.reduce((acc, cpu) => {
      const total = Object.values(cpu.times).reduce((a, b) => a + b, 0);
      return acc + ((total - cpu.times.idle) / total) * 100;
    }, 0) / cpus.length;

    const mem = os.totalmem();
    const free = os.freemem();
    getDb().prepare(`INSERT INTO metrics (cpu_percent, mem_used_mb, mem_total_mb, ws_connections) VALUES (?, ?, ?, ?)`)
      .run(Math.round(cpuPercent * 10) / 10, Math.round((mem - free) / 1048576), Math.round(mem / 1048576), connections.size);

    // Keep only last 24h of metrics (1440 rows)
    getDb().prepare(`DELETE FROM metrics WHERE id NOT IN (SELECT id FROM metrics ORDER BY id DESC LIMIT 1440)`).run();
  } catch (e) { console.error('[CRON] metrics:', e); }
}, 60_000);

// ---------------------------------------------------------------------------
// Exports for admin API inter-process queries
// ---------------------------------------------------------------------------
export function getWsStats() {
  return {
    connections: connections.size,
    users: [...connections.values()].filter(c => c.userId).map(c => ({
      userId: c.userId,
      email: c.email,
      connectedAt: c.connectedAt,
      lastActive: c.lastActive,
      msgCount: c.msgCount,
    })),
  };
}

// Notify user of subscription change (called from admin/razorpay webhook)
export { pushToUser };

// ---------------------------------------------------------------------------
// Start
// ---------------------------------------------------------------------------

try { initFirebase(); } catch (e) { console.warn('[WS] Firebase init skipped:', (e as any).message); }

// Init DB on startup
getDb();
console.log(`[DB] SQLite ready (WAL mode)`);

server.listen(PORT, () => {
  console.log(`[WS] WebSocket server listening on :${PORT}`);
  console.log(`[WS] Health check: http://localhost:${PORT}/`);
});
