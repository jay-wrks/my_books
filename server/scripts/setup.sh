#!/bin/bash
# ============================================================================
# EC2 FIRST-TIME SETUP SCRIPT
# Run: chmod +x scripts/setup.sh && sudo ./scripts/setup.sh
# ============================================================================

set -e

echo "=== Aravind Server Setup ==="

# Update system
apt-get update && apt-get upgrade -y

# Install Node.js 20 LTS
if ! command -v node &> /dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
fi
echo "Node: $(node -v)"

# Install PM2 globally
npm install -g pm2

# Install Nginx
apt-get install -y nginx

# Install Certbot for SSL
apt-get install -y certbot python3-certbot-nginx

# Install build tools for better-sqlite3
apt-get install -y build-essential python3

# Create data directory
mkdir -p /home/ubuntu/aravind/data

# Install dependencies
cd /home/ubuntu/aravind/server
npm install

# Build WS-API
cd ws-api && npx tsc -p tsconfig.json && cd ..

# Build Nuxt admin
npx nuxt build

echo ""
echo "=== Setup complete! ==="
echo ""
echo "Next steps:"
echo "1. Copy .env.example to .env and fill in values"
echo "2. Place firebase-service-account.json in server/"
echo "3. Run: pm2 start ecosystem.config.cjs"
echo "4. Configure Nginx: sudo cp scripts/nginx.conf /etc/nginx/sites-available/aravind"
echo "5. sudo ln -sf /etc/nginx/sites-available/aravind /etc/nginx/sites-enabled/aravind"
echo "6. sudo rm -f /etc/nginx/sites-enabled/default"
echo "7. sudo certbot --nginx -d yourdomain.com"
echo "8. sudo systemctl restart nginx"
echo "9. pm2 save && pm2 startup"
