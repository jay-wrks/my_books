<template>
  <div style="max-width:480px;margin:5vh auto;padding:2rem">
    <!-- Loading -->
    <div v-if="loading" style="text-align:center;padding:4rem 0">
      <h3>Loading...</h3>
    </div>

    <!-- Error -->
    <div v-else-if="error" style="text-align:center;padding:4rem 0">
      <h3 style="color:#f87171">{{ error }}</h3>
      <p style="color:#9ca3af;margin-top:1rem">Please go back to the app and try again.</p>
    </div>

    <!-- Already Active -->
    <div v-else-if="alreadyActive" style="text-align:center;padding:4rem 0">
      <h2 style="color:#10b981">✅ Already Subscribed!</h2>
      <p style="color:#9ca3af;margin-top:1rem">Your subscription is active. Go back to the app to access all PDFs.</p>
    </div>

    <!-- Payment Success -->
    <div v-else-if="paymentDone" style="text-align:center;padding:4rem 0">
      <h2 style="color:#10b981">🎉 Payment Successful!</h2>
      <p style="color:#d1d5db;margin-top:1rem;font-size:1.1rem">Your subscription is now active.</p>
      <p style="color:#9ca3af;margin-top:0.5rem">Go back to the <strong>Aravind app</strong> and refresh to access all study materials.</p>
    </div>

    <!-- Subscribe Form -->
    <div v-else>
      <div style="text-align:center;margin-bottom:2rem">
        <h1 style="color:#10b981;font-size:2rem">🎓 Aravind</h1>
        <p style="color:#9ca3af;margin-top:0.5rem">Unlock all study materials</p>
      </div>

      <div style="background:#111;border-radius:16px;padding:2rem;border:1px solid #222;text-align:center">
        <h2 style="margin-bottom:0.5rem">Monthly Plan</h2>
        <div style="font-size:2.5rem;font-weight:700;color:#10b981;margin:1rem 0">₹199<span style="font-size:1rem;color:#9ca3af">/month</span></div>

        <ul style="text-align:left;list-style:none;padding:0;margin:1.5rem 0">
          <li style="padding:0.5rem 0;border-bottom:1px solid #222">✅ Access all PDFs (Class 1-12)</li>
          <li style="padding:0.5rem 0;border-bottom:1px solid #222">✅ All subjects included</li>
          <li style="padding:0.5rem 0;border-bottom:1px solid #222">✅ New materials added weekly</li>
          <li style="padding:0.5rem 0;border-bottom:1px solid #222">✅ Read anywhere, anytime</li>
          <li style="padding:0.5rem 0">✅ Cancel anytime</li>
        </ul>

        <button @click="openRazorpay" :disabled="paying"
          style="width:100%;padding:1rem;font-size:1.1rem;font-weight:700;background:#059669;color:white;border:none;border-radius:12px;cursor:pointer">
          {{ paying ? 'Processing...' : 'Subscribe Now — ₹199/month' }}
        </button>

        <p style="color:#6b7280;font-size:0.75rem;margin-top:1rem">Powered by Razorpay. Secure payment.</p>
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
