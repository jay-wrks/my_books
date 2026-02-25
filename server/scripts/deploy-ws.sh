#!/bin/bash
# ============================================================================
# DEPLOY WS-API — called by admin UI deploy button
# Only rebuilds and restarts the WebSocket API server, NOT the admin UI
# ============================================================================

set -e
cd "$(dirname "$0")/.."

BRANCH=${1:-main}
echo "=== Deploying ws-api (branch: $BRANCH) ==="

# Pull latest code
git fetch origin
git checkout "$BRANCH"
git pull origin "$BRANCH"

# Rebuild ws-api only
cd ws-api
npm install --production 2>&1
npx tsc -p tsconfig.json 2>&1
cd ..

# Restart ws-api process only (admin stays up)
pm2 restart ws-api 2>&1 || echo "PM2 restart skipped (not running?)"

echo "=== Deploy complete ==="
