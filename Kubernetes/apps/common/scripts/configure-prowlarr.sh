#!/bin/bash
# =============================================================================
# Configure Prowlarr with Sonarr/Radarr Applications
# =============================================================================
# Usage: configure-prowlarr.sh

PROWLARR_URL="http://prowlarr.media.svc.cluster.local:9696"

# Get API keys from secret
PROWLARR_API_KEY=$(cat /etc/arr-secrets/prowlarr-api-key)
SONARR_API_KEY=$(cat /etc/arr-secrets/sonarr-api-key)
RADARR_API_KEY=$(cat /etc/arr-secrets/radarr-api-key)

if [ -z "$PROWLARR_API_KEY" ]; then
  echo "Error: Prowlarr API key not found"
  exit 1
fi

echo "Configuring Prowlarr applications..."

# Add Sonarr
if [ -n "$SONARR_API_KEY" ]; then
  EXISTING=$(curl -s -X GET "${PROWLARR_URL}/api/v1/applications" \
    -H "X-Api-Key: ${PROWLARR_API_KEY}" | grep -c "Sonarr" || echo "0")

  if [ "$EXISTING" = "0" ]; then
    curl -s -X POST "${PROWLARR_URL}/api/v1/applications" \
      -H "X-Api-Key: ${PROWLARR_API_KEY}" \
      -H "Content-Type: application/json" \
      -d '{
        "syncLevel": "fullSync",
        "name": "Sonarr",
        "fields": [
          {"name": "prowlarrUrl", "value": "'${PROWLARR_URL}'"},
          {"name": "baseUrl", "value": "http://sonarr.media.svc.cluster.local:8989"},
          {"name": "apiKey", "value": "'${SONARR_API_KEY}'"},
          {"name": "syncCategories", "value": [5000, 5010, 5020, 5030, 5040, 5045, 5050]}
        ],
        "implementationName": "Sonarr",
        "implementation": "Sonarr",
        "configContract": "SonarrSettings",
        "tags": []
      }'
    echo "Added Sonarr to Prowlarr"
  else
    echo "Sonarr already configured in Prowlarr"
  fi
fi

# Add Radarr
if [ -n "$RADARR_API_KEY" ]; then
  EXISTING=$(curl -s -X GET "${PROWLARR_URL}/api/v1/applications" \
    -H "X-Api-Key: ${PROWLARR_API_KEY}" | grep -c "Radarr" || echo "0")

  if [ "$EXISTING" = "0" ]; then
    curl -s -X POST "${PROWLARR_URL}/api/v1/applications" \
      -H "X-Api-Key: ${PROWLARR_API_KEY}" \
      -H "Content-Type: application/json" \
      -d '{
        "syncLevel": "fullSync",
        "name": "Radarr",
        "fields": [
          {"name": "prowlarrUrl", "value": "'${PROWLARR_URL}'"},
          {"name": "baseUrl", "value": "http://radarr.media.svc.cluster.local:7878"},
          {"name": "apiKey", "value": "'${RADARR_API_KEY}'"},
          {"name": "syncCategories", "value": [2000, 2010, 2020, 2030, 2040, 2045, 2050, 2060]}
        ],
        "implementationName": "Radarr",
        "implementation": "Radarr",
        "configContract": "RadarrSettings",
        "tags": []
      }'
    echo "Added Radarr to Prowlarr"
  else
    echo "Radarr already configured in Prowlarr"
  fi
fi

echo "Prowlarr configuration complete"
