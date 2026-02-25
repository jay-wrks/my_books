// Middleware: redirect to login if no admin token
export default defineNuxtRouteMiddleware((to) => {
  const token = useCookie('admin_token');
  const publicPages = ['/login', '/subscribe'];
  if (!publicPages.includes(to.path) && !token.value) {
    return navigateTo('/login');
  }
});
