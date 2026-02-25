#!/bin/bash
# Start both servers — Ctrl+C kills both
cd "$(dirname "$0")/.."

echo "=== Starting Admin UI (port 3000) + WS-API (port ${WS_PORT:-3001}) ==="

# Start admin UI in background
node .output/server/index.mjs &
PID_ADMIN=$!

# Start ws-api in background
node ws-api/dist/ws-api/index.js &
PID_WS=$!

echo "[Admin UI] PID=$PID_ADMIN"
echo "[WS-API]   PID=$PID_WS"

# Ctrl+C kills both
trap "echo ''; echo 'Stopping...'; kill $PID_ADMIN $PID_WS 2>/dev/null; wait; echo 'Done.'; exit 0" INT TERM

# Wait for either to exit
wait
