<template>
  <div>
    <h2 style="margin-bottom:1.5rem">🗄️ Database</h2>

    <!-- Tables Overview -->
    <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:0.75rem;margin-bottom:1.5rem">
      <button v-for="t in tables" :key="t.name" @click="loadTable(t.name)"
        :style="{background: selectedTable === t.name ? '#059669' : '#111', border:'1px solid #333', borderRadius:'8px', padding:'0.75rem', textAlign:'left', cursor:'pointer', color:'#f3f4f6'}">
        <div style="font-weight:600">{{ t.name }}</div>
        <div style="font-size:0.8rem;color:#9ca3af">{{ t.rowCount }} rows</div>
      </button>
    </div>

    <!-- Table Data Viewer -->
    <div v-if="tableData" style="background:#111;border-radius:12px;padding:1.25rem;border:1px solid #222;margin-bottom:1.5rem;overflow-x:auto">
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:1rem">
        <h4>{{ selectedTable }} ({{ tableData.total }} rows)</h4>
        <div style="display:flex;gap:0.5rem">
          <button v-if="tableData.page > 1" @click="loadTable(selectedTable!, tableData.page - 1)" style="padding:0.25rem 0.75rem;background:#333">← Prev</button>
          <span style="padding:0.5rem;color:#9ca3af;font-size:0.85rem">Page {{ tableData.page }}</span>
          <button v-if="tableData.total > tableData.page * tableData.limit" @click="loadTable(selectedTable!, tableData.page + 1)" style="padding:0.25rem 0.75rem;background:#333">Next →</button>
        </div>
      </div>
      <table v-if="tableData.rows.length" style="font-size:0.8rem">
        <thead><tr><th v-for="col in Object.keys(tableData.rows[0])" :key="col">{{ col }}</th></tr></thead>
        <tbody>
          <tr v-for="(row, i) in tableData.rows" :key="i">
            <td v-for="col in Object.keys(row)" :key="col" style="max-width:200px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">
              {{ row[col] }}
            </td>
          </tr>
        </tbody>
      </table>
      <p v-else style="color:#6b7280">Table is empty</p>
    </div>

    <!-- SQL Query -->
    <div style="background:#111;border-radius:12px;padding:1.25rem;border:1px solid #222;margin-bottom:1.5rem">
      <h4 style="margin-bottom:1rem">🔍 SQL Query</h4>
      <textarea v-model="sql" rows="3" placeholder="SELECT * FROM users LIMIT 10" style="font-family:monospace;font-size:0.85rem"></textarea>
      <div style="display:flex;gap:0.5rem;margin-top:0.5rem">
        <button @click="runQuery(true)" style="background:#2563eb">▶ Run (Read-Only)</button>
        <button @click="runQuery(false)" style="background:#dc2626">⚠ Run (Write)</button>
      </div>
      <div v-if="queryResult" style="margin-top:1rem;overflow-x:auto">
        <pre v-if="queryResult.error" style="color:#f87171;font-size:0.8rem">{{ queryResult.error }}</pre>
        <div v-else-if="queryResult.rows">
          <p style="color:#9ca3af;font-size:0.8rem;margin-bottom:0.5rem">{{ queryResult.count }} rows</p>
          <table style="font-size:0.8rem">
            <thead><tr><th v-for="col in queryResult.cols" :key="col">{{ col }}</th></tr></thead>
            <tbody>
              <tr v-for="(row, i) in queryResult.rows" :key="i">
                <td v-for="col in queryResult.cols" :key="col">{{ row[col] }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <p v-else style="color:#10b981;font-size:0.85rem">{{ queryResult.changes }} rows affected</p>
      </div>
    </div>

    <!-- Backup & Restore -->
    <div style="background:#111;border-radius:12px;padding:1.25rem;border:1px solid #222">
      <h4 style="margin-bottom:1rem">💾 Backup & Restore</h4>
      <div style="display:flex;gap:0.75rem;flex-wrap:wrap;margin-bottom:1rem">
        <button @click="doBackup" :disabled="backingUp" style="background:#059669">
          {{ backingUp ? '⏳ Backing up...' : '📤 Backup Now' }}
        </button>
        <button @click="loadBackups" style="background:#2563eb">🔄 Refresh List</button>
      </div>
      <p v-if="backupMsg" :style="{color: backupMsg.ok ? '#10b981' : '#f87171', fontSize:'0.85rem', marginBottom:'1rem'}">{{ backupMsg.text }}</p>

      <div v-if="backups.length" style="max-height:300px;overflow-y:auto">
        <div v-for="b in backups" :key="b" style="display:flex;justify-content:space-between;align-items:center;padding:0.5rem;border-bottom:1px solid #222">
          <span style="font-size:0.85rem;color:#d1d5db">{{ b.replace(/-/g, ':').slice(0, 19) }}</span>
          <button @click="doRestore(b)" style="font-size:0.75rem;padding:0.25rem 0.5rem;background:#dc2626">🔄 Restore</button>
        </div>
      </div>
      <p v-else style="color:#6b7280;font-size:0.85rem">No backups found</p>
    </div>
  </div>
</template>

<script setup lang="ts">
const { api } = useApi();
const tables = ref<any[]>([]);
const selectedTable = ref<string | null>(null);
const tableData = ref<any>(null);
const sql = ref('');
const queryResult = ref<any>(null);
const backups = ref<string[]>([]);
const backingUp = ref(false);
const backupMsg = ref<any>(null);

async function loadTables() {
  try { tables.value = (await api('db/tables')).tables; } catch {}
}

async function loadTable(name: string, page = 1) {
  selectedTable.value = name;
  try { tableData.value = await api(`db/rows/${name}?page=${page}`); } catch {}
}

async function runQuery(readOnly: boolean) {
  queryResult.value = null;
  try {
    const res = await api('db/query', { method: 'POST', body: { sql: sql.value, readOnly } });
    if (res.rows) {
      queryResult.value = { rows: res.rows, count: res.count, cols: res.rows.length ? Object.keys(res.rows[0]) : [] };
    } else {
      queryResult.value = { changes: res.changes };
    }
    loadTables(); // refresh counts
  } catch (e: any) {
    queryResult.value = { error: e.data?.message || 'Query failed' };
  }
}

async function loadBackups() {
  try { backups.value = (await api('db/backups')).firebaseBackups; } catch {}
}

async function doBackup() {
  backingUp.value = true;
  backupMsg.value = null;
  try {
    const res = await api('db/backup', { method: 'POST' });
    backupMsg.value = { ok: true, text: `✅ Backup complete: ${res.totalRows} rows saved` };
    loadBackups();
  } catch (e: any) {
    backupMsg.value = { ok: false, text: `❌ ${e.data?.message || 'Backup failed'}` };
  } finally {
    backingUp.value = false;
  }
}

async function doRestore(ts: string) {
  if (!confirm(`⚠️ This will REPLACE all current data with backup from ${ts}. Continue?`)) return;
  try {
    const res = await api('db/restore', { method: 'POST', body: { timestamp: ts } });
    backupMsg.value = { ok: true, text: `✅ Restored ${res.totalRows} rows from ${res.tables.length} tables` };
    loadTables();
    if (selectedTable.value) loadTable(selectedTable.value);
  } catch (e: any) {
    backupMsg.value = { ok: false, text: `❌ ${e.data?.message || 'Restore failed'}` };
  }
}

onMounted(() => { loadTables(); loadBackups(); });
</script>
