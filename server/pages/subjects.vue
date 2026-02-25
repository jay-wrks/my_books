<template>
  <div>
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:1.5rem">
      <h2>📖 Subjects</h2>
      <button @click="showForm = !showForm" style="background:#059669">{{ showForm ? '✕ Cancel' : '+ Add Subject' }}</button>
    </div>

    <!-- Form -->
    <div v-if="showForm" style="background:#111;border-radius:12px;padding:1.25rem;border:1px solid #222;margin-bottom:1.5rem">
      <div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:1rem">
        <label>Name <input v-model="form.name" required /></label>
        <label>Icon Name <input v-model="form.iconName" placeholder="book" /></label>
        <label>Display Order <input v-model.number="form.displayOrder" type="number" /></label>
      </div>
      <button @click="save" style="background:#059669;margin-top:1rem">{{ editId ? 'Update' : 'Create' }}</button>
    </div>

    <!-- List -->
    <div style="background:#111;border-radius:12px;padding:1.25rem;border:1px solid #222;overflow-x:auto">
      <table v-if="subjects.length" style="font-size:0.85rem">
        <thead><tr><th>Order</th><th>Name</th><th>Icon</th><th>ID</th><th>Actions</th></tr></thead>
        <tbody>
          <tr v-for="s in subjects" :key="s.id">
            <td>{{ s.display_order }}</td>
            <td>{{ s.name }}</td>
            <td>{{ s.icon_name }}</td>
            <td style="color:#6b7280">{{ s.id }}</td>
            <td style="display:flex;gap:0.25rem">
              <button @click="edit(s)" style="font-size:0.75rem;padding:0.25rem 0.5rem;background:#2563eb">✏️</button>
              <button @click="del(s.id)" style="font-size:0.75rem;padding:0.25rem 0.5rem;background:#dc2626">🗑️</button>
            </td>
          </tr>
        </tbody>
      </table>
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
