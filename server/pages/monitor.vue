<template>
  <div>
    <h2 style="margin-bottom:1.5rem">📡 Monitor</h2>

    <!-- Live Stats -->
    <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:1rem;margin-bottom:2rem">
      <div v-for="m in liveCards" :key="m.label" style="background:#111;border-radius:12px;padding:1.25rem;border:1px solid #222">
        <div style="font-size:0.85rem;color:#9ca3af">{{ m.label }}</div>
        <div style="font-size:1.5rem;font-weight:700;margin-top:0.25rem" :style="{color: m.color || '#10b981'}">{{ m.value }}</div>
      </div>
    </div>

    <!-- Metrics Chart (simple ASCII-style bar chart) -->
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
      <p v-else style="color:#6b7280">No metrics collected yet. Data appears after 1 minute.</p>
    </div>
  </div>
</template>

<script setup lang="ts">
const { api } = useApi();
const metrics = ref<any[]>([]);
const hours = ref(6);
const stats = ref<any>(null);

const liveCards = computed(() => {
  const s = stats.value;
  if (!s) return [];
  return [
    { label: 'WS Connections', value: s.wsConnections, color: '#10b981' },
    { label: 'CPU Cores', value: s.server.cpuCount },
    { label: 'RAM Used', value: `${s.server.memUsedMb}MB / ${s.server.memTotalMb}MB`, color: s.server.memUsedMb > s.server.memTotalMb * 0.85 ? '#ef4444' : '#10b981' },
    { label: 'Uptime', value: `${Math.round(s.server.uptime / 3600)}h` },
  ];
});

// Sample metrics to max 60 rows for display
const sampledMetrics = computed(() => {
  const arr = metrics.value;
  if (arr.length <= 60) return arr;
  const step = Math.ceil(arr.length / 60);
  return arr.filter((_, i) => i % step === 0);
});

function formatTime(t: string) {
  return new Date(t + 'Z').toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

async function loadMetrics() {
  try { metrics.value = (await api(`monitor/metrics?hours=${hours.value}`)).metrics; } catch {}
}
async function loadStats() {
  try { stats.value = await api('stats'); } catch {}
}

onMounted(() => { loadStats(); loadMetrics(); });
let t: any;
onMounted(() => { t = setInterval(loadStats, 5000); });
onUnmounted(() => clearInterval(t));
</script>
