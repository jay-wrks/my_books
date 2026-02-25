// PM2 Ecosystem config — runs both processes
module.exports = {
  apps: [
    {
      name: 'admin-ui',
      script: '.output/server/index.mjs',
      cwd: __dirname,
      env: {
        PORT: 3000,
        NODE_ENV: 'production',
      },
      max_memory_restart: '300M',
      instances: 1,
    },
    {
      name: 'ws-api',
      script: 'ws-api/dist/ws-api/index.js',
      cwd: __dirname,
      env: {
        NODE_ENV: 'production',
      },
      max_memory_restart: '400M',
      instances: 1,
      // Auto-restart on crash
      autorestart: true,
      watch: false,
    },
  ],
};
