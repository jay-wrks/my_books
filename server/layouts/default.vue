<template>
  <div class="app-root">
    <!-- ADMIN SIDEBAR LAYOUT -->
    <div v-if="isAdmin" class="admin-layout">
      <aside class="sidebar">
        <div class="sidebar-inner">
          <!-- Brand -->
          <div class="sidebar-brand">
            <div class="brand-icon">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"/><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"/>
              </svg>
            </div>
            <span class="brand-name">Aravind</span>
          </div>

          <!-- Navigation -->
          <nav class="sidebar-nav">
            <template v-if="navMain.length">
              <span class="nav-section-label">Main</span>
              <a v-for="item in navMain" :key="item.to" :href="item.to"
                @click.prevent="navigateTo(item.to)"
                :class="['nav-link', { active: route.path === item.to }]">
                <span class="nav-icon" v-html="item.svg"></span>
                <span>{{ item.label }}</span>
              </a>
            </template>

            <span class="nav-section-label">Content</span>
            <a v-for="item in navContent" :key="item.to" :href="item.to"
              @click.prevent="navigateTo(item.to)"
              :class="['nav-link', { active: route.path === item.to }]">
              <span class="nav-icon" v-html="item.svg"></span>
              <span>{{ item.label }}</span>
            </a>
          </nav>

          <!-- Footer -->
          <div class="sidebar-footer">
            <button @click="logout" class="nav-link logout-link">
              <span class="nav-icon">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/>
                </svg>
              </span>
              <span>Log out</span>
            </button>
          </div>
        </div>
      </aside>

      <!-- Mobile toggle -->
      <button class="mobile-menu-btn" @click="mobileOpen = !mobileOpen" v-if="false">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 12h18M3 6h18M3 18h18"/></svg>
      </button>

      <main class="main-content">
        <div class="content-container">
          <slot />
        </div>
      </main>
    </div>

    <!-- PUBLIC (subscribe page, login) -->
    <div v-else class="public-layout">
      <slot />
    </div>
  </div>
</template>

<script setup lang="ts">
const route = useRoute();
const adminToken = useCookie('admin_token');
const userRole = useCookie('user_role');
const mobileOpen = ref(false);

const publicPages = ['/subscribe', '/login'];
const isAdmin = computed(() => !publicPages.includes(route.path) && !!adminToken.value);
const isDev = computed(() => userRole.value === 'developer');

const svgDashboard = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/></svg>';
const svgDeploy = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2L2 7l10 5 10-5-10-5z"/><path d="M2 17l10 5 10-5"/><path d="M2 12l10 5 10-5"/></svg>';
const svgMonitor = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/></svg>';
const svgDatabase = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M21 12c0 1.66-4 3-9 3s-9-1.34-9-3"/><path d="M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5"/></svg>';
const svgPdfs = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></svg>';
const svgUsers = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>';
const svgSubjects = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/></svg>';
const svgAdmins = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>';

const navMain = computed(() => {
  if (!isDev.value) return [];
  return [
    { to: '/', svg: svgDashboard, label: 'Dashboard' },
    { to: '/deploy', svg: svgDeploy, label: 'Deploy' },
    { to: '/monitor', svg: svgMonitor, label: 'Monitor' },
    { to: '/database', svg: svgDatabase, label: 'Database' },
  ];
});

const navContent = computed(() => {
  const items = [
    { to: '/pdfs', svg: svgPdfs, label: 'PDFs' },
    { to: '/users', svg: svgUsers, label: 'Users' },
    { to: '/subjects', svg: svgSubjects, label: 'Subjects' },
  ];
  if (isDev.value) {
    items.push({ to: '/admins', svg: svgAdmins, label: 'Admins' });
  }
  return items;
});

function logout() {
  adminToken.value = null;
  userRole.value = null;
  navigateTo('/login');
}
</script>

<style scoped>
.app-root {
  min-height: 100vh;
}

.admin-layout {
  display: flex;
  min-height: 100vh;
}

.sidebar {
  width: var(--sidebar-width);
  background: var(--color-bg-primary);
  border-right: 1px solid var(--color-border-subtle);
  flex-shrink: 0;
  position: fixed;
  top: 0;
  left: 0;
  bottom: 0;
  z-index: 50;
}

.sidebar-inner {
  display: flex;
  flex-direction: column;
  height: 100%;
  padding: var(--space-5) var(--space-4);
}

.sidebar-brand {
  display: flex;
  align-items: center;
  gap: var(--space-3);
  padding: var(--space-2) var(--space-3);
  margin-bottom: var(--space-7);
}

.brand-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 32px;
  height: 32px;
  background: var(--color-accent-subtle);
  color: var(--color-accent);
  border-radius: var(--radius-md);
}

.brand-name {
  font-size: 1.0625rem;
  font-weight: 700;
  letter-spacing: -0.03em;
  color: var(--color-text-primary);
}

.sidebar-nav {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.nav-section-label {
  display: block;
  font-size: 0.6875rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--color-text-muted);
  padding: var(--space-4) var(--space-3) var(--space-2);
}

.nav-section-label:first-child {
  padding-top: 0;
}

.nav-link {
  display: flex;
  align-items: center;
  gap: var(--space-3);
  padding: 8px 12px;
  border-radius: var(--radius-md);
  font-size: 0.8125rem;
  font-weight: 500;
  color: var(--color-text-tertiary);
  text-decoration: none;
  transition: all var(--transition-fast);
  cursor: pointer;
  border: none;
  background: none;
  width: 100%;
  text-align: left;
}

.nav-link:hover {
  color: var(--color-text-primary);
  background: var(--color-bg-hover);
}

.nav-link.active {
  color: var(--color-text-primary);
  background: var(--color-bg-active);
}

.nav-link.active .nav-icon {
  color: var(--color-accent);
}

.nav-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 20px;
  height: 20px;
  flex-shrink: 0;
  color: var(--color-text-muted);
  transition: color var(--transition-fast);
}

.nav-link:hover .nav-icon {
  color: var(--color-text-secondary);
}

.sidebar-footer {
  padding-top: var(--space-4);
  border-top: 1px solid var(--color-border-subtle);
}

.logout-link {
  color: var(--color-text-muted);
  font-family: var(--font-sans);
}

.logout-link:hover {
  color: var(--color-danger);
  background: var(--color-danger-subtle);
}

.logout-link:hover .nav-icon {
  color: var(--color-danger);
}

.main-content {
  flex: 1;
  margin-left: var(--sidebar-width);
  min-height: 100vh;
  background: var(--color-bg-root);
}

.content-container {
  max-width: var(--content-max-width);
  padding: var(--space-8) var(--space-8);
}

.public-layout {
  min-height: 100vh;
  background: var(--color-bg-root);
}

.mobile-menu-btn {
  display: none;
}

@media (max-width: 768px) {
  .sidebar {
    transform: translateX(-100%);
    transition: transform var(--transition-base);
  }

  .sidebar.open {
    transform: translateX(0);
  }

  .main-content {
    margin-left: 0;
  }

  .content-container {
    padding: var(--space-5) var(--space-4);
  }

  .mobile-menu-btn {
    display: flex;
    position: fixed;
    top: var(--space-4);
    left: var(--space-4);
    z-index: 40;
  }
}
</style>
