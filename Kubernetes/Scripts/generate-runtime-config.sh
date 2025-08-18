#!/bin/bash
set -e

echo "Waiting for API keys and generating config for $CONFIG_TYPE..."

# Install kubectl
apk add --no-cache curl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/

# Wait for API keys to be available
echo "Waiting for Sonarr and Radarr API keys..."
while ! kubectl get secret sonarr-api-key -n media > /dev/null 2>&1; do
    echo "Sonarr API key not ready, waiting..."
    sleep 10
done

while ! kubectl get secret radarr-api-key -n media > /dev/null 2>&1; do
    echo "Radarr API key not ready, waiting..."
    sleep 10
done

# Get API keys from secrets
SONARR_API_KEY=$(kubectl get secret sonarr-api-key -n media -o jsonpath='{.data.api-key}' | base64 -d)
RADARR_API_KEY=$(kubectl get secret radarr-api-key -n media -o jsonpath='{.data.api-key}' | base64 -d)

echo "Retrieved API keys, generating configs..."

if [ "$CONFIG_TYPE" = "decluttarr" ]; then
    # Process Decluttarr config
    sed "s/SONARR_API_KEY_PLACEHOLDER/$SONARR_API_KEY/g; s/RADARR_API_KEY_PLACEHOLDER/$RADARR_API_KEY/g" \
        /templates/config-template.yaml > /config/config.yaml
    echo "Decluttarr config generated successfully"
elif [ "$CONFIG_TYPE" = "recyclarr" ]; then
    # Process Recyclarr configs
    sed "s/SONARR_API_KEY_PLACEHOLDER/$SONARR_API_KEY/g" /templates/sonarr.yaml > /config/sonarr.yaml
    sed "s/RADARR_API_KEY_PLACEHOLDER/$RADARR_API_KEY/g" /templates/radarr.yaml > /config/radarr.yaml
    echo "Recyclarr configs generated successfully"
fi

echo "Config generation completed!"
