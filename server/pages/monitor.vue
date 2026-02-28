<template>
  <div>
    <div class="page-header">
      <div>
        <h2>Monitor</h2>
        <p class="page-description">WebSocket API status, system resources, and request logs</p>
      </div>
    </div>

    <!-- WS-API Status & Controls -->
    <div class="card mb-6">
      <div class="card-header">
        <div class="flex items-center gap-3">
          <h4>WebSocket API</h4>
          <span :class="['badge', wsStatus?.running ? 'badge-success' : 'badge-danger']">
            <span :class="['status-dot', wsStatus?.running ? 'online' : 'offline']"></span>
            {{ wsStatus?.running ? 'Running' : 'Stopped' }}
          </span>
        </div>
        <div class="flex gap-2">
          <button v-if="!wsStatus?.running" @click="wsControl('start')" :disabled="!!wsBusy" class="btn-sm btn-primary">Start</button>
          <button v-if="wsStatus?.running" @click="wsControl('stop')" :disabled="!!wsBusy" class="btn-sm btn-danger">Stop</button>
          <button v-if="wsStatus?.running" @click="wsControl('restart')" :disabled="!!wsBusy" class="btn-sm btn-warning">Restart</button>
        </div>
      </div>

      <div v-if="wsMsg" :class="['ws-msg', wsMsg.ok ? 'msg-success' : 'msg-error']">
        {{ wsMsg.text }}
      </div>

      <template v-if="wsStatus?.running">
        <!-- Summary cards -->
        <div class="ws-stat-grid mb-5">
          <div v-for="c in wsCards" :key="c.label" class="ws-stat-item">
            <div class="ws-stat-label">{{ c.label }}</div>
            <div class="ws-stat-value" :style="{color: c.color || 'var(--color-text-primary)'}">{{ c.value }}</div>
          </div>
        </div>

        <!-- Connected Users -->
        <div v-if="wsStatus.connectedUsers?.length" class="section mb-5">
          <h5 class="section-title">Connected Users ({{ wsStatus.connectedUsers.length }})</h5>
          <div class="table-container">
            <table>
              <thead><tr><th>Email</th><th>Connected</th><th>Last Active</th><th>Messages</th></tr></thead>
              <tbody>
                <tr v-for="u in wsStatus.connectedUsers" :key="u.userId">
                  <td class="text-primary">{{ u.email || '(anonymous)' }}</td>
                  <td>{{ timeAgo(u.connectedAt) }}</td>
                  <td>{{ timeAgo(u.lastActive) }}</td>
                  <td>{{ u.msgCount }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <!-- Action Stats -->
        <div v-if="Object.keys(wsStatus.actions || {}).length" class="section mb-5">
          <h5 class="section-title">Action Stats</h5>
          <div class="table-container">
            <table>
              <thead><tr><th>Action</th><th>Calls</th><th>Errors</th><th>Avg (ms)</th><th>Last Called</th></tr></thead>
              <tbody>
                <tr v-for="(s, name) in sortedActions" :key="name">
                  <td><code>{{ name }}</code></td>
                  <td>{{ s.count }}</td>
                  <td>
                    <span :class="s.errors > 0 ? 'text-danger' : 'text-muted'">{{ s.errors }}</span>
                  </td>
                  <td>{{ s.avgMs }}ms</td>
                  <td>{{ timeAgo(s.lastCalledAt) }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <!-- Recent Requests -->
        <div v-if="wsStatus.recentRequests?.length" class="section">
          <h5 class="section-title">Recent Requests</h5>
          <div class="table-container table-scroll">
            <table>
              <thead><tr><th>Time</th><th>Action</th><th>User</th><th>Status</th><th>Duration</th><th>Error</th></tr></thead>
              <tbody>
                <tr v-for="(r, i) in wsStatus.recentRequests" :key="i">
                  <td class="no-wrap">{{ new Date(r.ts).toLocaleTimeString() }}</td>
                  <td><code>{{ r.action }}</code></td>
                  <td>{{ r.email || '—' }}</td>
                  <td>
                    <span :class="['badge', r.status === 'ok' ? 'badge-success' : 'badge-danger']">{{ r.status }}</span>
                  </td>
                  <td>{{ r.durationMs }}ms</td>
                  <td class="error-cell">{{ r.error || '' }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </template>

      <div v-else-if="wsStatus" class="empty-state">
        {{ wsStatus.error || 'WebSocket API server is not running.' }}
      </div>
    </div>

    <!-- System Stats -->
    <div class="grid grid-auto mb-6">
      <div v-for="m in liveCards" :key="m.label" class="stat-card">
        <div class="stat-label">{{ m.label }}</div>
        <div class="stat-value" :style="{color: m.color || 'var(--color-text-primary)'}">{{ m.value }}</div>
      </div>
    </div>

    <!-- Metrics Chart -->
    <div class="card">
      <div class="card-header">
        <h4>Resource History</h4>
        <select v-model="hours" @change="loadMetrics" class="time-select">
          <option :value="1">1 hour</option>
          <option :value="6">6 hours</option>
          <option :value="24">24 hours</option>
        </select>
      </div>
      <div v-if="metrics.length" class="metrics-chart">
        <div v-for="(m, i) in sampledMetrics" :key="i" class="metric-row">
          <span class="metric-time">{{ formatTime(m.created_at) }}</span>
          <span class="metric-cpu-label">{{ m.cpu_percent }}%</span>
          <div class="metric-bar-track">
            <div class="metric-bar-fill" :style="{width: m.cpu_percent + '%', background: m.cpu_percent > 80 ? 'var(--color-danger)' : 'var(--color-accent)'}"></div>
          </div>
          <span class="metric-mem">{{ m.mem_used_mb }}MB</span>
          <span class="metric-ws">{{ m.ws_connections }}ws</span>
        </div>
      </div>
      <div v-else class="empty-state">No metrics collected yet. Data appears after ws-api runs for 1 minute.</div>
    </div>
  </div>
</template>

<script setup lang="ts">
const { api } = useApi();
const metrics = ref<any[]>([]);
const hours = ref(6);
const stats = ref<any>(null);
const wsStatus = ref<any>(null);

const wsCards = computed(() => {
  const ws = wsStatus.value;
  if (!ws?.running) return [];
  return [
    { label: 'Connections', value: ws.connections, color: 'var(--color-success)' },
    { label: 'Total Messages', value: ws.totalMessages, color: 'var(--color-info)' },
    { label: 'Total Errors', value: ws.totalErrors, color: ws.totalErrors > 0 ? 'var(--color-danger)' : 'var(--color-success)' },
    { label: 'WS Uptime', value: formatDuration(ws.uptime), color: '#a78bfa' },
  ];
});

const sortedActions = computed(() => {
  const acts = wsStatus.value?.actions || {};
  // Sort by count descending
  return Object.fromEntries(
    Object.entries(acts).sort((a: any, b: any) => b[1].count - a[1].count)
  );
});

const liveCards = computed(() => {
  const s = stats.value;
  if (!s) return [];
  return [
    { label: 'CPU Cores', value: s.server.cpuCount },
    { label: 'RAM Used', value: `${s.server.memUsedMb}MB / ${s.server.memTotalMb}MB`, color: s.server.memUsedMb > s.server.memTotalMb * 0.85 ? 'var(--color-danger)' : 'var(--color-success)' },
    { label: 'System Uptime', value: formatDuration(s.server.uptime) },
  ];
});

const sampledMetrics = computed(() => {
  const arr = metrics.value;
  if (arr.length <= 60) return arr;
  const step = Math.ceil(arr.length / 60);
  return arr.filter((_: any, i: number) => i % step === 0);
});

function formatTime(t: string) {
  return new Date(t + 'Z').toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

function formatDuration(secs: number) {
  if (!secs || secs < 0) return '—';
  if (secs < 60) return `${secs}s`;
  if (secs < 3600) return `${Math.floor(secs / 60)}m`;
  const h = Math.floor(secs / 3600);
  const m = Math.floor((secs % 3600) / 60);
  return m > 0 ? `${h}h ${m}m` : `${h}h`;
}

function timeAgo(ts: number) {
  if (!ts) return '—';
  const diff = Math.round((Date.now() - ts) / 1000);
  if (diff < 5) return 'just now';
  if (diff < 60) return `${diff}s ago`;
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  return `${Math.floor(diff / 3600)}h ago`;
}

async function loadMetrics() {
  try { metrics.value = (await api(`monitor/metrics?hours=${hours.value}`)).metrics; } catch {}
}
async function loadStats() {
  try { stats.value = await api('stats'); } catch {}
}
async function loadWsStatus() {
  try { wsStatus.value = await api('monitor/ws-status'); } catch {}
}

const wsBusy = ref('');
const wsMsg = ref<any>(null);

async function wsControl(command: string) {
  if (command === 'stop' && !confirm('Stop ws-api? Clients will disconnect.')) return;
  if (command === 'restart' && !confirm('Restart ws-api? Brief downtime while it restarts.')) return;
  wsBusy.value = command;
  wsMsg.value = null;
  try {
    await api('monitor/ws-control', { method: 'POST', body: { command } });
    wsMsg.value = { ok: true, text: `ws-api: ${command} successful` };
    setTimeout(() => loadWsStatus(), 1500);
  } catch (e: any) {
    wsMsg.value = { ok: false, text: e.data?.message || 'Failed' };
  } finally {
    wsBusy.value = '';
  }
}

onMounted(() => {
  loadStats();
  loadMetrics();
  loadWsStatus();
});

let t: any;
onMounted(() => {
  t = setInterval(() => {
    loadStats();
    loadWsStatus();
  }, 5000);
});
onUnmounted(() => clearInterval(t));
</script>

<style scoped>
.ws-stat-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
  gap: var(--space-3);
}

.ws-stat-item {
  background: var(--color-bg-elevated);
  border-radius: var(--radius-md);
  padding: var(--space-3) var(--space-4);
}

.ws-stat-label {
  font-size: 0.6875rem;
  font-weight: 500;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--color-text-muted);
  margin-bottom: 2px;
}

.ws-stat-value {
  font-size: 1.25rem;
  font-weight: 700;
  letter-spacing: -0.02em;
}

.ws-msg {
  padding: 10px 14px;
  border-radius: var(--radius-md);
  font-size: 0.8125rem;
  margin-bottom: var(--space-5);
}

.msg-success {
  background: var(--color-success-subtle);
  color: var(--color-success);
}

.msg-error {
  background: var(--color-danger-subtle);
  color: var(--color-danger);
}

.section-title {
  font-size: 0.8125rem;
  font-weight: 600;
  color: var(--color-text-secondary);
  margin-bottom: var(--space-3);
}

.table-container {
  overflow-x: auto;
}

.table-scroll {
  max-height: 300px;
  overflow-y: auto;
}

.text-primary {
  color: var(--color-text-primary);
  font-weight: 500;
}

.text-danger {
  color: var(--color-danger);
}

.text-muted {
  color: var(--color-text-muted);
}

.no-wrap {
  white-space: nowrap;
}

.error-cell {
  color: var(--color-danger);
  max-width: 200px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.time-select {
  width: auto;
  min-width: 120px;
}

.metrics-chart {
  display: flex;
  flex-direction: column;
  gap: 3px;
  max-height: 300px;
  overflow-y: auto;
}

.metric-row {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  font-size: 0.75rem;
}

.metric-time {
  width: 52px;
  color: var(--color-text-muted);
  flex-shrink: 0;
  font-family: var(--font-mono);
}

.metric-cpu-label {
  width: 36px;
  color: var(--color-text-tertiary);
  flex-shrink: 0;
  text-align: right;
  font-family: var(--font-mono);
}

.metric-bar-track {
  flex: 1;
  background: var(--color-bg-elevated);
  border-radius: 4px;
  height: 14px;
  overflow: hidden;
}

.metric-bar-fill {
  height: 100%;
  border-radius: 4px;
  transition: width var(--transition-slow);
}

.metric-mem {
  width: 60px;
  color: var(--color-text-tertiary);
  flex-shrink: 0;
  text-align: right;
  font-family: var(--font-mono);
}

.metric-ws {
  width: 30px;
  color: var(--color-text-muted);
  flex-shrink: 0;
  font-family: var(--font-mono);
}
</style>
