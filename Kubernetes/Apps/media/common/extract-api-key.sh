#!/bin/bash
set -e

# Wait for the application to start and generate config.xml
echo "Waiting for $APP_NAME to start and generate config..."
while [ ! -f /config/config.xml ]; do
    echo "Config file not found, waiting..."
    sleep 5
done

# Wait a bit more to ensure the API key is generated
sleep 10

# Extract API key from config.xml
echo "Extracting API key from $APP_NAME config..."
API_KEY=$(grep -oP '<ApiKey>\K[^<]+' /config/config.xml || echo "")

if [ -z "$API_KEY" ]; then
    echo "No API key found in config.xml, retrying..."
    exit 1
fi

echo "Found API key for $APP_NAME: $API_KEY"

# Create or update the secret
APP_NAME_LOWER=$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]')
kubectl create secret generic "${APP_NAME_LOWER}-api-key" \
    --from-literal=api-key="$API_KEY" \
    --dry-run=client -o yaml | kubectl apply -f -

echo "API key saved to secret ${APP_NAME_LOWER}-api-key"
