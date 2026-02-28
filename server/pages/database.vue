<template>
  <div>
    <div class="page-header">
      <div>
        <h2>Database</h2>
        <p class="page-description">Browse tables, run queries, and manage backups</p>
      </div>
    </div>

    <!-- Tables Overview -->
    <div class="table-selector mb-6">
      <button v-for="t in tables" :key="t.name" @click="loadTable(t.name)"
        :class="['table-btn', { active: selectedTable === t.name }]">
        <span class="table-btn-name">{{ t.name }}</span>
        <span class="table-btn-count">{{ t.rowCount }} rows</span>
      </button>
    </div>

    <!-- Table Data Viewer -->
    <div v-if="tableData" class="card mb-6">
      <div class="card-header">
        <h4>{{ selectedTable }} <span class="row-count">({{ tableData.total }} rows)</span></h4>
        <div class="pagination" style="margin:0;border:none;padding:0">
          <button v-if="tableData.page > 1" @click="loadTable(selectedTable!, tableData.page - 1)" class="btn-sm">Previous</button>
          <span class="page-info">Page {{ tableData.page }}</span>
          <button v-if="tableData.total > tableData.page * tableData.limit" @click="loadTable(selectedTable!, tableData.page + 1)" class="btn-sm">Next</button>
        </div>
      </div>
      <div class="table-container">
        <table v-if="tableData.rows.length" class="table-compact">
          <thead><tr><th v-for="col in Object.keys(tableData.rows[0])" :key="col">{{ col }}</th></tr></thead>
          <tbody>
            <tr v-for="(row, i) in tableData.rows" :key="i">
              <td v-for="col in Object.keys(row)" :key="col" class="cell-truncate">
                {{ row[col] }}
              </td>
            </tr>
          </tbody>
        </table>
        <div v-else class="empty-state">Table is empty</div>
      </div>
    </div>

    <!-- SQL Query -->
    <div class="card mb-6">
      <div class="card-header">
        <h4>SQL Query</h4>
      </div>
      <textarea v-model="sql" rows="3" placeholder="SELECT * FROM users LIMIT 10" class="sql-input"></textarea>
      <div class="flex gap-3 mt-3">
        <button @click="runQuery(true)" class="btn-info">Run (Read-Only)</button>
        <button @click="runQuery(false)" class="btn-danger">Run (Write)</button>
      </div>
      <div v-if="queryResult" class="mt-4">
        <pre v-if="queryResult.error" class="query-error">{{ queryResult.error }}</pre>
        <div v-else-if="queryResult.rows">
          <p class="query-count mb-3">{{ queryResult.count }} rows returned</p>
          <div class="table-container">
            <table class="table-compact">
              <thead><tr><th v-for="col in queryResult.cols" :key="col">{{ col }}</th></tr></thead>
              <tbody>
                <tr v-for="(row, i) in queryResult.rows" :key="i">
                  <td v-for="col in queryResult.cols" :key="col">{{ row[col] }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
        <p v-else class="query-success">{{ queryResult.changes }} rows affected</p>
      </div>
    </div>

    <!-- Backup & Restore -->
    <div class="card">
      <div class="card-header">
        <h4>Backup & Restore</h4>
      </div>
      <div class="flex gap-3 flex-wrap mb-4">
        <button @click="doBackup" :disabled="backingUp" class="btn-primary">
          {{ backingUp ? 'Backing up...' : 'Backup Now' }}
        </button>
        <button @click="loadBackups">Refresh List</button>
      </div>
      <p v-if="backupMsg" :class="['backup-msg', backupMsg.ok ? 'msg-success' : 'msg-error']">{{ backupMsg.text }}</p>

      <div v-if="backups.length" class="backup-list">
        <div v-for="b in backups" :key="b" class="backup-item">
          <span class="backup-name">{{ b.replace(/-/g, ':').slice(0, 19) }}</span>
          <button @click="doRestore(b)" class="btn-sm btn-danger">Restore</button>
        </div>
      </div>
      <div v-else class="empty-state">No backups found</div>
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
    backupMsg.value = { ok: true, text: `Backup complete: ${res.totalRows} rows saved` };
    loadBackups();
  } catch (e: any) {
    backupMsg.value = { ok: false, text: e.data?.message || 'Backup failed' };
  } finally {
    backingUp.value = false;
  }
}

async function doRestore(ts: string) {
  if (!confirm(`This will REPLACE all current data with backup from ${ts}. Continue?`)) return;
  try {
    const res = await api('db/restore', { method: 'POST', body: { timestamp: ts } });
    backupMsg.value = { ok: true, text: `Restored ${res.totalRows} rows from ${res.tables.length} tables` };
    loadTables();
    if (selectedTable.value) loadTable(selectedTable.value);
  } catch (e: any) {
    backupMsg.value = { ok: false, text: e.data?.message || 'Restore failed' };
  }
}

onMounted(() => { loadTables(); loadBackups(); });
</script>

<style scoped>
.table-selector {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
  gap: var(--space-3);
}

.table-btn {
  display: flex;
  flex-direction: column;
  gap: 4px;
  padding: var(--space-4);
  background: var(--color-bg-surface);
  border: 1px solid var(--color-border-subtle);
  border-radius: var(--radius-lg);
  text-align: left;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.table-btn:hover {
  border-color: var(--color-border-default);
  background: var(--color-bg-elevated);
}

.table-btn.active {
  border-color: var(--color-accent);
  background: var(--color-accent-subtle);
}

.table-btn-name {
  font-weight: 600;
  font-size: 0.8125rem;
  color: var(--color-text-primary);
}

.table-btn-count {
  font-size: 0.75rem;
  color: var(--color-text-tertiary);
}

.table-btn.active .table-btn-count {
  color: var(--color-accent-text);
}

.table-container {
  overflow-x: auto;
}

.table-compact {
  font-size: 0.8125rem;
}

.cell-truncate {
  max-width: 200px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.row-count {
  font-weight: 400;
  color: var(--color-text-tertiary);
  font-size: 0.8125rem;
}

.sql-input {
  font-family: var(--font-mono);
  font-size: 0.8125rem;
}

.query-error {
  color: var(--color-danger);
  background: var(--color-danger-subtle);
  border-color: transparent;
}

.query-count {
  font-size: 0.8125rem;
  color: var(--color-text-tertiary);
}

.query-success {
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--color-success);
}

.backup-msg {
  font-size: 0.8125rem;
  padding: 10px 14px;
  border-radius: var(--radius-md);
  margin-bottom: var(--space-4);
}

.msg-success {
  background: var(--color-success-subtle);
  color: var(--color-success);
}

.msg-error {
  background: var(--color-danger-subtle);
  color: var(--color-danger);
}

.backup-list {
  max-height: 300px;
  overflow-y: auto;
}

.backup-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--space-3) var(--space-4);
  border-bottom: 1px solid var(--color-border-subtle);
}

.backup-item:last-child {
  border-bottom: none;
}

.backup-name {
  font-size: 0.8125rem;
  font-family: var(--font-mono);
  color: var(--color-text-secondary);
}
</style>
