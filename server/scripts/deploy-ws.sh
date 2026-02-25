#!/bin/bash
# ============================================================================
# DEPLOY SCRIPT — Full deploy from main (or rollback to deploy_* branch)
# Called by admin UI, or manually: ./scripts/deploy-ws.sh [branch]
# Clones to temp, builds everything, stops PM2, copies artifacts, restarts PM2
# ============================================================================

set -e
cd "$(dirname "$0")/.."

BRANCH=${1:-main}
TEMP_DIR="$(pwd)/_deploy_temp"
ORIGIN_URL=$(git remote get-url origin)

echo "=== Deploy (branch: $BRANCH) ==="

# Cleanup leftover temp
rm -rf "$TEMP_DIR"

# 1. Shallow clone
echo "--- Cloning $BRANCH ---"
git clone --depth 1 --branch "$BRANCH" "$ORIGIN_URL" "$TEMP_DIR"

# 2. Build in temp
echo "--- Installing dependencies ---"
cd "$TEMP_DIR"
npm install

echo "--- Building Nuxt admin UI ---"
npx nuxt build

echo "--- Building WS-API ---"
npx tsc -p ws-api/tsconfig.json

cd "$(dirname "$0")/.."

# 3. Stop PM2
echo "--- Stopping PM2 processes ---"
pm2 stop admin-ui ws-api 2>&1 || echo "PM2 stop: some may not be running"

# 4. Copy built artifacts (keep data/, .env, node_modules)
echo "--- Copying artifacts ---"
rm -rf .output && cp -r "$TEMP_DIR/.output" .output
rm -rf ws-api/dist && cp -r "$TEMP_DIR/ws-api/dist" ws-api/dist
cp -r "$TEMP_DIR/shared" ./
cp -r "$TEMP_DIR/server" ./
cp "$TEMP_DIR/ws-api/index.ts" ws-api/
cp -f "$TEMP_DIR/package.json" ./
cp -f "$TEMP_DIR/ecosystem.config.cjs" ./
cp -f "$TEMP_DIR/nuxt.config.ts" ./

# 5. Reinstall prod deps
npm install --production

# 6. Start PM2
echo "--- Starting PM2 processes ---"
pm2 start ecosystem.config.cjs

# 7. Create deploy branch if deploying from main
if [ "$BRANCH" = "main" ]; then
  DATE_STR=$(date +%Y_%m_%d)
  SEQ=$(git branch -r --format="%(refname:short)" | grep "origin/deploy_${DATE_STR}_" | wc -l)
  SEQ=$((SEQ + 1))
  DEPLOY_BRANCH="deploy_${DATE_STR}_${SEQ}"
  echo "--- Creating deploy branch: $DEPLOY_BRANCH ---"
  cd "$TEMP_DIR"
  git checkout -b "$DEPLOY_BRANCH"
  git push origin "$DEPLOY_BRANCH"
  cd "$(dirname "$0")/.."
  echo "Created branch: $DEPLOY_BRANCH"
fi

# 8. Cleanup
rm -rf "$TEMP_DIR"

echo "=== Deploy complete ==="
