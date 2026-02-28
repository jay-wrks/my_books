<template>
  <div>
    <div class="page-header">
      <div>
        <h2>Deploy</h2>
        <p class="page-description">Deploy and track deployment history</p>
      </div>
    </div>

    <!-- Current Status -->
    <div class="card mb-6">
      <div class="card-header">
        <h4>Current Status</h4>
      </div>
      <div v-if="status" class="status-grid">
        <div class="status-item">
          <span class="status-label">Branch</span>
          <span class="status-value accent">{{ status.branch }}</span>
        </div>
        <div class="status-item">
          <span class="status-label">Commit</span>
          <code>{{ status.commit }}</code>
        </div>
      </div>
    </div>

    <!-- Deploy from main -->
    <div class="card mb-6">
      <div class="card-header">
        <h4>Deploy from main</h4>
      </div>
      <p class="deploy-desc mb-4">
        Pulls latest <code>ws-api/</code> and <code>shared/</code> from <code>origin/main</code>, stops ws-api, copies files, restarts.
      </p>
      <button type="button" @click.prevent="startDeploy()" :disabled="streaming" class="btn-primary">
        {{ streaming ? 'Deploying...' : 'Deploy Latest' }}
      </button>
    </div>

    <!-- Live Terminal -->
    <div v-if="termLines.length" class="card mb-6 terminal-card">
      <div class="card-header">
        <h4 :class="['terminal-status', streamDone ? (streamOk ? 'text-success' : 'text-danger') : 'text-muted']">
          {{ streamDone ? (streamOk ? 'Deploy Complete' : 'Deploy Failed') : 'Running...' }}
        </h4>
        <button v-if="streamDone" type="button" @click="termLines = []" class="btn-sm btn-ghost">Close</button>
      </div>
      <div ref="termEl" class="terminal">
        <div v-for="(line, i) in termLines" :key="i" :class="{
          'line-cmd': line.startsWith('>>>'),
          'line-ok': line.startsWith('Deploy Complete') || line.startsWith('Commit:') && false,
          'line-err': line.startsWith('Connection lost') || line.startsWith('Error'),
          'line-info': line.startsWith('Commit:'),
        }">{{ line }}</div>
        <div v-if="!streamDone" class="cursor"></div>
      </div>
    </div>

    <!-- Deploy History -->
    <div class="card">
      <div class="card-header">
        <h4>Deploy History</h4>
      </div>
      <div class="table-container">
        <table v-if="status?.history?.length">
          <thead><tr><th>Branch</th><th>Commit</th><th>Status</th><th>Duration</th><th>Date</th><th>Log</th></tr></thead>
          <tbody>
            <tr v-for="d in status.history" :key="d.id">
              <td>{{ d.branch }}</td>
              <td><code>{{ d.commit_hash || '—' }}</code></td>
              <td>
                <span :class="['badge', d.status === 'success' ? 'badge-success' : d.status === 'failed' ? 'badge-danger' : 'badge-warning']">
                  {{ d.status }}
                </span>
              </td>
              <td>{{ d.duration_ms ? (d.duration_ms / 1000).toFixed(1) + 's' : '—' }}</td>
              <td>{{ new Date(d.created_at).toLocaleString() }}</td>
              <td>
                <button v-if="d.log" type="button" @click="showLog = d.log" class="btn-sm btn-ghost">View</button>
              </td>
            </tr>
          </tbody>
        </table>
        <div v-else class="empty-state">No deploys yet</div>
      </div>
    </div>

    <!-- Log Modal -->
    <div v-if="showLog" @click="showLog = ''" class="modal-overlay">
      <div @click.stop class="modal-content">
        <div class="modal-header">
          <h4>Deploy Log</h4>
          <button type="button" @click="showLog = ''" class="btn-sm btn-ghost">Close</button>
        </div>
        <pre>{{ showLog }}</pre>
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

function startDeploy() {
  streaming.value = true;
  streamDone.value = false;
  streamOk.value = false;
  termLines.value = ['$ deploy from main', ''];

  const url = '/api/admin/deploy/stream';

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
      termLines.value.push('', 'Connection lost');
      streamDone.value = true;
      streamOk.value = false;
      streaming.value = false;
    }
    es.close();
  };
}

onMounted(load);
</script>

<style scoped>
.status-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: var(--space-4);
}

.status-item {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.status-label {
  font-size: 0.75rem;
  font-weight: 500;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--color-text-tertiary);
}

.status-value {
  font-size: 0.9375rem;
  font-weight: 600;
  color: var(--color-text-primary);
}

.status-value.accent {
  color: var(--color-accent);
}

.deploy-desc {
  font-size: 0.8125rem;
  color: var(--color-text-tertiary);
  line-height: 1.6;
}

.terminal-card {
  padding: 0;
}

.terminal-card .card-header {
  padding: var(--space-4) var(--space-6);
  margin-bottom: 0;
}

.terminal-card .terminal {
  border: none;
  border-radius: 0 0 var(--radius-lg) var(--radius-lg);
}

.terminal-status {
  font-size: 0.8125rem;
}

.text-success { color: var(--color-success); }
.text-danger { color: var(--color-danger); }
.text-muted { color: var(--color-text-tertiary); }

.table-container {
  overflow-x: auto;
}
</style>
