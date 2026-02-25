<template>
  <div>
    <h2 style="margin-bottom:1.5rem">🚀 Deploy</h2>

    <!-- Current Status -->
    <div style="background:#111;border-radius:12px;padding:1.25rem;border:1px solid #222;margin-bottom:1.5rem">
      <h4 style="margin-bottom:1rem">Current Status</h4>
      <div v-if="status" style="display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:0.75rem">
        <div><span style="color:#9ca3af">Branch:</span> <strong style="color:#10b981">{{ status.branch }}</strong></div>
        <div><span style="color:#9ca3af">Commit:</span> <code>{{ status.commit }}</code></div>
        <div><span style="color:#9ca3af">Dirty:</span> {{ status.dirty ? '⚠️ Yes' : '✅ No' }}</div>
      </div>
    </div>

    <!-- Deploy Controls -->
    <div style="background:#111;border-radius:12px;padding:1.25rem;border:1px solid #222;margin-bottom:1.5rem">
      <h4 style="margin-bottom:1rem">Deploy WS-API</h4>
      <div style="display:flex;gap:1rem;align-items:end;flex-wrap:wrap">
        <label style="flex:1;min-width:200px">
          Branch
          <select v-model="selectedBranch">
            <option v-for="b in status?.branches || []" :key="b" :value="b">{{ b }}</option>
          </select>
        </label>
        <button @click="deploy" :disabled="deploying" style="background:#059669;white-space:nowrap">
          {{ deploying ? '⏳ Deploying...' : '🚀 Pull & Deploy' }}
        </button>
      </div>
      <p v-if="deployResult" style="margin-top:1rem;padding:0.75rem;border-radius:8px"
        :style="{background: deployResult.ok ? '#052e16' : '#450a0a', color: deployResult.ok ? '#86efac' : '#fca5a5'}">
        {{ deployResult.message }}
      </p>
    </div>

    <!-- Deploy History -->
    <div style="background:#111;border-radius:12px;padding:1.25rem;border:1px solid #222">
      <h4 style="margin-bottom:1rem">Deploy History</h4>
      <div style="overflow-x:auto">
        <table v-if="status?.history?.length">
          <thead><tr><th>Branch</th><th>Commit</th><th>Status</th><th>Duration</th><th>Date</th><th>Log</th></tr></thead>
          <tbody>
            <tr v-for="d in status.history" :key="d.id">
              <td>{{ d.branch }}</td>
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
const selectedBranch = ref('main');
const deploying = ref(false);
const deployResult = ref<any>(null);
const showLog = ref('');

async function load() {
  try {
    status.value = await api('deploy/status');
    if (status.value?.branch) selectedBranch.value = status.value.branch;
  } catch {}
}

async function deploy() {
  deploying.value = true;
  deployResult.value = null;
  try {
    const res = await api('deploy/pull', { method: 'POST', body: { branch: selectedBranch.value } });
    deployResult.value = { ok: true, message: `✅ Deployed ${res.commit} in ${(res.duration / 1000).toFixed(1)}s` };
    await load();
  } catch (e: any) {
    deployResult.value = { ok: false, message: `❌ ${e.data?.message || 'Deploy failed'}` };
  } finally {
    deploying.value = false;
  }
}

onMounted(load);
</script>
