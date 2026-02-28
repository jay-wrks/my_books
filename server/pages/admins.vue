<template>
  <div>
    <div class="page-header">
      <div>
        <h2>Admin Accounts</h2>
        <p class="page-description">Create and manage admin accounts for the web panel</p>
      </div>
      <button @click="showForm = !showForm" :class="showForm ? '' : 'btn-primary'">
        {{ showForm ? 'Cancel' : 'Add Admin' }}
      </button>
    </div>

    <!-- Create form -->
    <div v-if="showForm" class="card mb-6">
      <h4 class="mb-5">New Admin Account</h4>
      <div class="form-grid">
        <label>
          <span>Name</span>
          <input v-model="form.name" required placeholder="e.g. John" />
        </label>
        <label>
          <span>Email</span>
          <input v-model="form.email" type="email" required placeholder="admin@example.com" />
        </label>
        <label>
          <span>Password</span>
          <input v-model="form.password" type="password" required placeholder="Min 6 characters" />
        </label>
      </div>
      <p v-if="formError" class="form-error mt-3">{{ formError }}</p>
      <div class="mt-4">
        <button @click="create" class="btn-primary" :disabled="creating">
          {{ creating ? 'Creating...' : 'Create Admin' }}
        </button>
      </div>
    </div>

    <!-- List -->
    <div class="card">
      <div class="table-container">
        <table v-if="admins.length">
          <thead><tr><th>Name</th><th>Email</th><th>Created</th><th>Actions</th></tr></thead>
          <tbody>
            <tr v-for="a in admins" :key="a.id">
              <td class="text-primary">{{ a.name }}</td>
              <td>{{ a.email }}</td>
              <td class="text-muted">{{ formatDate(a.created_at) }}</td>
              <td>
                <div class="flex gap-2">
                  <button @click="resetPwd(a)" class="btn-sm btn-info">Reset Password</button>
                  <button @click="del(a)" class="btn-sm btn-danger">Delete</button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
        <div v-else class="empty-state">No admin accounts yet. Create one to get started.</div>
      </div>
    </div>

    <!-- Reset Password Modal -->
    <div v-if="resetTarget" class="modal-overlay" @click.self="resetTarget = null">
      <div class="modal-card">
        <h4 class="mb-4">Reset Password — {{ resetTarget.name }}</h4>
        <label>
          <span>New Password</span>
          <input v-model="newPassword" type="password" placeholder="Min 6 characters" @keyup.enter="doReset" />
        </label>
        <p v-if="resetError" class="form-error mt-3">{{ resetError }}</p>
        <div class="mt-4 flex gap-3">
          <button @click="doReset" class="btn-primary" :disabled="resetting">
            {{ resetting ? 'Resetting...' : 'Reset' }}
          </button>
          <button @click="resetTarget = null">Cancel</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const { api } = useApi();
const admins = ref<any[]>([]);
const showForm = ref(false);
const creating = ref(false);
const formError = ref('');
const form = reactive({ name: '', email: '', password: '' });

const resetTarget = ref<any>(null);
const newPassword = ref('');
const resetting = ref(false);
const resetError = ref('');

function formatDate(d: string) {
  if (!d) return '—';
  return new Date(d).toLocaleDateString('en-IN', { year: 'numeric', month: 'short', day: 'numeric' });
}

async function load() {
  try {
    const res = await api('admins');
    admins.value = res.admins;
  } catch {}
}

async function create() {
  formError.value = '';
  if (!form.name || !form.email || !form.password) {
    formError.value = 'All fields are required';
    return;
  }
  if (form.password.length < 6) {
    formError.value = 'Password must be at least 6 characters';
    return;
  }
  creating.value = true;
  try {
    await api('admins', { method: 'POST', body: { ...form } });
    showForm.value = false;
    Object.assign(form, { name: '', email: '', password: '' });
    load();
  } catch (e: any) {
    formError.value = e.data?.message || 'Failed to create admin';
  } finally {
    creating.value = false;
  }
}

function resetPwd(admin: any) {
  resetTarget.value = admin;
  newPassword.value = '';
  resetError.value = '';
}

async function doReset() {
  resetError.value = '';
  if (!newPassword.value || newPassword.value.length < 6) {
    resetError.value = 'Password must be at least 6 characters';
    return;
  }
  resetting.value = true;
  try {
    await api(`admins/${resetTarget.value.id}/reset-password`, {
      method: 'POST',
      body: { password: newPassword.value },
    });
    resetTarget.value = null;
  } catch (e: any) {
    resetError.value = e.data?.message || 'Failed to reset password';
  } finally {
    resetting.value = false;
  }
}

async function del(admin: any) {
  if (!confirm(`Delete admin "${admin.name}" (${admin.email})?`)) return;
  try {
    await api(`admins/${admin.id}`, { method: 'DELETE' });
    load();
  } catch (e: any) {
    alert(e.data?.message || 'Failed to delete');
  }
}

onMounted(load);
</script>

<style scoped>
.table-container { overflow-x: auto; }
.text-primary { color: var(--color-text-primary); font-weight: 500; }
.text-muted { color: var(--color-text-muted); font-size: 0.8rem; }
.form-error { color: var(--color-danger); font-size: 0.85rem; }
.form-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: var(--space-4);
}
@media (max-width: 768px) {
  .form-grid { grid-template-columns: 1fr; }
}
.modal-overlay {
  position: fixed; inset: 0;
  background: rgba(0,0,0,.6);
  display: flex; align-items: center; justify-content: center;
  z-index: 100;
}
.modal-card {
  background: var(--color-bg-primary);
  border: 1px solid var(--color-border-subtle);
  border-radius: var(--radius-lg);
  padding: var(--space-6);
  width: 100%; max-width: 400px;
}
</style>
