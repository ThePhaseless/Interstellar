#!/bin/bash
# =============================================================================
# Extract API Key from *arr config.xml
# =============================================================================
# Usage: extract-api-key.sh <app-name> <config-path>

set -euo pipefail

APP_NAME=${1:-}
CONFIG_PATH=${2:-}

if [ -z "$APP_NAME" ] || [ -z "$CONFIG_PATH" ]; then
  echo "Usage: $0 <app-name> <config-path>"
  exit 1
fi

# Clear any previous API key so it is never stale
kubectl patch secret arr-api-keys -n media \
  --type='json' \
  -p="[{\"op\": \"replace\", \"path\": \"/data/${APP_NAME}-api-key\", \"value\": \"\"}]" \
  >/dev/null 2>&1 || true

# Wait for config.xml to exist
echo "Waiting for $CONFIG_PATH to exist..."
timeout=300
while [ ! -f "$CONFIG_PATH" ] && [ $timeout -gt 0 ]; do
  sleep 5
  timeout=$((timeout - 5))
done

if [ ! -f "$CONFIG_PATH" ]; then
  echo "Error: $CONFIG_PATH not found after waiting"
  exit 1
fi

case "$APP_NAME" in
sonarr)
  APP_URL=${APP_URL:-"http://localhost:8989"}
  PING_PATH="/ping"
  STATUS_PATH="/api/v3/system/status"
  ;;
radarr)
  APP_URL=${APP_URL:-"http://localhost:7878"}
  PING_PATH="/ping"
  STATUS_PATH="/api/v3/system/status"
  ;;
prowlarr)
  APP_URL=${APP_URL:-"http://localhost:9696"}
  PING_PATH="/ping"
  STATUS_PATH="/api/v1/system/status"
  ;;
*)
  APP_URL=""
  PING_PATH=""
  STATUS_PATH=""
  ;;
esac

while true; do
  API_KEY=$(grep -oP '(?<=<ApiKey>)[^<]+' "$CONFIG_PATH" || echo "")

  if [ -z "$API_KEY" ]; then
    echo "Waiting for API key in $CONFIG_PATH..."
    sleep 5
    continue
  fi

  if [ -n "$APP_URL" ]; then
    if ! curl -fsS "${APP_URL}${PING_PATH}" >/dev/null 2>&1; then
      echo "Waiting for $APP_NAME API to be reachable..."
      sleep 5
      continue
    fi

    STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
      -H "X-Api-Key: ${API_KEY}" \
      "${APP_URL}${STATUS_PATH}" || echo "000")

    if [ "$STATUS_CODE" != "200" ]; then
      echo "Invalid API key for $APP_NAME (HTTP $STATUS_CODE), retrying..."
      kubectl patch secret arr-api-keys -n media \
        --type='json' \
        -p="[{\"op\": \"replace\", \"path\": \"/data/${APP_NAME}-api-key\", \"value\": \"\"}]" \
        >/dev/null 2>&1 || true
      sleep 10
      continue
    fi
  fi

  kubectl patch secret arr-api-keys -n media \
    --type='json' \
    -p="[{\"op\": \"replace\", \"path\": \"/data/${APP_NAME}-api-key\", \"value\": \"$(echo -n $API_KEY | base64)\"}]"

  echo "Updated arr-api-keys secret with $APP_NAME API key"
  exit 0
done
