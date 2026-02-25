export default defineNuxtConfig({
  ssr: false, // Full SPA — minimal memory on EC2

  runtimeConfig: {
    jwtSecret: process.env.JWT_SECRET,
    adminEmail: process.env.ADMIN_EMAIL,
    adminPassword: process.env.ADMIN_PASSWORD,
    razorpayKeyId: process.env.RAZORPAY_KEY_ID,
    razorpayKeySecret: process.env.RAZORPAY_KEY_SECRET,
    razorpayPlanId: process.env.RAZORPAY_PLAN_ID,
    razorpayWebhookSecret: process.env.RAZORPAY_WEBHOOK_SECRET,
    wsPort: process.env.WS_PORT || '3001',
    public: {
      razorpayKeyId: process.env.RAZORPAY_KEY_ID,
      domain: process.env.DOMAIN || 'localhost:3000',
    },
  },

  app: {
    head: {
      title: 'Aravind Admin',
      meta: [{ name: 'viewport', content: 'width=device-width, initial-scale=1' }],
      link: [
        { rel: 'stylesheet', href: 'https://cdn.jsdelivr.net/npm/@picocss/pico@2/css/pico.min.css' },
      ],
      script: [
        { src: 'https://checkout.razorpay.com/v1/checkout.js', defer: true },
      ],
    },
  },

  compatibilityDate: '2025-01-01',

  vite: {
    server: {
      watch: {
        ignored: ['**/ws-api/**', '**/shared/**', '**/data/**', '**/scripts/**'],
      },
    },
  },
});
