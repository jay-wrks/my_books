// ============================================================================
// Admin auth middleware — checks admin_token cookie or Authorization header
// ============================================================================

import { verifyJwt } from '../../shared/auth';

export default defineEventHandler((event) => {
  const path = getRequestURL(event).pathname;

  // Public endpoints — skip auth
  if (path === '/api/admin/login' ||
      path === '/api/razorpay-webhook' ||
      path.startsWith('/api/subscribe')) {
    return;
  }

  // All other /api/ routes need admin auth
  if (!path.startsWith('/api/')) return;

  const token = getCookie(event, 'admin_token') ||
    getRequestHeader(event, 'authorization')?.replace('Bearer ', '');

  if (!token) {
    throw createError({ statusCode: 401, message: 'Not authenticated' });
  }

  const payload = verifyJwt(token);
  if (!payload || (payload.role !== 'admin' && payload.role !== 'developer')) {
    throw createError({ statusCode: 403, message: 'Admin access required' });
  }

  // Attach to event context
  event.context.admin = payload;
});
