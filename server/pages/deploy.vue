<template>
  <div>
    <h2 style="margin-bottom:1.5rem">🚀 Deploy</h2>

    <!-- Current Status -->
    <div style="background:#111;border-radius:12px;padding:1.25rem;border:1px solid #222;margin-bottom:1.5rem">
      <h4 style="margin-bottom:1rem">Current Status</h4>
      <div v-if="status" style="display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:0.75rem">
        <div><span style="color:#9ca3af">Branch:</span> <strong style="color:#10b981">{{ status.branch }}</strong></div>
        <div><span style="color:#9ca3af">Commit:</span> <code>{{ status.commit }}</code></div>
      </div>
    </div>

    <!-- Deploy from main -->
    <div style="background:#111;border-radius:12px;padding:1.25rem;border:1px solid #222;margin-bottom:1.5rem">
      <h4 style="margin-bottom:0.5rem">Deploy from main</h4>
      <p style="color:#9ca3af;font-size:0.85rem;margin-bottom:1rem">
        Fetches latest <code>main</code>, builds admin UI + WS-API in a temp clone, stops servers, copies artifacts, restarts.
        Creates a <code>deploy_YYYY_MM_DD_N</code> branch as a snapshot.
      </p>
      <button @click="deploy" :disabled="deploying || rollingBack" style="background:#059669;white-space:nowrap">
        {{ deploying ? '⏳ Deploying...' : '🚀 Deploy Latest' }}
      </button>
      <p v-if="deployResult" style="margin-top:1rem;padding:0.75rem;border-radius:8px"
        :style="{background: deployResult.ok ? '#052e16' : '#450a0a', color: deployResult.ok ? '#86efac' : '#fca5a5'}">
        {{ deployResult.message }}
      </p>
    </div>

    <!-- Rollback — deploy branches -->
    <div style="background:#111;border-radius:12px;padding:1.25rem;border:1px solid #222;margin-bottom:1.5rem">
      <h4 style="margin-bottom:1rem">Rollback to Previous Deploy</h4>
      <div v-if="status?.deployBranches?.length" style="display:flex;flex-direction:column;gap:0.5rem">
        <div v-for="br in status.deployBranches" :key="br"
          style="display:flex;align-items:center;justify-content:space-between;padding:0.6rem 0.75rem;background:#1a1a1a;border-radius:8px;border:1px solid #333">
          <code style="color:#e5e7eb">{{ br }}</code>
          <button @click="rollback(br)" :disabled="deploying || rollingBack"
            style="background:#b45309;font-size:0.8rem;padding:0.3rem 0.75rem;white-space:nowrap">
            {{ rollingBack === br ? '⏳ Rolling back...' : '⏪ Rollback' }}
          </button>
        </div>
      </div>
      <p v-else style="color:#6b7280">No deploy snapshots found</p>
    </div>

    <!-- Deploy History -->
    <div style="background:#111;border-radius:12px;padding:1.25rem;border:1px solid #222">
      <h4 style="margin-bottom:1rem">Deploy History</h4>
      <div style="overflow-x:auto">
        <table v-if="status?.history?.length">
          <thead><tr><th>Type</th><th>Branch</th><th>Deploy Branch</th><th>Commit</th><th>Status</th><th>Duration</th><th>Date</th><th>Log</th></tr></thead>
          <tbody>
            <tr v-for="d in status.history" :key="d.id">
              <td><span :style="{color: d.type === 'rollback' ? '#fbbf24' : '#60a5fa'}">{{ d.type || 'deploy' }}</span></td>
              <td>{{ d.branch }}</td>
              <td><code v-if="d.deploy_branch">{{ d.deploy_branch }}</code><span v-else>—</span></td>
              <td><code>{{ d.commit_hash || '—' }}</code></td>
              <td><span :style="{color: d.status === 'success' ? '#10b981' : d.status === 'failed' ? '#f87171' : '#fbbf24'}">
                {{ d.status }}</span></td>
              <td>{{ d.duration_ms ? (d.duration_ms / 1000).toFixed(1) + 's' : '—' }}</td>
              <td>{{ new Date(d.created_at).toLocaleString() }}</td>
              <td><button v-if="d.log" @click="showLog = d.log" style="font-size:0.75rem;padding:0.25rem 0.5rem">📋 View</button></td>
            </tr>
          </tbody>
        </table>
        <p v-else style="color:#6b7280">No deploys yet</p>
      </div>
    </div>

    <!-- Log Modal -->
    <div v-if="showLog" @click="showLog = ''" style="position:fixed;inset:0;background:rgba(0,0,0,0.8);display:flex;align-items:center;justify-content:center;z-index:999;padding:2rem">
      <div @click.stop style="background:#111;border-radius:12px;padding:1.5rem;max-width:800px;width:100%;max-height:80vh;overflow:auto;border:1px solid #333">
        <div style="display:flex;justify-content:space-between;margin-bottom:1rem">
          <h4>Deploy Log</h4>
          <button @click="showLog = ''" style="background:#333;padding:0.25rem 0.75rem">✕</button>
        </div>
        <pre style="white-space:pre-wrap;font-size:0.8rem;color:#d1d5db">{{ showLog }}</pre>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const { api } = useApi();
const status = ref<any>(null);
const deploying = ref(false);
const rollingBack = ref(''); // holds the branch name while rolling back
const deployResult = ref<any>(null);
const showLog = ref('');

async function load() {
  try {
    status.value = await api('deploy/status');
  } catch {}
}

async function deploy() {
  deploying.value = true;
  deployResult.value = null;
  try {
    const res = await api('deploy/run', { method: 'POST' });
    deployResult.value = { ok: true, message: `✅ Deployed ${res.commit} → ${res.deployBranch} in ${(res.duration / 1000).toFixed(1)}s` };
    await load();
  } catch (e: any) {
    deployResult.value = { ok: false, message: `❌ ${e.data?.message || 'Deploy failed'}` };
  } finally {
    deploying.value = false;
  }
}

async function rollback(branch: string) {
  if (!confirm(`Rollback to ${branch}?\n\nThis will stop servers, build from that snapshot, and restart.`)) return;
  rollingBack.value = branch;
  deployResult.value = null;
  try {
    const res = await api('deploy/rollback', { method: 'POST', body: { deployBranch: branch } });
    deployResult.value = { ok: true, message: `✅ Rolled back to ${branch} (${res.commit}) in ${(res.duration / 1000).toFixed(1)}s` };
    await load();
  } catch (e: any) {
    deployResult.value = { ok: false, message: `❌ Rollback failed: ${e.data?.message || 'Unknown error'}` };
  } finally {
    rollingBack.value = '';
  }
}

onMounted(load);
</script>
