// ============================================================================
// SHARED DATABASE — used by BOTH NuxtJS admin APIs and WS-API server
// WAL mode = safe concurrent read/write from two processes
// better-sqlite3 = synchronous, 5x faster than async sqlite3
// ============================================================================

import Database from 'better-sqlite3';
import path from 'path';
import fs from 'fs';

const DB_PATH = path.resolve(process.cwd(), 'data', 'app.db');
fs.mkdirSync(path.dirname(DB_PATH), { recursive: true });

let _db: Database.Database | null = null;

export function getDb(): Database.Database {
  if (_db) return _db;
  _db = new Database(DB_PATH);

  // Performance pragmas — critical for <50ms responses
  _db.pragma('journal_mode = WAL');
  _db.pragma('synchronous = NORMAL');
  _db.pragma('cache_size = -20000'); // 20MB cache
  _db.pragma('busy_timeout = 5000'); // wait 5s if locked
  _db.pragma('foreign_keys = ON');

  _db.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      email TEXT UNIQUE NOT NULL COLLATE NOCASE,
      phone TEXT DEFAULT '',
      password_hash TEXT NOT NULL,
      is_admin INTEGER DEFAULT 0,
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS subjects (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL UNIQUE,
      icon_name TEXT DEFAULT 'book',
      display_order INTEGER DEFAULT 0,
      created_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS pdfs (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      description TEXT DEFAULT '',
      class_level INTEGER NOT NULL CHECK(class_level BETWEEN 1 AND 12),
      subject_id TEXT NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
      firebase_path TEXT NOT NULL,
      thumbnail_url TEXT DEFAULT '',
      page_count INTEGER DEFAULT 0,
      file_size_kb INTEGER DEFAULT 0,
      is_active INTEGER DEFAULT 1,
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS subscriptions (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      status TEXT NOT NULL DEFAULT 'none' CHECK(status IN ('none','active','expired','cancelled')),
      razorpay_subscription_id TEXT DEFAULT '',
      razorpay_payment_id TEXT DEFAULT '',
      amount INTEGER DEFAULT 0,
      started_at TEXT,
      expires_at TEXT,
      created_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS payments (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      razorpay_payment_id TEXT DEFAULT '',
      razorpay_subscription_id TEXT DEFAULT '',
      amount INTEGER DEFAULT 0,
      status TEXT DEFAULT 'captured',
      created_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS sessions (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      device_info TEXT DEFAULT '',
      created_at TEXT DEFAULT (datetime('now')),
      last_active TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS backup_history (
      id TEXT PRIMARY KEY,
      type TEXT DEFAULT 'manual' CHECK(type IN ('auto','manual')),
      row_count INTEGER DEFAULT 0,
      status TEXT DEFAULT 'pending' CHECK(status IN ('pending','success','failed')),
      error_message TEXT DEFAULT '',
      created_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS metrics (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      cpu_percent REAL DEFAULT 0,
      mem_used_mb REAL DEFAULT 0,
      mem_total_mb REAL DEFAULT 0,
      ws_connections INTEGER DEFAULT 0,
      created_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS deploy_history (
      id TEXT PRIMARY KEY,
      branch TEXT DEFAULT 'main',
      commit_hash TEXT DEFAULT '',
      status TEXT DEFAULT 'pending' CHECK(status IN ('pending','running','success','failed')),
      log TEXT DEFAULT '',
      duration_ms INTEGER DEFAULT 0,
      created_at TEXT DEFAULT (datetime('now'))
    );

    -- Speed indexes
    CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
    CREATE INDEX IF NOT EXISTS idx_pdfs_class_subject ON pdfs(class_level, subject_id, is_active);
    CREATE INDEX IF NOT EXISTS idx_pdfs_active ON pdfs(is_active);
    CREATE INDEX IF NOT EXISTS idx_subs_user ON subscriptions(user_id, status);
    CREATE INDEX IF NOT EXISTS idx_payments_user ON payments(user_id);
    CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id);
    CREATE INDEX IF NOT EXISTS idx_metrics_time ON metrics(created_at);

    -- Default subjects
    INSERT OR IGNORE INTO subjects (id, name, icon_name, display_order) VALUES
      ('sub_math','Mathematics','calculate',1),
      ('sub_sci','Science','science',2),
      ('sub_eng','English','translate',3),
      ('sub_soc','Social Studies','public',4),
      ('sub_hin','Hindi','language',5),
      ('sub_tam','Tamil','language',6),
      ('sub_phy','Physics','bolt',7),
      ('sub_chem','Chemistry','biotech',8),
      ('sub_bio','Biology','eco',9),
      ('sub_comp','Computer Science','computer',10);
  `);

  return _db;
}

// ---------------------------------------------------------------------------
// Query helpers
// ---------------------------------------------------------------------------

export function getActiveSubscription(userId: string) {
  return getDb().prepare(`
    SELECT * FROM subscriptions
    WHERE user_id = ? AND status = 'active' AND datetime(expires_at) > datetime('now')
    ORDER BY expires_at DESC LIMIT 1
  `).get(userId) as any | undefined;
}

export function expireOldSubscriptions() {
  return getDb().prepare(`
    UPDATE subscriptions SET status = 'expired'
    WHERE status = 'active' AND datetime(expires_at) <= datetime('now')
  `).run();
}

export function getTableNames(): string[] {
  return (getDb().prepare(
    `SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name`
  ).all() as any[]).map(r => r.name);
}

export function getAllData(): Record<string, any[]> {
  const db = getDb();
  const data: Record<string, any[]> = {};
  for (const t of getTableNames()) {
    data[t] = db.prepare(`SELECT * FROM "${t}"`).all();
  }
  return data;
}

export function restoreAllData(data: Record<string, any[]>) {
  const db = getDb();
  db.transaction(() => {
    db.pragma('foreign_keys = OFF');
    for (const table of Object.keys(data)) db.prepare(`DELETE FROM "${table}"`).run();
    for (const [table, rows] of Object.entries(data)) {
      if (!rows.length) continue;
      const cols = Object.keys(rows[0]);
      const ph = cols.map(() => '?').join(',');
      const stmt = db.prepare(`INSERT OR REPLACE INTO "${table}" (${cols.join(',')}) VALUES (${ph})`);
      for (const row of rows) stmt.run(...cols.map(c => row[c]));
    }
    db.pragma('foreign_keys = ON');
  })();
}

export function getTableRowCount(table: string): number {
  return (getDb().prepare(`SELECT COUNT(*) as c FROM "${table}"`).get() as any).c;
}
