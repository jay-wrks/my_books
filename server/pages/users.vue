<template>
  <div>
    <div class="page-header">
      <div>
        <h2>Users</h2>
        <p class="page-description">Manage registered users and subscriptions</p>
      </div>
    </div>

    <!-- Subscription Grant Modal -->
    <div v-if="grantModal" class="modal-backdrop" @click.self="grantModal = null">
      <div class="card modal-card">
        <h4 class="mb-4">Grant Subscription</h4>
        <p class="mb-4 text-secondary">Grant subscription to <strong>{{ grantModal.name }}</strong> ({{ grantModal.email }})</p>
        <label>
          <span>Duration (days)</span>
          <select v-model="grantDays">
            <option :value="7">7 days</option>
            <option :value="30">30 days</option>
            <option :value="90">90 days</option>
            <option :value="180">180 days</option>
            <option :value="365">1 year</option>
          </select>
        </label>
        <div class="flex gap-3 mt-5">
          <button class="btn-primary" @click="grantSubscription">Grant</button>
          <button @click="grantModal = null">Cancel</button>
        </div>
      </div>
    </div>

    <div class="card">
      <div class="table-container">
        <table v-if="users.length">
          <thead>
            <tr>
              <th>Name</th>
              <th>Email</th>
              <th>Phone</th>
              <th>Status</th>
              <th>Subscription</th>
              <th>Expires</th>
              <th>Joined</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="u in users" :key="u.id" :class="{ 'row-blocked': u.is_blocked }">
              <td class="text-primary">{{ u.name }}</td>
              <td>{{ u.email }}</td>
              <td>{{ u.phone || '—' }}</td>
              <td>
                <span :class="['badge', u.is_blocked ? 'badge-danger' : 'badge-success']">
                  {{ u.is_blocked ? 'Blocked' : 'Active' }}
                </span>
              </td>
              <td>
                <span :class="['badge', u.sub_status === 'active' ? 'badge-success' : 'badge-muted']">
                  {{ u.sub_status || 'none' }}
                </span>
              </td>
              <td>{{ u.sub_expires ? new Date(u.sub_expires).toLocaleDateString() : '—' }}</td>
              <td>{{ new Date(u.created_at).toLocaleDateString() }}</td>
              <td>
                <div class="actions-cell">
                  <button
                    v-if="u.sub_status !== 'active'"
                    @click="grantModal = u; grantDays = 30"
                    class="btn-sm btn-success"
                    title="Grant subscription"
                  >Grant Sub</button>
                  <button
                    v-else
                    @click="revokeSubscription(u)"
                    class="btn-sm btn-warning"
                    title="Revoke subscription"
                  >Revoke Sub</button>
                  <button
                    @click="toggleBlock(u)"
                    :class="['btn-sm', u.is_blocked ? 'btn-info' : 'btn-danger']"
                  >{{ u.is_blocked ? 'Unblock' : 'Block' }}</button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
        <div v-else class="empty-state">No users yet</div>
      </div>

      <div v-if="data?.total > data?.limit" class="pagination">
        <button v-if="page > 1" @click="page--;load()" class="btn-sm">Previous</button>
        <span class="page-info">Page {{ page }} of {{ Math.ceil(data.total / data.limit) }}</span>
        <button v-if="data.total > page * data.limit" @click="page++;load()" class="btn-sm">Next</button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const { api } = useApi();
const users = ref<any[]>([]);
const data = ref<any>(null);
const page = ref(1);
const grantModal = ref<any>(null);
const grantDays = ref(30);

async function load() {
  try {
    data.value = await api(`users?page=${page.value}`);
    users.value = data.value.users;
  } catch {}
}

async function toggleBlock(u: any) {
  const action = u.is_blocked ? 'unblock' : 'block';
  if (!confirm(`${action.charAt(0).toUpperCase() + action.slice(1)} user "${u.name}" (${u.email})?`)) return;
  try {
    await api(`users/${u.id}/block`, { method: 'POST' });
    load();
  } catch (e: any) {
    alert(e.data?.message || 'Failed');
  }
}

async function grantSubscription() {
  if (!grantModal.value) return;
  try {
    await api(`users/${grantModal.value.id}/subscription`, {
      method: 'POST',
      body: { action: 'grant', days: grantDays.value },
    });
    grantModal.value = null;
    load();
  } catch (e: any) {
    alert(e.data?.message || 'Failed');
  }
}

async function revokeSubscription(u: any) {
  if (!confirm(`Revoke subscription for "${u.name}"?`)) return;
  try {
    await api(`users/${u.id}/subscription`, {
      method: 'POST',
      body: { action: 'revoke' },
    });
    load();
  } catch (e: any) {
    alert(e.data?.message || 'Failed');
  }
}

onMounted(load);
</script>

<style scoped>
.table-container {
  overflow-x: auto;
}

.text-primary {
  color: var(--color-text-primary);
  font-weight: 500;
}

.text-secondary {
  color: var(--color-text-secondary);
  font-size: 0.875rem;
}

.row-blocked {
  opacity: 0.6;
  background: var(--color-danger-subtle, rgba(239, 68, 68, 0.04));
}

.actions-cell {
  display: flex;
  gap: 6px;
  flex-wrap: nowrap;
}

.btn-success {
  background: var(--color-success);
  color: #fff;
  border-color: var(--color-success);
}
.btn-success:hover {
  opacity: 0.85;
}

.btn-warning {
  background: var(--color-warning, #f59e0b);
  color: #000;
  border-color: var(--color-warning, #f59e0b);
}
.btn-warning:hover {
  opacity: 0.85;
}

.badge-muted {
  background: var(--color-bg-tertiary);
  color: var(--color-text-tertiary);
}

/* Modal */
.modal-backdrop {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.6);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.modal-card {
  min-width: 360px;
  max-width: 440px;
}
</style>
