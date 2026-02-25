<template>
  <div>
    <h2 style="margin-bottom:1.5rem">📡 Monitor</h2>

    <!-- WS-API Status & Controls -->
    <div style="background:#111;border-radius:12px;padding:1.25rem;border:1px solid #222;margin-bottom:1.5rem">
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:1rem;flex-wrap:wrap;gap:0.5rem">
        <div style="display:flex;align-items:center;gap:0.75rem">
          <h4>🌐 WS-API</h4>
          <span :style="{
            padding:'0.15rem 0.5rem', borderRadius:'999px', fontSize:'0.75rem', fontWeight:600,
            background: wsStatus?.running ? '#052e16' : '#450a0a',
            color: wsStatus?.running ? '#86efac' : '#fca5a5',
          }">{{ wsStatus?.running ? '● Running' : '● Stopped' }}</span>
        </div>
        <div style="display:flex;gap:0.4rem">
          <button v-if="!wsStatus?.running" @click="wsControl('start')" :disabled="!!wsBusy"
            style="font-size:0.75rem;padding:0.25rem 0.6rem;background:#059669">▶ Start</button>
          <button v-if="wsStatus?.running" @click="wsControl('stop')" :disabled="!!wsBusy"
            style="font-size:0.75rem;padding:0.25rem 0.6rem;background:#dc2626">⏹ Stop</button>
          <button v-if="wsStatus?.running" @click="wsControl('restart')" :disabled="!!wsBusy"
            style="font-size:0.75rem;padding:0.25rem 0.6rem;background:#d97706">🔄 Restart</button>
        </div>
      </div>
      <p v-if="wsMsg" style="margin-bottom:0.75rem;padding:0.5rem 0.75rem;border-radius:8px;font-size:0.85rem"
        :style="{background: wsMsg.ok ? '#052e16' : '#450a0a', color: wsMsg.ok ? '#86efac' : '#fca5a5'}">
        {{ wsMsg.text }}
      </p>

      <template v-if="wsStatus?.running">
        <!-- Summary cards -->
        <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:0.75rem;margin-bottom:1.25rem">
          <div v-for="c in wsCards" :key="c.label" style="background:#1a1a1a;border-radius:8px;padding:0.6rem 0.75rem">
            <div style="font-size:0.75rem;color:#6b7280">{{ c.label }}</div>
            <div style="font-size:1.25rem;font-weight:700" :style="{color: c.color || '#10b981'}">{{ c.value }}</div>
          </div>
        </div>

        <!-- Connected Users -->
        <div v-if="wsStatus.connectedUsers?.length" style="margin-bottom:1.25rem">
          <h5 style="margin-bottom:0.5rem;color:#d1d5db">Connected Users ({{ wsStatus.connectedUsers.length }})</h5>
          <div style="overflow-x:auto">
            <table style="font-size:0.8rem">
              <thead><tr><th>Email</th><th>Connected</th><th>Last Active</th><th>Messages</th></tr></thead>
              <tbody>
                <tr v-for="u in wsStatus.connectedUsers" :key="u.userId">
                  <td>{{ u.email || '(anonymous)' }}</td>
                  <td>{{ timeAgo(u.connectedAt) }}</td>
                  <td>{{ timeAgo(u.lastActive) }}</td>
                  <td>{{ u.msgCount }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <!-- Action Stats -->
        <div v-if="Object.keys(wsStatus.actions || {}).length" style="margin-bottom:1.25rem">
          <h5 style="margin-bottom:0.5rem;color:#d1d5db">Action Stats</h5>
          <div style="overflow-x:auto">
            <table style="font-size:0.8rem">
              <thead><tr><th>Action</th><th>Calls</th><th>Errors</th><th>Avg (ms)</th><th>Last Called</th></tr></thead>
              <tbody>
                <tr v-for="(s, name) in sortedActions" :key="name">
                  <td><code>{{ name }}</code></td>
                  <td>{{ s.count }}</td>
                  <td :style="{color: s.errors > 0 ? '#f87171' : '#6b7280'}">{{ s.errors }}</td>
                  <td>{{ s.avgMs }}ms</td>
                  <td>{{ timeAgo(s.lastCalledAt) }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <!-- Recent Requests -->
        <div v-if="wsStatus.recentRequests?.length">
          <h5 style="margin-bottom:0.5rem;color:#d1d5db">Recent Requests (last 50)</h5>
          <div style="overflow-x:auto;max-height:300px;overflow-y:auto">
            <table style="font-size:0.8rem">
              <thead><tr><th>Time</th><th>Action</th><th>User</th><th>Status</th><th>Duration</th><th>Error</th></tr></thead>
              <tbody>
                <tr v-for="(r, i) in wsStatus.recentRequests" :key="i">
                  <td style="white-space:nowrap">{{ new Date(r.ts).toLocaleTimeString() }}</td>
                  <td><code>{{ r.action }}</code></td>
                  <td>{{ r.email || '—' }}</td>
                  <td><span :style="{color: r.status === 'ok' ? '#10b981' : '#f87171'}">{{ r.status }}</span></td>
                  <td>{{ r.durationMs }}ms</td>
                  <td style="color:#fca5a5;max-width:200px;overflow:hidden;text-overflow:ellipsis">{{ r.error || '' }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </template>
      <p v-else-if="wsStatus" style="color:#fca5a5">{{ wsStatus.error || 'WebSocket API server is not running.' }}</p>
    </div>

    <!-- System Stats -->
    <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:1rem;margin-bottom:2rem">
      <div v-for="m in liveCards" :key="m.label" style="background:#111;border-radius:12px;padding:1.25rem;border:1px solid #222">
        <div style="font-size:0.85rem;color:#9ca3af">{{ m.label }}</div>
        <div style="font-size:1.5rem;font-weight:700;margin-top:0.25rem" :style="{color: m.color || '#10b981'}">{{ m.value }}</div>
      </div>
    </div>

    <!-- Metrics Chart -->
    <div style="background:#111;border-radius:12px;padding:1.25rem;border:1px solid #222;margin-bottom:1.5rem">
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:1rem">
        <h4>📈 Resource History</h4>
        <select v-model="hours" @change="loadMetrics" style="width:auto">
          <option :value="1">1 hour</option>
          <option :value="6">6 hours</option>
          <option :value="24">24 hours</option>
        </select>
      </div>
      <div v-if="metrics.length" style="display:flex;flex-direction:column;gap:0.25rem;max-height:300px;overflow-y:auto">
        <div v-for="(m, i) in sampledMetrics" :key="i" style="display:flex;align-items:center;gap:0.5rem;font-size:0.75rem">
          <span style="width:60px;color:#6b7280;flex-shrink:0">{{ formatTime(m.created_at) }}</span>
          <span style="width:35px;color:#9ca3af;flex-shrink:0">{{ m.cpu_percent }}%</span>
          <div style="flex:1;background:#1f1f1f;border-radius:4px;height:16px;overflow:hidden">
            <div :style="{width: m.cpu_percent + '%', height:'100%', background: m.cpu_percent > 80 ? '#ef4444' : '#10b981', borderRadius:'4px', transition:'width 0.3s'}"></div>
          </div>
          <span style="width:70px;color:#9ca3af;flex-shrink:0;text-align:right">{{ m.mem_used_mb }}MB</span>
          <span style="width:30px;color:#6b7280;flex-shrink:0">{{ m.ws_connections }}ws</span>
        </div>
      </div>
      <p v-else style="color:#6b7280">No metrics collected yet. Data appears after ws-api runs for 1 minute.</p>
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
    { label: 'Connections', value: ws.connections, color: '#10b981' },
    { label: 'Total Messages', value: ws.totalMessages, color: '#60a5fa' },
    { label: 'Total Errors', value: ws.totalErrors, color: ws.totalErrors > 0 ? '#f87171' : '#10b981' },
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
    { label: 'RAM Used', value: `${s.server.memUsedMb}MB / ${s.server.memTotalMb}MB`, color: s.server.memUsedMb > s.server.memTotalMb * 0.85 ? '#ef4444' : '#10b981' },
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
    wsMsg.value = { ok: true, text: `✅ ws-api: ${command} successful` };
    setTimeout(() => loadWsStatus(), 1500);
  } catch (e: any) {
    wsMsg.value = { ok: false, text: `❌ ${e.data?.message || 'Failed'}` };
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
