// ============================================================================
// RAZORPAY WEBHOOK — handles subscription events
// Public endpoint: POST /api/razorpay-webhook
// ============================================================================

import { getDb } from '../../shared/db';
import { pushToWsUser } from '../utils/ws-manager';
import { v4 as uuid } from 'uuid';
import crypto from 'crypto';

export default defineEventHandler(async (event) => {
  const config = useRuntimeConfig();
  const body = await readRawBody(event);
  if (!body) throw createError({ statusCode: 400, message: 'Empty body' });

  // Verify Razorpay signature
  const signature = getRequestHeader(event, 'x-razorpay-signature');
  if (!signature) throw createError({ statusCode: 400, message: 'Missing signature' });

  const expected = crypto.createHmac('sha256', config.razorpayWebhookSecret).update(body).digest('hex');
  if (signature !== expected) {
    throw createError({ statusCode: 401, message: 'Invalid signature' });
  }

  const payload = JSON.parse(body);
  const eventType = payload.event;
  const entity = payload.payload?.subscription?.entity || payload.payload?.payment?.entity || {};
  const db = getDb();

  console.log(`[RAZORPAY] Webhook: ${eventType}`);

  // Extract user_id from notes (we pass it during subscription creation)
  const userId = entity.notes?.user_id || entity.notes?.userId;

  if (!userId) {
    console.warn('[RAZORPAY] No user_id in notes, skipping');
    return { ok: true };
  }

  // Verify user exists
  const user = db.prepare('SELECT id FROM users WHERE id = ?').get(userId) as any;
  if (!user) {
    console.warn(`[RAZORPAY] User ${userId} not found`);
    return { ok: true };
  }

  switch (eventType) {
    case 'subscription.activated':
    case 'subscription.charged': {
      // Create or update subscription to active
      const subId = entity.id || '';
      const paymentId = payload.payload?.payment?.entity?.id || '';
      const amount = entity.plan?.item?.amount ? entity.plan.item.amount / 100 : 0;

      // Calculate expiry — 30 days from now
      const expiresAt = new Date(Date.now() + 30 * 86400_000).toISOString();
      const startedAt = new Date().toISOString();

      // Expire any old active subs for this user
      db.prepare("UPDATE subscriptions SET status = 'expired' WHERE user_id = ? AND status = 'active'").run(userId);

      // Create new active subscription
      db.prepare(`INSERT INTO subscriptions (id, user_id, status, razorpay_subscription_id, razorpay_payment_id, amount, started_at, expires_at)
        VALUES (?, ?, 'active', ?, ?, ?, ?, ?)`).run(uuid(), userId, subId, paymentId, amount, startedAt, expiresAt);

      // Record payment
      db.prepare('INSERT INTO payments (id, user_id, razorpay_payment_id, razorpay_subscription_id, amount, status) VALUES (?, ?, ?, ?, ?, \'captured\')')
        .run(uuid(), userId, paymentId, subId, amount);

      console.log(`[RAZORPAY] Subscription activated for user ${userId}, expires ${expiresAt}`);

      // Push real-time event to connected Flutter client
      try { await pushToWsUser(userId, 'subscriptionActivated', { status: 'active', expiresAt }); } catch {}
      break;
    }

    case 'subscription.cancelled':
    case 'subscription.halted':
    case 'subscription.expired': {
      db.prepare("UPDATE subscriptions SET status = 'cancelled' WHERE user_id = ? AND status = 'active'").run(userId);
      console.log(`[RAZORPAY] Subscription cancelled/halted for user ${userId}`);

      // Push real-time event to connected Flutter client
      try { await pushToWsUser(userId, 'subscriptionExpired', { status: 'none' }); } catch {}
      break;
    }

    case 'payment.failed': {
      const paymentId = payload.payload?.payment?.entity?.id || '';
      db.prepare('INSERT INTO payments (id, user_id, razorpay_payment_id, amount, status) VALUES (?, ?, ?, 0, \'failed\')')
        .run(uuid(), userId, paymentId);
      console.log(`[RAZORPAY] Payment failed for user ${userId}`);
      break;
    }
  }

  return { ok: true };
});
