#!/bin/bash
set -e

# Install kubectl
echo "Installing kubectl..."
apk add --no-cache curl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/

echo "Configuring Prowlarr indexers..."

# Wait for Prowlarr to be ready
echo "Waiting for Prowlarr to be available..."
while ! curl -s http://prowlarr:9696/api/v1/health >/dev/null; do
    echo "Prowlarr not ready, waiting..."
    sleep 10
done

# Wait for API keys to be available
echo "Waiting for Sonarr and Radarr API keys..."
while ! kubectl get secret sonarr-api-key -n media >/dev/null 2>&1; do
    echo "Sonarr API key not ready, waiting..."
    sleep 10
done

while ! kubectl get secret radarr-api-key -n media >/dev/null 2>&1; do
    echo "Radarr API key not ready, waiting..."
    sleep 10
done

# Get API keys from secrets
SONARR_API_KEY=$(kubectl get secret sonarr-api-key -n media -o jsonpath='{.data.api-key}' | base64 -d)
RADARR_API_KEY=$(kubectl get secret radarr-api-key -n media -o jsonpath='{.data.api-key}' | base64 -d)

# Wait for Prowlarr API key to be available
while [ -z "$PROWLARR_API_KEY" ]; do
    echo "Prowlarr API key not ready, waiting..."
    sleep 10
    PROWLARR_API_KEY=$(kubectl get secret prowlarr-api-key -n media -o jsonpath='{.data.api-key}' 2>/dev/null | base64 -d || echo "")
done

echo "Adding Sonarr to Prowlarr..."
curl -X POST "http://prowlarr:9696/api/v1/applications" \
    -H "X-Api-Key: $PROWLARR_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{
        "name": "Sonarr",
        "implementation": "Sonarr",
        "configContract": "SonarrSettings",
        "fields": [
            {"name": "baseUrl", "value": "http://sonarr:8989"},
            {"name": "apiKey", "value": "'$SONARR_API_KEY'"},
            {"name": "syncLevel", "value": "fullSync"}
        ],
        "tags": []
    }'

echo "Adding Radarr to Prowlarr..."
curl -X POST "http://prowlarr:9696/api/v1/applications" \
    -H "X-Api-Key: $PROWLARR_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{
        "name": "Radarr",
        "implementation": "Radarr",
        "configContract": "RadarrSettings",
        "fields": [
            {"name": "baseUrl", "value": "http://radarr:7878"},
            {"name": "apiKey", "value": "'$RADARR_API_KEY'"},
            {"name": "syncLevel", "value": "fullSync"}
        ],
        "tags": []
    }'

echo "Prowlarr configuration completed!"
