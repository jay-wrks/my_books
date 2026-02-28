<template>
  <div>
    <div class="page-header">
      <div>
        <h2>Subjects</h2>
        <p class="page-description">Manage academic subjects and categories</p>
      </div>
      <button @click="showForm = !showForm" :class="showForm ? '' : 'btn-primary'">
        {{ showForm ? 'Cancel' : 'Add Subject' }}
      </button>
    </div>

    <!-- Form -->
    <div v-if="showForm" class="card mb-6">
      <h4 class="mb-5">{{ editId ? 'Edit Subject' : 'New Subject' }}</h4>
      <div class="form-grid">
        <label>
          <span>Name</span>
          <input v-model="form.name" required placeholder="e.g. Mathematics" />
        </label>
        <label>
          <span>Icon Name</span>
          <input v-model="form.iconName" placeholder="book" />
        </label>
        <label>
          <span>Display Order</span>
          <input v-model.number="form.displayOrder" type="number" />
        </label>
      </div>
      <div class="mt-4">
        <button @click="save" class="btn-primary">{{ editId ? 'Update Subject' : 'Create Subject' }}</button>
      </div>
    </div>

    <!-- List -->
    <div class="card">
      <div class="table-container">
        <table v-if="subjects.length">
          <thead><tr><th>Order</th><th>Name</th><th>Icon</th><th>ID</th><th>Actions</th></tr></thead>
          <tbody>
            <tr v-for="s in subjects" :key="s.id">
              <td>{{ s.display_order }}</td>
              <td class="text-primary">{{ s.name }}</td>
              <td><code>{{ s.icon_name }}</code></td>
              <td class="text-muted">{{ s.id }}</td>
              <td>
                <div class="flex gap-2">
                  <button @click="edit(s)" class="btn-sm btn-info">Edit</button>
                  <button @click="del(s.id)" class="btn-sm btn-danger">Delete</button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
        <div v-else class="empty-state">No subjects created yet</div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const { api } = useApi();
const subjects = ref<any[]>([]);
const showForm = ref(false);
const editId = ref<string | null>(null);
const form = reactive({ name: '', iconName: 'book', displayOrder: 0 });

function edit(s: any) {
  editId.value = s.id;
  Object.assign(form, { name: s.name, iconName: s.icon_name, displayOrder: s.display_order });
  showForm.value = true;
}

async function save() {
  if (!form.name) return;
  if (editId.value) {
    await api(`subjects/${editId.value}`, { method: 'PUT', body: form });
  } else {
    await api('subjects', { method: 'POST', body: form });
  }
  showForm.value = false;
  editId.value = null;
  load();
}

async function del(id: string) {
  if (!confirm('Delete subject? This will also delete all PDFs under it.')) return;
  await api(`subjects/${id}`, { method: 'DELETE' });
  load();
}

async function load() {
  try { subjects.value = (await api('subjects')).subjects; } catch {}
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

.text-muted {
  color: var(--color-text-muted);
  font-family: var(--font-mono);
  font-size: 0.75rem;
}

.form-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: var(--space-4);
}

@media (max-width: 768px) {
  .form-grid {
    grid-template-columns: 1fr;
  }
}
</style>
