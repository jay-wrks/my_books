<template>
  <div class="login-page">
    <div class="login-container">
      <!-- Brand -->
      <div class="login-brand">
        <div class="brand-mark">
          <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"/><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"/>
          </svg>
        </div>
        <h1>Aravind</h1>
        <p>Sign in to your admin panel</p>
      </div>

      <!-- Form -->
      <form @submit.prevent="doLogin" class="login-form">
        <label>
          <span>Email address</span>
          <input v-model="email" type="email" required placeholder="admin@example.com" autocomplete="email" />
        </label>
        <label>
          <span>Password</span>
          <input v-model="password" type="password" required placeholder="Enter your password" autocomplete="current-password" />
        </label>
        <button type="submit" :disabled="loading" class="btn-primary btn-lg login-btn">
          {{ loading ? 'Signing in...' : 'Sign in' }}
        </button>
        <p v-if="error" class="login-error">{{ error }}</p>
      </form>
    </div>
  </div>
</template>

<script setup lang="ts">
const { api } = useApi();
const token = useCookie('admin_token', { maxAge: 30 * 86400 });
const email = ref('');
const password = ref('');
const loading = ref(false);
const error = ref('');

async function doLogin() {
  loading.value = true;
  error.value = '';
  try {
    const res = await $fetch<any>('/api/admin/login', {
      method: 'POST',
      body: { email: email.value, password: password.value },
    });
    token.value = res.token;
    navigateTo('/');
  } catch (e: any) {
    error.value = e.data?.message || 'Login failed';
  } finally {
    loading.value = false;
  }
}

// Redirect if already logged in
onMounted(() => { if (token.value) navigateTo('/'); });
</script>

<style scoped>
.login-page {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 100vh;
  padding: var(--space-6);
  background: var(--color-bg-root);
}

.login-container {
  width: 100%;
  max-width: 380px;
}

.login-brand {
  text-align: center;
  margin-bottom: var(--space-8);
}

.brand-mark {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 52px;
  height: 52px;
  background: var(--color-accent-subtle);
  color: var(--color-accent);
  border-radius: var(--radius-lg);
  margin-bottom: var(--space-5);
}

.login-brand h1 {
  font-size: 1.5rem;
  font-weight: 700;
  letter-spacing: -0.03em;
  margin-bottom: 4px;
}

.login-brand p {
  font-size: 0.875rem;
  color: var(--color-text-tertiary);
}

.login-form {
  background: var(--color-bg-surface);
  border: 1px solid var(--color-border-subtle);
  border-radius: var(--radius-xl);
  padding: var(--space-7);
  display: flex;
  flex-direction: column;
  gap: var(--space-5);
}

.login-btn {
  width: 100%;
  margin-top: var(--space-2);
}

.login-error {
  text-align: center;
  font-size: 0.8125rem;
  color: var(--color-danger);
  background: var(--color-danger-subtle);
  padding: 8px 12px;
  border-radius: var(--radius-md);
}
</style>
