<template>
  <div class="subscribe-page">
    <div class="subscribe-container">
      <!-- Loading -->
      <div v-if="loading" class="state-card">
        <div class="shimmer state-shimmer"></div>
        <p class="state-text">Loading subscription details...</p>
      </div>

      <!-- Error -->
      <div v-else-if="error" class="state-card">
        <div class="state-icon error-icon">
          <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/>
          </svg>
        </div>
        <h3>{{ error }}</h3>
        <p class="state-text">Please go back to the app and try again.</p>
      </div>

      <!-- Already Active -->
      <div v-else-if="alreadyActive" class="state-card">
        <div class="state-icon success-icon">
          <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/>
          </svg>
        </div>
        <h2>Already Subscribed</h2>
        <p class="state-text">Your subscription is active. Go back to the app to access all PDFs.</p>
      </div>

      <!-- Payment Success -->
      <div v-else-if="paymentDone" class="state-card">
        <div class="state-icon success-icon">
          <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/>
          </svg>
        </div>
        <h2>Payment Successful</h2>
        <p class="state-subtitle">Your subscription is now active.</p>
        <p class="state-text">Go back to the <strong>Aravind app</strong> and refresh to access all study materials.</p>
      </div>

      <!-- Subscribe Form -->
      <div v-else>
        <div class="subscribe-brand">
          <div class="brand-mark">
            <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"/><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"/>
            </svg>
          </div>
          <h1>Aravind</h1>
          <p>Unlock all study materials</p>
        </div>

        <div class="plan-card">
          <div class="plan-header">
            <span class="plan-badge">Monthly Plan</span>
          </div>

          <div class="plan-price">
            <span class="price-amount">₹199</span>
            <span class="price-period">/month</span>
          </div>

          <ul class="plan-features">
            <li>
              <svg class="check-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
              Access all PDFs (Class 1-12)
            </li>
            <li>
              <svg class="check-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
              All subjects included
            </li>
            <li>
              <svg class="check-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
              New materials added weekly
            </li>
            <li>
              <svg class="check-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
              Read anywhere, anytime
            </li>
            <li>
              <svg class="check-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
              Cancel anytime
            </li>
          </ul>

          <button @click="openRazorpay" :disabled="paying" class="subscribe-btn">
            {{ paying ? 'Processing...' : 'Subscribe Now' }}
          </button>

          <p class="plan-footer">Powered by Razorpay. Secure payment.</p>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const route = useRoute();
const config = useRuntimeConfig();

const loading = ref(true);
const error = ref('');
const alreadyActive = ref(false);
const paymentDone = ref(false);
const paying = ref(false);
const subData = ref<any>(null);

onMounted(async () => {
  const userId = route.query.userId as string;
  if (!userId) {
    error.value = 'Missing user ID. Please open this page from the app.';
    loading.value = false;
    return;
  }

  try {
    const res = await $fetch<any>('/api/subscribe/create', {
      method: 'POST',
      body: { userId },
    });

    if (res.alreadyActive) {
      alreadyActive.value = true;
    } else {
      subData.value = res;
    }
  } catch (e: any) {
    error.value = e.data?.message || 'Failed to load subscription. Please try again.';
  } finally {
    loading.value = false;
  }
});

function openRazorpay() {
  if (!subData.value || !(window as any).Razorpay) {
    error.value = 'Payment system not loaded. Please refresh the page.';
    return;
  }

  paying.value = true;

  const options = {
    key: config.public.razorpayKeyId,
    subscription_id: subData.value.subscriptionId,
    name: 'Aravind Study Materials',
    description: 'Monthly Subscription',
    prefill: {
      name: subData.value.userName,
      email: subData.value.userEmail,
      contact: subData.value.userPhone,
    },
    theme: { color: '#059669' },
    handler: (_response: any) => {
      // Payment success — webhook will handle the rest
      paymentDone.value = true;
      paying.value = false;
    },
    modal: {
      ondismiss: () => {
        paying.value = false;
      },
    },
  };

  const rzp = new (window as any).Razorpay(options);
  rzp.on('payment.failed', (response: any) => {
    paying.value = false;
    error.value = response.error?.description || 'Payment failed. Please try again.';
  });
  rzp.open();
}
</script>

<style scoped>
.subscribe-page {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: var(--space-6);
  background: var(--color-bg-root);
}

.subscribe-container {
  width: 100%;
  max-width: 440px;
}

/* Brand */
.subscribe-brand {
  text-align: center;
  margin-bottom: var(--space-7);
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

.subscribe-brand h1 {
  font-size: 1.75rem;
  font-weight: 700;
  letter-spacing: -0.03em;
  margin-bottom: 4px;
}

.subscribe-brand p {
  font-size: 0.9375rem;
  color: var(--color-text-tertiary);
}

/* Plan Card */
.plan-card {
  background: var(--color-bg-surface);
  border: 1px solid var(--color-border-subtle);
  border-radius: var(--radius-xl);
  padding: var(--space-8);
  text-align: center;
}

.plan-header {
  margin-bottom: var(--space-4);
}

.plan-badge {
  display: inline-block;
  padding: 4px 14px;
  background: var(--color-accent-subtle);
  color: var(--color-accent);
  border-radius: var(--radius-full);
  font-size: 0.75rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

.plan-price {
  margin-bottom: var(--space-6);
}

.price-amount {
  font-size: 3rem;
  font-weight: 700;
  letter-spacing: -0.04em;
  color: var(--color-text-primary);
}

.price-period {
  font-size: 1rem;
  color: var(--color-text-tertiary);
  font-weight: 400;
}

.plan-features {
  list-style: none;
  padding: 0;
  text-align: left;
  margin-bottom: var(--space-7);
}

.plan-features li {
  display: flex;
  align-items: center;
  gap: var(--space-3);
  padding: var(--space-3) 0;
  border-bottom: 1px solid var(--color-border-subtle);
  font-size: 0.875rem;
  color: var(--color-text-secondary);
}

.plan-features li:last-child {
  border-bottom: none;
}

.check-icon {
  color: var(--color-accent);
  flex-shrink: 0;
}

.subscribe-btn {
  width: 100%;
  padding: 14px 24px;
  font-size: 1rem;
  font-weight: 700;
  background: var(--color-accent);
  color: white;
  border: none;
  border-radius: var(--radius-lg);
  cursor: pointer;
  transition: all var(--transition-fast);
}

.subscribe-btn:hover {
  background: var(--color-accent-hover);
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
}

.subscribe-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
  transform: none;
  box-shadow: none;
}

.plan-footer {
  margin-top: var(--space-4);
  font-size: 0.6875rem;
  color: var(--color-text-muted);
}

/* State Cards */
.state-card {
  text-align: center;
  padding: var(--space-10) var(--space-6);
}

.state-shimmer {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  margin: 0 auto var(--space-5);
}

.state-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 56px;
  height: 56px;
  border-radius: 50%;
  margin-bottom: var(--space-5);
}

.success-icon {
  background: var(--color-success-subtle);
  color: var(--color-success);
}

.error-icon {
  background: var(--color-danger-subtle);
  color: var(--color-danger);
}

.state-card h2 {
  font-size: 1.5rem;
  margin-bottom: var(--space-3);
}

.state-card h3 {
  font-size: 1.125rem;
  color: var(--color-danger);
  margin-bottom: var(--space-3);
}

.state-subtitle {
  font-size: 1.0625rem;
  color: var(--color-text-secondary);
  margin-bottom: var(--space-2);
}

.state-text {
  font-size: 0.875rem;
  color: var(--color-text-tertiary);
}
</style>
