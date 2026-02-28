<template>
  <div>
    <div class="page-header">
      <div>
        <h2>Dashboard</h2>
        <p class="page-description">System overview and key metrics</p>
      </div>
    </div>

    <!-- Stats Cards -->
    <div class="grid grid-auto mb-7">
      <div v-for="card in cards" :key="card.label" class="stat-card">
        <div class="stat-label">{{ card.label }}</div>
        <div class="stat-value">{{ card.value }}</div>
      </div>
    </div>

    <!-- Server Info -->
    <div class="card mb-6">
      <div class="card-header">
        <h4>Server</h4>
      </div>
      <div v-if="stats" class="grid grid-auto">
        <div class="server-metric">
          <span class="metric-label">CPU Cores</span>
          <span class="metric-value">{{ stats.server.cpuCount }}</span>
        </div>
        <div class="server-metric">
          <span class="metric-label">RAM</span>
          <span class="metric-value">{{ stats.server.memUsedMb }}MB / {{ stats.server.memTotalMb }}MB</span>
        </div>
        <div class="server-metric">
          <span class="metric-label">WS Connections</span>
          <span class="metric-value">{{ stats.wsConnections }}</span>
        </div>
        <div class="server-metric">
          <span class="metric-label">Uptime</span>
          <span class="metric-value">{{ Math.round(stats.server.uptime / 3600) }}h</span>
        </div>
      </div>
    </div>

    <!-- Recent Payments -->
    <div class="card">
      <div class="card-header">
        <h4>Recent Payments</h4>
      </div>
      <div class="table-container">
        <table v-if="stats?.recentPayments?.length">
          <thead><tr><th>User</th><th>Amount</th><th>Status</th><th>Date</th></tr></thead>
          <tbody>
            <tr v-for="p in stats.recentPayments" :key="p.id">
              <td>{{ p.user_email }}</td>
              <td class="font-mono">₹{{ p.amount }}</td>
              <td>
                <span :class="['badge', p.status === 'captured' ? 'badge-success' : 'badge-danger']">
                  {{ p.status }}
                </span>
              </td>
              <td>{{ new Date(p.created_at).toLocaleDateString() }}</td>
            </tr>
          </tbody>
        </table>
        <div v-else class="empty-state">No payments yet</div>
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

<style scoped>
.table-container {
  overflow-x: auto;
}

.font-mono {
  font-family: var(--font-mono);
  font-size: 0.8125rem;
}

.server-metric {
  display: flex;
  flex-direction: column;
  gap: 4px;
  padding: var(--space-3) var(--space-4);
  background: var(--color-bg-elevated);
  border-radius: var(--radius-md);
}

.metric-label {
  font-size: 0.75rem;
  font-weight: 500;
  color: var(--color-text-tertiary);
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

.metric-value {
  font-size: 0.9375rem;
  font-weight: 600;
  color: var(--color-text-primary);
}
</style>
