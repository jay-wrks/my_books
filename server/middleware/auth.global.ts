// Middleware: redirect to login if no admin token, restrict dev-only pages
export default defineNuxtRouteMiddleware((to) => {
  const token = useCookie('admin_token');
  const userRole = useCookie('user_role');
  const publicPages = ['/login', '/subscribe'];

  if (!publicPages.includes(to.path) && !token.value) {
    return navigateTo('/login');
  }

  // Developer-only pages: dashboard, deploy, monitor, database, admins
  const devOnlyPages = ['/', '/deploy', '/monitor', '/database', '/admins'];
  if (devOnlyPages.includes(to.path) && userRole.value === 'admin') {
    return navigateTo('/pdfs');
  }
});
