// ============================================================================
// SUBSCRIBE API — creates Razorpay subscription for a user
// Public endpoint: POST /api/subscribe/create
// ============================================================================

import { getDb } from '../../../shared/db';
import https from 'https';

export default defineEventHandler(async (event) => {
  const { userId } = await readBody(event);
  if (!userId) throw createError({ statusCode: 400, message: 'userId required' });

  const config = useRuntimeConfig();
  const db = getDb();

  // Verify user exists
  const user = db.prepare('SELECT id, name, email, phone FROM users WHERE id = ?').get(userId) as any;
  if (!user) throw createError({ statusCode: 404, message: 'User not found' });

  // Check if already has active subscription
  const activeSub = db.prepare(`SELECT id FROM subscriptions WHERE user_id = ? AND status = 'active' AND datetime(expires_at) > datetime('now')`).get(userId);
  if (activeSub) return { alreadyActive: true };

  // Create Razorpay subscription
  const subsData = JSON.stringify({
    plan_id: config.razorpayPlanId,
    total_count: 12, // max 12 months
    quantity: 1,
    notes: { user_id: userId, email: user.email },
  });

  const result = await new Promise<any>((resolve, reject) => {
    const req = https.request({
      hostname: 'api.razorpay.com',
      path: '/v1/subscriptions',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Basic ' + Buffer.from(`${config.razorpayKeyId}:${config.razorpayKeySecret}`).toString('base64'),
      },
    }, (res) => {
      let data = '';
      res.on('data', c => data += c);
      res.on('end', () => {
        try { resolve(JSON.parse(data)); } catch { reject(new Error(data)); }
      });
    });
    req.on('error', reject);
    req.write(subsData);
    req.end();
  });

  if (result.error) {
    throw createError({ statusCode: 400, message: result.error.description || 'Razorpay error' });
  }

  return {
    subscriptionId: result.id,
    razorpayKeyId: config.public.razorpayKeyId,
    userName: user.name,
    userEmail: user.email,
    userPhone: user.phone,
  };
});
