<template>
  <div>
    <div class="page-header">
      <div>
        <h2>Users</h2>
        <p class="page-description">Manage registered users and subscriptions</p>
      </div>
    </div>

    <div class="card">
      <div class="table-container">
        <table v-if="users.length">
          <thead><tr><th>Name</th><th>Email</th><th>Phone</th><th>Subscription</th><th>Expires</th><th>Joined</th></tr></thead>
          <tbody>
            <tr v-for="u in users" :key="u.id">
              <td class="text-primary">{{ u.name }}</td>
              <td>{{ u.email }}</td>
              <td>{{ u.phone || '—' }}</td>
              <td>
                <span :class="['badge', u.sub_status === 'active' ? 'badge-success' : 'badge-danger']">
                  {{ u.sub_status || 'none' }}
                </span>
              </td>
              <td>{{ u.sub_expires ? new Date(u.sub_expires).toLocaleDateString() : '—' }}</td>
              <td>{{ new Date(u.created_at).toLocaleDateString() }}</td>
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

async function load() {
  try {
    data.value = await api(`users?page=${page.value}`);
    users.value = data.value.users;
  } catch {}
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
</style>
