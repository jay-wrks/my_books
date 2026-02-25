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
        Pulls latest <code>ws-api/</code> and <code>shared/</code> from <code>origin/main</code>, stops ws-api, copies files, restarts.
      </p>
      <button type="button" @click.prevent="startDeploy('deploy')" :disabled="streaming" style="background:#059669;white-space:nowrap">
        {{ streaming ? '⏳ Deploying...' : '🚀 Deploy Latest' }}
      </button>
    </div>

    <!-- Live Terminal -->
    <div v-if="termLines.length" style="background:#0a0a0a;border-radius:12px;padding:1rem;border:1px solid #333;margin-bottom:1.5rem;font-family:'Fira Code','Cascadia Code','Consolas',monospace">
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:0.75rem">
        <h4 style="font-size:0.9rem;color:#9ca3af">{{ streamDone ? (streamOk ? '✅ Deploy Complete' : '❌ Deploy Failed') : '⏳ Running...' }}</h4>
        <button v-if="streamDone" type="button" @click="termLines = []" style="font-size:0.75rem;padding:0.2rem 0.5rem;background:#333">✕ Close</button>
      </div>
      <div ref="termEl" style="max-height:400px;overflow-y:auto;font-size:0.78rem;line-height:1.6;color:#d4d4d4">
        <div v-for="(line, i) in termLines" :key="i" :style="{
          color: line.startsWith('>>>') ? '#60a5fa'
            : line.startsWith('✅') ? '#10b981'
            : line.startsWith('❌') ? '#f87171'
            : line.startsWith('Commit:') ? '#fbbf24'
            : '#d4d4d4'
        }">{{ line }}</div>
        <div v-if="!streamDone" style="color:#6b7280">▌</div>
      </div>
    </div>

    <!-- Rollback — deploy branches -->
    <div style="background:#111;border-radius:12px;padding:1.25rem;border:1px solid #222;margin-bottom:1.5rem">
      <h4 style="margin-bottom:1rem">Rollback to Previous Deploy</h4>
      <div v-if="status?.deployBranches?.length" style="display:flex;flex-direction:column;gap:0.5rem">
        <div v-for="br in status.deployBranches" :key="br"
          style="display:flex;align-items:center;justify-content:space-between;padding:0.6rem 0.75rem;background:#1a1a1a;border-radius:8px;border:1px solid #333">
          <code style="color:#e5e7eb">{{ br }}</code>
          <button type="button" @click.prevent="startDeploy('rollback', br)" :disabled="streaming"
            style="background:#b45309;font-size:0.8rem;padding:0.3rem 0.75rem;white-space:nowrap">
            ⏪ Rollback
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
              <td><button v-if="d.log" type="button" @click="showLog = d.log" style="font-size:0.75rem;padding:0.25rem 0.5rem">📋 View</button></td>
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
          <button type="button" @click="showLog = ''" style="background:#333;padding:0.25rem 0.75rem">✕</button>
        </div>
        <pre style="white-space:pre-wrap;font-size:0.8rem;color:#d1d5db">{{ showLog }}</pre>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const { api, token } = useApi();
const status = ref<any>(null);
const showLog = ref('');

// Live terminal state
const streaming = ref(false);
const streamDone = ref(false);
const streamOk = ref(false);
const termLines = ref<string[]>([]);
const termEl = ref<HTMLElement | null>(null);

async function load() {
  try { status.value = await api('deploy/status'); } catch {}
}

function startDeploy(type: 'deploy' | 'rollback', branch?: string) {
  if (type === 'rollback' && !confirm(`Rollback to ${branch}?\n\nThis will stop ws-api, restore files from that branch, and restart.`)) return;

  streaming.value = true;
  streamDone.value = false;
  streamOk.value = false;
  termLines.value = [`$ ${type === 'rollback' ? `rollback → ${branch}` : 'deploy from main'}`, ''];

  let url = `/api/admin/deploy/stream?type=${type}`;
  if (branch) url += `&branch=${encodeURIComponent(branch)}`;

  const es = new EventSource(url);

  es.onmessage = (e) => {
    const line = JSON.parse(e.data);
    termLines.value.push(line);
    // Auto-scroll
    nextTick(() => { if (termEl.value) termEl.value.scrollTop = termEl.value.scrollHeight; });
  };

  es.addEventListener('done', (e) => {
    const data = JSON.parse(e.data);
    streamOk.value = data.status === 'success';
    streamDone.value = true;
    streaming.value = false;
    es.close();
    load(); // Refresh status & history
  });

  es.onerror = () => {
    if (!streamDone.value) {
      termLines.value.push('', '❌ Connection lost');
      streamDone.value = true;
      streamOk.value = false;
      streaming.value = false;
    }
    es.close();
  };
}

onMounted(load);
</script>
