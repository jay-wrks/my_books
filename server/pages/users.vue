<template>
  <div>
    <h2 style="margin-bottom:1.5rem">👥 Users</h2>

    <div style="background:#111;border-radius:12px;padding:1.25rem;border:1px solid #222;overflow-x:auto">
      <table v-if="users.length" style="font-size:0.85rem">
        <thead><tr><th>Name</th><th>Email</th><th>Phone</th><th>Subscription</th><th>Expires</th><th>Joined</th></tr></thead>
        <tbody>
          <tr v-for="u in users" :key="u.id">
            <td>{{ u.name }}</td>
            <td>{{ u.email }}</td>
            <td>{{ u.phone || '—' }}</td>
            <td><span :style="{color: u.sub_status === 'active' ? '#10b981' : '#f87171', fontWeight:600}">{{ u.sub_status || 'none' }}</span></td>
            <td>{{ u.sub_expires ? new Date(u.sub_expires).toLocaleDateString() : '—' }}</td>
            <td>{{ new Date(u.created_at).toLocaleDateString() }}</td>
          </tr>
        </tbody>
      </table>
      <p v-else style="color:#6b7280">No users yet</p>

      <div v-if="data?.total > data?.limit" style="display:flex;gap:0.5rem;margin-top:1rem;justify-content:center">
        <button v-if="page > 1" @click="page--;load()" style="padding:0.25rem 0.75rem;background:#333">← Prev</button>
        <span style="padding:0.5rem;color:#9ca3af;font-size:0.85rem">Page {{ page }} of {{ Math.ceil(data.total / data.limit) }}</span>
        <button v-if="data.total > page * data.limit" @click="page++;load()" style="padding:0.25rem 0.75rem;background:#333">Next →</button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const { api } = useApi();
const users = ref<any[]>([]);
const data = ref<any>(null);
const page = ref(1);

async function load() {
  try {
    data.value = await api(`users?page=${page.value}`);
    users.value = data.value.users;
  } catch {}
}
onMounted(load);
</script>
