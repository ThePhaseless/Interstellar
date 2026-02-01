#!/bin/bash
# =============================================================================
# Extract API Key from *arr config.xml
# =============================================================================
# Usage: extract-api-key.sh <app-name> <config-path>

APP_NAME=$1
CONFIG_PATH=$2

if [ -z "$APP_NAME" ] || [ -z "$CONFIG_PATH" ]; then
  echo "Usage: $0 <app-name> <config-path>"
  exit 1
fi

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

# Extract API key
API_KEY=$(grep -oP '(?<=<ApiKey>)[^<]+' "$CONFIG_PATH" || echo "")

if [ -z "$API_KEY" ]; then
  echo "Error: Could not extract API key from $CONFIG_PATH"
  exit 1
fi

echo "Extracted API key for $APP_NAME"

# Update the arr-api-keys secret
kubectl patch secret arr-api-keys -n media \
  --type='json' \
  -p="[{\"op\": \"replace\", \"path\": \"/data/${APP_NAME}-api-key\", \"value\": \"$(echo -n $API_KEY | base64)\"}]"

echo "Updated arr-api-keys secret with $APP_NAME API key"
