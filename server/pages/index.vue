<template>
  <div>
    <h2 style="margin-bottom:1.5rem">📊 Dashboard</h2>

    <!-- Stats Cards -->
    <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:1rem;margin-bottom:2rem">
      <div v-for="card in cards" :key="card.label" style="background:#111;border-radius:12px;padding:1.25rem;border:1px solid #222">
        <div style="font-size:0.85rem;color:#9ca3af">{{ card.label }}</div>
        <div style="font-size:1.8rem;font-weight:700;color:#10b981;margin-top:0.25rem">{{ card.value }}</div>
      </div>
    </div>

    <!-- Server Info -->
    <div style="background:#111;border-radius:12px;padding:1.25rem;border:1px solid #222;margin-bottom:2rem">
      <h4 style="margin-bottom:1rem">🖥️ Server</h4>
      <div v-if="stats" style="display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:0.75rem">
        <div><span style="color:#9ca3af">CPU Cores:</span> {{ stats.server.cpuCount }}</div>
        <div><span style="color:#9ca3af">RAM:</span> {{ stats.server.memUsedMb }}MB / {{ stats.server.memTotalMb }}MB</div>
        <div><span style="color:#9ca3af">WS Conns:</span> {{ stats.wsConnections }}</div>
        <div><span style="color:#9ca3af">Uptime:</span> {{ Math.round(stats.server.uptime / 3600) }}h</div>
      </div>
    </div>

    <!-- Recent Payments -->
    <div style="background:#111;border-radius:12px;padding:1.25rem;border:1px solid #222">
      <h4 style="margin-bottom:1rem">💰 Recent Payments</h4>
      <div style="overflow-x:auto">
        <table v-if="stats?.recentPayments?.length">
          <thead><tr><th>User</th><th>Amount</th><th>Status</th><th>Date</th></tr></thead>
          <tbody>
            <tr v-for="p in stats.recentPayments" :key="p.id">
              <td>{{ p.user_email }}</td>
              <td>₹{{ p.amount }}</td>
              <td><span :style="{color: p.status === 'captured' ? '#10b981' : '#f87171'}">{{ p.status }}</span></td>
              <td>{{ new Date(p.created_at).toLocaleDateString() }}</td>
            </tr>
          </tbody>
        </table>
        <p v-else style="color:#6b7280">No payments yet</p>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const { api } = useApi();
const stats = ref<any>(null);

const cards = computed(() => [
  { label: 'Total Users', value: stats.value?.totalUsers ?? '—' },
  { label: 'Active Subscribers', value: stats.value?.activeSubs ?? '—' },
  { label: 'Total PDFs', value: stats.value?.totalPdfs ?? '—' },
  { label: 'Revenue', value: stats.value ? `₹${stats.value.totalPayments}` : '—' },
  { label: 'WS Connections', value: stats.value?.wsConnections ?? '—' },
]);

async function load() {
  try { stats.value = await api('stats'); } catch {}
}
onMounted(load);
// Auto-refresh every 10s
let timer: any;
onMounted(() => { timer = setInterval(load, 10000); });
onUnmounted(() => clearInterval(timer));
</script>
