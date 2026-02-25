// ============================================================================
// ALL ADMIN REST APIs — single file, all endpoints
// Route: /api/admin/[...action].ts — catches /api/admin/login, /api/admin/stats, etc.
// ============================================================================

import { getDb, getTableNames, getAllData, restoreAllData, getTableRowCount, getActiveSubscription, expireOldSubscriptions } from '../../../shared/db';
import { backupToFirebase, listBackups, getBackupData } from '../../../shared/firebase';
import { hashPwd, checkPwd, signJwt } from '../../../shared/auth';
import { v4 as uuid } from 'uuid';
import { exec } from 'child_process';
import { promisify } from 'util';
import os from 'os';
import http from 'http';

const execAsync = promisify(exec);

export default defineEventHandler(async (event) => {
  const url = getRequestURL(event);
  const method = getMethod(event);
  // Extract action path: /api/admin/stats → "stats", /api/admin/db/tables → "db/tables"
  const action = url.pathname.replace('/api/admin/', '').replace(/\/$/, '');

  try {
    // ===== LOGIN (public) =====
    if (action === 'login' && method === 'POST') {
      const { email, password } = await readBody(event);
      const config = useRuntimeConfig();
      if (email !== config.adminEmail || password !== config.adminPassword) {
        throw createError({ statusCode: 401, message: 'Invalid credentials' });
      }
      // Check if admin user exists in DB, create if not
      const db = getDb();
      let admin = db.prepare('SELECT * FROM users WHERE email = ? AND is_admin = 1').get(email) as any;
      if (!admin) {
        const id = uuid();
        db.prepare('INSERT OR IGNORE INTO users (id, name, email, password_hash, is_admin) VALUES (?, ?, ?, ?, 1)')
          .run(id, 'Admin', email, hashPwd(password));
        admin = { id, email };
      }
      const token = signJwt({ userId: admin.id, email, isAdmin: true });
      setCookie(event, 'admin_token', token, { httpOnly: false, maxAge: 30 * 86400, path: '/' });
      return { token, email };
    }

    // ===== DASHBOARD STATS =====
    if (action === 'stats' && method === 'GET') {
      const db = getDb();
      const totalUsers = (db.prepare('SELECT COUNT(*) as c FROM users WHERE is_admin = 0').get() as any).c;
      const activeSubs = (db.prepare(`SELECT COUNT(*) as c FROM subscriptions WHERE status = 'active' AND datetime(expires_at) > datetime('now')`).get() as any).c;
      const totalPdfs = (db.prepare('SELECT COUNT(*) as c FROM pdfs').get() as any).c;
      const totalPayments = (db.prepare('SELECT COALESCE(SUM(amount), 0) as s FROM payments WHERE status = \'captured\'').get() as any).s;
      const recentPayments = db.prepare(`
        SELECT p.*, u.name as user_name, u.email as user_email
        FROM payments p JOIN users u ON p.user_id = u.id
        ORDER BY p.created_at DESC LIMIT 10
      `).all();

      // WS connections from ws-api health endpoint
      let wsConnections = 0;
      try {
        const res = await new Promise<string>((resolve) => {
          http.get(`http://localhost:${process.env.WS_PORT || 3001}/`, (r) => {
            let d = '';
            r.on('data', c => d += c);
            r.on('end', () => resolve(d));
          }).on('error', () => resolve('{}'));
        });
        wsConnections = JSON.parse(res).connections || 0;
      } catch {}

      const mem = os.totalmem();
      const free = os.freemem();
      return {
        totalUsers, activeSubs, totalPdfs, totalPayments,
        recentPayments,
        wsConnections,
        server: {
          cpuCount: os.cpus().length,
          memUsedMb: Math.round((mem - free) / 1048576),
          memTotalMb: Math.round(mem / 1048576),
          uptime: Math.round(os.uptime()),
          platform: os.platform(),
        },
      };
    }

    // ===== MONITOR — Metrics history =====
    if (action === 'monitor/metrics' && method === 'GET') {
      const hours = parseInt(getQuery(event).hours as string) || 24;
      const rows = getDb().prepare(`
        SELECT * FROM metrics WHERE datetime(created_at) > datetime('now', '-${hours} hours') ORDER BY created_at
      `).all();
      return { metrics: rows };
    }

    // ===== DEPLOY — Status =====
    if (action === 'deploy/status' && method === 'GET') {
      const cwd = process.cwd();
      let branch = '', commit = '';
      try {
        const { stdout: b } = await execAsync('git rev-parse --abbrev-ref HEAD', { cwd });
        branch = b.trim();
        const { stdout: c } = await execAsync('git rev-parse --short HEAD', { cwd });
        commit = c.trim();
      } catch {}
      const history = getDb().prepare('SELECT * FROM deploy_history ORDER BY created_at DESC LIMIT 30').all();
      // List deploy_* branches from remote
      let deployBranches: string[] = [];
      try {
        await execAsync('git fetch origin --prune', { cwd, timeout: 15000 });
        const { stdout } = await execAsync('git branch -r --format="%(refname:short)"', { cwd });
        deployBranches = stdout.trim().split('\n')
          .map(b => b.replace('origin/', '').trim())
          .filter(b => b.startsWith('deploy_'))
          .sort().reverse();
      } catch {}
      return { branch, commit, history, deployBranches };
    }

    // ===== DEPLOY — Deploy from main =====
    // Flow: clone to temp → build → stop PM2 → copy artifacts → start PM2 → create deploy branch → cleanup
    if (action === 'deploy/run' && method === 'POST') {
      const db = getDb();
      const deployId = uuid();
      const startTime = Date.now();
      const cwd = process.cwd();
      const tempDir = `${cwd}/_deploy_temp`;
      const logs: string[] = [];

      // Get remote origin URL
      let originUrl = '';
      try {
        const { stdout } = await execAsync('git remote get-url origin', { cwd });
        originUrl = stdout.trim();
      } catch {
        throw createError({ statusCode: 500, message: 'Could not determine git remote origin URL' });
      }

      db.prepare("INSERT INTO deploy_history (id, branch, type, status) VALUES (?, 'main', 'deploy', 'running')").run(deployId);

      try {
        // 1. Clean up any leftover temp dir
        await execAsync(`rm -rf "${tempDir}"`, { cwd }).catch(() => {});

        // 2. Shallow clone main branch into temp
        logs.push('--- Clone main into temp ---');
        const { stdout: cloneLog } = await execAsync(
          `git clone --depth 1 --branch main "${originUrl}" "${tempDir}" 2>&1`,
          { cwd, timeout: 60000 }
        );
        logs.push(cloneLog);

        // 3. Get the commit hash from the clone
        const { stdout: commitHash } = await execAsync('git rev-parse --short HEAD', { cwd: tempDir });

        // 4. Install deps & build everything in temp
        logs.push('--- Install dependencies ---');
        const { stdout: installLog } = await execAsync('npm install 2>&1', { cwd: tempDir, timeout: 120000 });
        logs.push(installLog);

        logs.push('--- Build Nuxt admin UI ---');
        const { stdout: nuxtLog } = await execAsync('npx nuxt build 2>&1', { cwd: tempDir, timeout: 120000 });
        logs.push(nuxtLog);

        logs.push('--- Build WS-API ---');
        const { stdout: wsLog } = await execAsync('npx tsc -p ws-api/tsconfig.json 2>&1', { cwd: tempDir, timeout: 60000 });
        logs.push(wsLog);

        // 5. Stop both PM2 processes
        logs.push('--- Stopping PM2 processes ---');
        const { stdout: stopLog } = await execAsync(
          'pm2 stop admin-ui ws-api 2>&1 || echo "PM2 stop: some processes may not be running"',
          { cwd, timeout: 15000 }
        );
        logs.push(stopLog);

        // 6. Copy built artifacts over (keep data/, .env, node_modules intact)
        logs.push('--- Copying built artifacts ---');
        // Admin UI output
        await execAsync(`rm -rf "${cwd}/.output" && cp -r "${tempDir}/.output" "${cwd}/.output"`, { cwd, timeout: 30000 });
        // WS-API dist
        await execAsync(`rm -rf "${cwd}/ws-api/dist" && cp -r "${tempDir}/ws-api/dist" "${cwd}/ws-api/dist"`, { cwd, timeout: 15000 });
        // Copy updated source files (shared, server, ws-api src, configs etc.)
        await execAsync(
          `cp -r "${tempDir}/shared" "${cwd}/" && ` +
          `cp -r "${tempDir}/server" "${cwd}/" && ` +
          `cp -r "${tempDir}/ws-api/index.ts" "${cwd}/ws-api/" && ` +
          `cp -f "${tempDir}/package.json" "${cwd}/" && ` +
          `cp -f "${tempDir}/ecosystem.config.cjs" "${cwd}/" && ` +
          `cp -f "${tempDir}/nuxt.config.ts" "${cwd}/" 2>&1`,
          { cwd, timeout: 15000 }
        );
        logs.push('Artifacts copied successfully');

        // 7. Reinstall production deps in main dir (in case package.json changed)
        const { stdout: mainInstall } = await execAsync('npm install --production 2>&1', { cwd, timeout: 120000 });
        logs.push(mainInstall);

        // 8. Start both PM2 processes
        logs.push('--- Starting PM2 processes ---');
        const { stdout: startLog } = await execAsync(
          'pm2 start ecosystem.config.cjs 2>&1',
          { cwd, timeout: 15000 }
        );
        logs.push(startLog);

        // 9. Create deploy branch on origin
        const now = new Date();
        const dateStr = `${now.getFullYear()}_${String(now.getMonth() + 1).padStart(2, '0')}_${String(now.getDate()).padStart(2, '0')}`;
        // Find next sequence number for today
        let seq = 1;
        try {
          const { stdout: existing } = await execAsync(
            `git branch -r --format="%(refname:short)" | grep "origin/deploy_${dateStr}_" | wc -l`,
            { cwd, timeout: 10000 }
          );
          seq = parseInt(existing.trim()) + 1 || 1;
        } catch {}
        const deployBranch = `deploy_${dateStr}_${seq}`;

        logs.push(`--- Creating deploy branch: ${deployBranch} ---`);
        await execAsync(
          `cd "${tempDir}" && git checkout -b "${deployBranch}" && git push origin "${deployBranch}" 2>&1`,
          { cwd: tempDir, timeout: 30000 }
        );
        logs.push(`Branch ${deployBranch} pushed to origin`);

        // 10. Cleanup temp
        await execAsync(`rm -rf "${tempDir}"`, { cwd }).catch(() => {});

        const duration = Date.now() - startTime;
        db.prepare('UPDATE deploy_history SET status = ?, commit_hash = ?, deploy_branch = ?, log = ?, duration_ms = ? WHERE id = ?')
          .run('success', commitHash.trim(), deployBranch, logs.join('\n'), duration, deployId);

        return { status: 'success', deployId, duration, commit: commitHash.trim(), deployBranch };
      } catch (e: any) {
        // Try to restart PM2 even if deploy failed (best effort recovery)
        await execAsync('pm2 start ecosystem.config.cjs 2>&1', { cwd, timeout: 15000 }).catch(() => {});
        // Cleanup temp
        await execAsync(`rm -rf "${tempDir}"`, { cwd }).catch(() => {});

        const duration = Date.now() - startTime;
        db.prepare('UPDATE deploy_history SET status = ?, log = ?, duration_ms = ? WHERE id = ?')
          .run('failed', logs.join('\n') + '\n--- ERROR ---\n' + e.message + '\n' + (e.stderr || ''), duration, deployId);
        throw createError({ statusCode: 500, message: e.message });
      }
    }

    // ===== DEPLOY — Rollback to a deploy_* branch =====
    if (action === 'deploy/rollback' && method === 'POST') {
      const { deployBranch } = await readBody(event);
      if (!deployBranch || !/^deploy_\d{4}_\d{2}_\d{2}_\d+$/.test(deployBranch)) {
        throw createError({ statusCode: 400, message: 'Invalid deploy branch name' });
      }
      const db = getDb();
      const deployId = uuid();
      const startTime = Date.now();
      const cwd = process.cwd();
      const tempDir = `${cwd}/_deploy_temp`;
      const logs: string[] = [];

      let originUrl = '';
      try {
        const { stdout } = await execAsync('git remote get-url origin', { cwd });
        originUrl = stdout.trim();
      } catch {
        throw createError({ statusCode: 500, message: 'Could not determine git remote origin URL' });
      }

      db.prepare("INSERT INTO deploy_history (id, branch, type, status) VALUES (?, ?, 'rollback', 'running')").run(deployId, deployBranch);

      try {
        await execAsync(`rm -rf "${tempDir}"`, { cwd }).catch(() => {});

        // Clone the deploy branch
        logs.push(`--- Clone ${deployBranch} into temp ---`);
        const { stdout: cloneLog } = await execAsync(
          `git clone --depth 1 --branch "${deployBranch}" "${originUrl}" "${tempDir}" 2>&1`,
          { cwd, timeout: 60000 }
        );
        logs.push(cloneLog);

        const { stdout: commitHash } = await execAsync('git rev-parse --short HEAD', { cwd: tempDir });

        // Build in temp
        logs.push('--- Install dependencies ---');
        const { stdout: installLog } = await execAsync('npm install 2>&1', { cwd: tempDir, timeout: 120000 });
        logs.push(installLog);

        logs.push('--- Build Nuxt admin UI ---');
        const { stdout: nuxtLog } = await execAsync('npx nuxt build 2>&1', { cwd: tempDir, timeout: 120000 });
        logs.push(nuxtLog);

        logs.push('--- Build WS-API ---');
        const { stdout: wsLog } = await execAsync('npx tsc -p ws-api/tsconfig.json 2>&1', { cwd: tempDir, timeout: 60000 });
        logs.push(wsLog);

        // Stop PM2
        logs.push('--- Stopping PM2 processes ---');
        const { stdout: stopLog } = await execAsync(
          'pm2 stop admin-ui ws-api 2>&1 || echo "PM2 stop: some processes may not be running"',
          { cwd, timeout: 15000 }
        );
        logs.push(stopLog);

        // Copy artifacts
        logs.push('--- Copying built artifacts ---');
        await execAsync(`rm -rf "${cwd}/.output" && cp -r "${tempDir}/.output" "${cwd}/.output"`, { cwd, timeout: 30000 });
        await execAsync(`rm -rf "${cwd}/ws-api/dist" && cp -r "${tempDir}/ws-api/dist" "${cwd}/ws-api/dist"`, { cwd, timeout: 15000 });
        await execAsync(
          `cp -r "${tempDir}/shared" "${cwd}/" && ` +
          `cp -r "${tempDir}/server" "${cwd}/" && ` +
          `cp -r "${tempDir}/ws-api/index.ts" "${cwd}/ws-api/" && ` +
          `cp -f "${tempDir}/package.json" "${cwd}/" && ` +
          `cp -f "${tempDir}/ecosystem.config.cjs" "${cwd}/" && ` +
          `cp -f "${tempDir}/nuxt.config.ts" "${cwd}/" 2>&1`,
          { cwd, timeout: 15000 }
        );
        logs.push('Artifacts copied');

        const { stdout: mainInstall } = await execAsync('npm install --production 2>&1', { cwd, timeout: 120000 });
        logs.push(mainInstall);

        // Start PM2
        logs.push('--- Starting PM2 processes ---');
        const { stdout: startLog } = await execAsync('pm2 start ecosystem.config.cjs 2>&1', { cwd, timeout: 15000 });
        logs.push(startLog);

        // Cleanup temp
        await execAsync(`rm -rf "${tempDir}"`, { cwd }).catch(() => {});

        const duration = Date.now() - startTime;
        db.prepare('UPDATE deploy_history SET status = ?, commit_hash = ?, deploy_branch = ?, log = ?, duration_ms = ? WHERE id = ?')
          .run('success', commitHash.trim(), deployBranch, logs.join('\n'), duration, deployId);

        return { status: 'success', deployId, duration, commit: commitHash.trim(), deployBranch };
      } catch (e: any) {
        await execAsync('pm2 start ecosystem.config.cjs 2>&1', { cwd, timeout: 15000 }).catch(() => {});
        await execAsync(`rm -rf "${tempDir}"`, { cwd }).catch(() => {});

        const duration = Date.now() - startTime;
        db.prepare('UPDATE deploy_history SET status = ?, log = ?, duration_ms = ? WHERE id = ?')
          .run('failed', logs.join('\n') + '\n--- ERROR ---\n' + e.message + '\n' + (e.stderr || ''), duration, deployId);
        throw createError({ statusCode: 500, message: e.message });
      }
    }

    // ===== DB — List tables =====
    if (action === 'db/tables' && method === 'GET') {
      const tables = getTableNames().map(name => ({
        name, rowCount: getTableRowCount(name),
      }));
      return { tables };
    }

    // ===== DB — Get table rows =====
    if (action.startsWith('db/rows/') && method === 'GET') {
      const table = action.replace('db/rows/', '');
      const q = getQuery(event);
      const page = parseInt(q.page as string) || 1;
      const limit = Math.min(parseInt(q.limit as string) || 50, 200);
      const offset = (page - 1) * limit;
      const db = getDb();
      const total = getTableRowCount(table);
      const rows = db.prepare(`SELECT * FROM "${table}" LIMIT ? OFFSET ?`).all(limit, offset);
      return { table, rows, total, page, limit };
    }

    // ===== DB — Run query (read-only by default) =====
    if (action === 'db/query' && method === 'POST') {
      const { sql, readOnly = true } = await readBody(event);
      if (!sql) throw createError({ statusCode: 400, message: 'sql required' });
      const db = getDb();
      if (readOnly) {
        const rows = db.prepare(sql).all();
        return { rows, count: rows.length };
      } else {
        const result = db.prepare(sql).run();
        return { changes: result.changes };
      }
    }

    // ===== DB — Backup to Firebase =====
    if (action === 'db/backup' && method === 'POST') {
      const db = getDb();
      const backupId = uuid();
      db.prepare('INSERT INTO backup_history (id, type, status) VALUES (?, \'manual\', \'pending\')').run(backupId);
      try {
        const data = getAllData();
        const totalRows = Object.values(data).reduce((s, arr) => s + arr.length, 0);
        const ts = await backupToFirebase(data);
        db.prepare('UPDATE backup_history SET status = ?, row_count = ? WHERE id = ?').run('success', totalRows, backupId);
        return { backupId, timestamp: ts, totalRows };
      } catch (e: any) {
        db.prepare('UPDATE backup_history SET status = ?, error_message = ? WHERE id = ?').run('failed', e.message, backupId);
        throw createError({ statusCode: 500, message: e.message });
      }
    }

    // ===== DB — List backups =====
    if (action === 'db/backups' && method === 'GET') {
      const [firebaseBackups, localHistory] = await Promise.all([
        listBackups().catch(() => []),
        Promise.resolve(getDb().prepare('SELECT * FROM backup_history ORDER BY created_at DESC LIMIT 50').all()),
      ]);
      return { firebaseBackups, localHistory };
    }

    // ===== DB — Restore from Firebase =====
    if (action === 'db/restore' && method === 'POST') {
      const { timestamp } = await readBody(event);
      if (!timestamp) throw createError({ statusCode: 400, message: 'timestamp required' });
      const data = await getBackupData(timestamp);
      if (!Object.keys(data).length) throw createError({ statusCode: 404, message: 'Backup not found or empty' });
      restoreAllData(data);
      return { restored: true, tables: Object.keys(data), totalRows: Object.values(data).reduce((s, a) => s + a.length, 0) };
    }

    // ===== DB — Backup history =====
    if (action === 'db/history' && method === 'GET') {
      return { history: getDb().prepare('SELECT * FROM backup_history ORDER BY created_at DESC LIMIT 50').all() };
    }

    // ===== PDFS — List =====
    if (action === 'pdfs' && method === 'GET') {
      const q = getQuery(event);
      const page = parseInt(q.page as string) || 1;
      const limit = Math.min(parseInt(q.limit as string) || 50, 200);
      const offset = (page - 1) * limit;
      const db = getDb();
      const total = (db.prepare('SELECT COUNT(*) as c FROM pdfs').get() as any).c;
      const pdfs = db.prepare(`
        SELECT p.*, s.name as subject_name FROM pdfs p
        LEFT JOIN subjects s ON p.subject_id = s.id
        ORDER BY p.created_at DESC LIMIT ? OFFSET ?
      `).all(limit, offset);
      return { pdfs, total, page, limit };
    }

    // ===== PDFS — Create =====
    if (action === 'pdfs' && method === 'POST') {
      const body = await readBody(event);
      const { title, description, classLevel, subjectId, firebasePath, thumbnailUrl, pageCount, fileSizeKb } = body;
      if (!title || !classLevel || !subjectId || !firebasePath) {
        throw createError({ statusCode: 400, message: 'title, classLevel, subjectId, firebasePath required' });
      }
      const id = uuid();
      getDb().prepare(`INSERT INTO pdfs (id, title, description, class_level, subject_id, firebase_path, thumbnail_url, page_count, file_size_kb)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`).run(id, title, description || '', classLevel, subjectId, firebasePath, thumbnailUrl || '', pageCount || 0, fileSizeKb || 0);
      return { id, created: true };
    }

    // ===== PDFS — Update =====
    if (action.startsWith('pdfs/') && method === 'PUT') {
      const pdfId = action.replace('pdfs/', '');
      const body = await readBody(event);
      const db = getDb();
      const fields: string[] = [];
      const params: any[] = [];
      for (const [key, val] of Object.entries(body)) {
        const col = key === 'classLevel' ? 'class_level' : key === 'subjectId' ? 'subject_id' :
          key === 'firebasePath' ? 'firebase_path' : key === 'thumbnailUrl' ? 'thumbnail_url' :
          key === 'pageCount' ? 'page_count' : key === 'fileSizeKb' ? 'file_size_kb' :
          key === 'isActive' ? 'is_active' : key;
        if (['title','description','class_level','subject_id','firebase_path','thumbnail_url','page_count','file_size_kb','is_active'].includes(col)) {
          fields.push(`${col} = ?`);
          params.push(val);
        }
      }
      if (!fields.length) throw createError({ statusCode: 400, message: 'Nothing to update' });
      fields.push("updated_at = datetime('now')");
      params.push(pdfId);
      db.prepare(`UPDATE pdfs SET ${fields.join(',')} WHERE id = ?`).run(...params);
      return { updated: true };
    }

    // ===== PDFS — Delete =====
    if (action.startsWith('pdfs/') && method === 'DELETE') {
      const pdfId = action.replace('pdfs/', '');
      getDb().prepare('DELETE FROM pdfs WHERE id = ?').run(pdfId);
      return { deleted: true };
    }

    // ===== SUBJECTS — List =====
    if (action === 'subjects' && method === 'GET') {
      return { subjects: getDb().prepare('SELECT * FROM subjects ORDER BY display_order').all() };
    }

    // ===== SUBJECTS — Create =====
    if (action === 'subjects' && method === 'POST') {
      const { name, iconName, displayOrder } = await readBody(event);
      if (!name) throw createError({ statusCode: 400, message: 'name required' });
      const id = 'sub_' + name.toLowerCase().replace(/[^a-z0-9]/g, '_').slice(0, 20);
      getDb().prepare('INSERT INTO subjects (id, name, icon_name, display_order) VALUES (?, ?, ?, ?)')
        .run(id, name, iconName || 'book', displayOrder || 0);
      return { id, created: true };
    }

    // ===== SUBJECTS — Update =====
    if (action.startsWith('subjects/') && method === 'PUT') {
      const subId = action.replace('subjects/', '');
      const body = await readBody(event);
      const fields: string[] = [];
      const params: any[] = [];
      if (body.name) { fields.push('name = ?'); params.push(body.name); }
      if (body.iconName) { fields.push('icon_name = ?'); params.push(body.iconName); }
      if (body.displayOrder !== undefined) { fields.push('display_order = ?'); params.push(body.displayOrder); }
      if (!fields.length) throw createError({ statusCode: 400, message: 'Nothing to update' });
      params.push(subId);
      getDb().prepare(`UPDATE subjects SET ${fields.join(',')} WHERE id = ?`).run(...params);
      return { updated: true };
    }

    // ===== SUBJECTS — Delete =====
    if (action.startsWith('subjects/') && method === 'DELETE') {
      const subId = action.replace('subjects/', '');
      getDb().prepare('DELETE FROM subjects WHERE id = ?').run(subId);
      return { deleted: true };
    }

    // ===== USERS — List =====
    if (action === 'users' && method === 'GET') {
      const q = getQuery(event);
      const page = parseInt(q.page as string) || 1;
      const limit = Math.min(parseInt(q.limit as string) || 50, 200);
      const offset = (page - 1) * limit;
      const db = getDb();
      const total = (db.prepare('SELECT COUNT(*) as c FROM users WHERE is_admin = 0').get() as any).c;
      const users = db.prepare(`
        SELECT u.id, u.name, u.email, u.phone, u.created_at,
          (SELECT status FROM subscriptions WHERE user_id = u.id ORDER BY created_at DESC LIMIT 1) as sub_status,
          (SELECT expires_at FROM subscriptions WHERE user_id = u.id AND status = 'active' ORDER BY expires_at DESC LIMIT 1) as sub_expires
        FROM users u WHERE u.is_admin = 0
        ORDER BY u.created_at DESC LIMIT ? OFFSET ?
      `).all(limit, offset);
      return { users, total, page, limit };
    }

    // ===== USERS — Get single =====
    if (action.startsWith('users/') && method === 'GET') {
      const userId = action.replace('users/', '');
      const db = getDb();
      const user = db.prepare('SELECT id, name, email, phone, created_at FROM users WHERE id = ?').get(userId);
      if (!user) throw createError({ statusCode: 404, message: 'User not found' });
      const subs = db.prepare('SELECT * FROM subscriptions WHERE user_id = ? ORDER BY created_at DESC').all(userId);
      const payments = db.prepare('SELECT * FROM payments WHERE user_id = ? ORDER BY created_at DESC').all(userId);
      return { user, subscriptions: subs, payments };
    }

    throw createError({ statusCode: 404, message: `Unknown admin endpoint: ${action}` });

  } catch (e: any) {
    if (e.statusCode) throw e;
    console.error(`[ADMIN API] ${action}:`, e.message);
    throw createError({ statusCode: 500, message: e.message });
  }
});
