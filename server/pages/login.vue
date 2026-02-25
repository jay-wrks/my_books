<template>
  <div style="max-width:400px;margin:15vh auto;padding:2rem">
    <h2 style="text-align:center;color:#10b981;margin-bottom:2rem">🎓 Aravind Admin</h2>
    <form @submit.prevent="doLogin">
      <label>Email <input v-model="email" type="email" required /></label>
      <label>Password <input v-model="password" type="password" required /></label>
      <button type="submit" :disabled="loading" style="width:100%;background:#059669">
        {{ loading ? 'Logging in...' : 'Login' }}
      </button>
      <p v-if="error" style="color:#f87171;text-align:center;margin-top:1rem">{{ error }}</p>
    </form>
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
