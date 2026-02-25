<template>
  <div :data-theme="'dark'" style="min-height:100vh">
    <!-- ADMIN SIDEBAR LAYOUT -->
    <div v-if="isAdmin" style="display:flex;min-height:100vh">
      <aside style="width:220px;background:#111;border-right:1px solid #333;padding:1rem;flex-shrink:0">
        <h3 style="color:#10b981;margin-bottom:2rem">🎓 Aravind</h3>
        <nav>
          <a v-for="item in nav" :key="item.to" :href="item.to"
            @click.prevent="navigateTo(item.to)"
            :style="{display:'block',padding:'0.5rem 0.75rem',marginBottom:'0.25rem',borderRadius:'8px',textDecoration:'none',fontSize:'0.9rem',
              background: route.path === item.to ? '#059669' : 'transparent',
              color: route.path === item.to ? '#fff' : '#9ca3af'}">
            {{ item.icon }} {{ item.label }}
          </a>
        </nav>
        <div style="position:absolute;bottom:1rem">
          <a href="#" @click.prevent="logout" style="color:#f87171;font-size:0.85rem;text-decoration:none">🚪 Logout</a>
        </div>
      </aside>
      <main style="flex:1;padding:1.5rem;overflow:auto;background:#0a0a0a">
        <slot />
      </main>
    </div>
    <!-- PUBLIC (subscribe page, login) -->
    <div v-else>
      <slot />
    </div>
  </div>
</template>

<script setup lang="ts">
const route = useRoute();
const adminToken = useCookie('admin_token');

const publicPages = ['/subscribe', '/login'];
const isAdmin = computed(() => !publicPages.includes(route.path) && !!adminToken.value);

const nav = [
  { to: '/', icon: '📊', label: 'Dashboard' },
  { to: '/deploy', icon: '🚀', label: 'Deploy' },
  { to: '/monitor', icon: '📡', label: 'Monitor' },
  { to: '/database', icon: '🗄️', label: 'Database' },
  { to: '/pdfs', icon: '📚', label: 'PDFs' },
  { to: '/users', icon: '👥', label: 'Users' },
  { to: '/subjects', icon: '📖', label: 'Subjects' },
];

function logout() {
  adminToken.value = null;
  navigateTo('/login');
}
</script>
