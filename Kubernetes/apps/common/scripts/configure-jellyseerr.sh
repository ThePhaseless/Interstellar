#!/bin/bash
# =============================================================================
# Configure Jellyseerr with Jellyfin, Sonarr, and Radarr
# =============================================================================
# This script runs as a sidecar and waits for Jellyseerr to be ready,
# then configures the media servers via API.
# Usage: configure-jellyseerr.sh

set -e

JELLYSEERR_URL="http://localhost:5055"

# Wait for Jellyseerr to be ready
echo "Waiting for Jellyseerr to be ready..."
timeout=300
while ! curl -s "${JELLYSEERR_URL}/api/v1/status" > /dev/null 2>&1 && [ $timeout -gt 0 ]; do
  sleep 5
  timeout=$((timeout - 5))
done

if [ $timeout -le 0 ]; then
  echo "Error: Jellyseerr not ready after waiting"
  exit 1
fi

echo "Jellyseerr is ready"

# Check if already initialized
STATUS=$(curl -s "${JELLYSEERR_URL}/api/v1/status")
INITIALIZED=$(echo "$STATUS" | grep -o '"initialized":[^,}]*' | cut -d: -f2 || echo "false")

if [ "$INITIALIZED" = "true" ]; then
  echo "Jellyseerr already initialized, checking configurations..."
else
  echo "Jellyseerr not initialized - requires manual setup via UI first"
  echo "Please complete initial setup at https://jellyseerr.nerine.dev"
  exit 0
fi

# Configure Jellyfin if not already configured
echo "Checking Jellyfin configuration..."
JELLYFIN_SETTINGS=$(curl -s "${JELLYSEERR_URL}/api/v1/settings/jellyfin")
JELLYFIN_HOST=$(echo "$JELLYFIN_SETTINGS" | grep -o '"hostname":"[^"]*"' | cut -d'"' -f4 || echo "")

if [ -z "$JELLYFIN_HOST" ] || [ "$JELLYFIN_HOST" = "" ]; then
  echo "Configuring Jellyfin..."
  curl -s -X POST "${JELLYSEERR_URL}/api/v1/settings/jellyfin" \
    -H "Content-Type: application/json" \
    -d '{
      "hostname": "jellyfin.media.svc.cluster.local",
      "port": 8096,
      "useSsl": false,
      "urlBase": "",
      "externalHostname": "https://watch.nerine.dev"
    }' || echo "Failed to configure Jellyfin"
else
  echo "Jellyfin already configured: $JELLYFIN_HOST"
fi

# Configure Radarr
echo "Checking Radarr configuration..."
RADARR_SERVERS=$(curl -s "${JELLYSEERR_URL}/api/v1/settings/radarr")
RADARR_COUNT=$(echo "$RADARR_SERVERS" | grep -c '"id":' || echo "0")

if [ "$RADARR_COUNT" = "0" ]; then
  echo "Configuring Radarr..."

  # Get Radarr API key from secret
  RADARR_API_KEY="${RADARR_API_KEY:-}"
  if [ -z "$RADARR_API_KEY" ]; then
    echo "Warning: RADARR_API_KEY not set, skipping Radarr configuration"
  else
    # Get quality profiles from Radarr
    RADARR_URL="http://radarr.media.svc.cluster.local:7878"
    PROFILES=$(curl -s "${RADARR_URL}/api/v3/qualityprofile" -H "X-Api-Key: ${RADARR_API_KEY}")
    PROFILE_ID=$(echo "$PROFILES" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2 || echo "1")

    # Get root folders
    FOLDERS=$(curl -s "${RADARR_URL}/api/v3/rootfolder" -H "X-Api-Key: ${RADARR_API_KEY}")
    ROOT_FOLDER=$(echo "$FOLDERS" | grep -o '"path":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "/movies")

    curl -s -X POST "${JELLYSEERR_URL}/api/v1/settings/radarr" \
      -H "Content-Type: application/json" \
      -d '{
        "name": "Radarr",
        "hostname": "radarr.media.svc.cluster.local",
        "port": 7878,
        "apiKey": "'"${RADARR_API_KEY}"'",
        "useSsl": false,
        "baseUrl": "",
        "activeProfileId": '"${PROFILE_ID}"',
        "activeProfileName": "HD-1080p",
        "activeDirectory": "'"${ROOT_FOLDER}"'",
        "is4k": false,
        "minimumAvailability": "released",
        "isDefault": true,
        "externalUrl": "https://radarr.nerine.dev",
        "syncEnabled": true,
        "preventSearch": false
      }' || echo "Failed to configure Radarr"
  fi
else
  echo "Radarr already configured"
fi

# Configure Sonarr
echo "Checking Sonarr configuration..."
SONARR_SERVERS=$(curl -s "${JELLYSEERR_URL}/api/v1/settings/sonarr")
SONARR_COUNT=$(echo "$SONARR_SERVERS" | grep -c '"id":' || echo "0")

if [ "$SONARR_COUNT" = "0" ]; then
  echo "Configuring Sonarr..."

  # Get Sonarr API key from secret
  SONARR_API_KEY="${SONARR_API_KEY:-}"
  if [ -z "$SONARR_API_KEY" ]; then
    echo "Warning: SONARR_API_KEY not set, skipping Sonarr configuration"
  else
    # Get quality profiles from Sonarr
    SONARR_URL="http://sonarr.media.svc.cluster.local:8989"
    PROFILES=$(curl -s "${SONARR_URL}/api/v3/qualityprofile" -H "X-Api-Key: ${SONARR_API_KEY}")
    PROFILE_ID=$(echo "$PROFILES" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2 || echo "1")

    # Get root folders
    FOLDERS=$(curl -s "${SONARR_URL}/api/v3/rootfolder" -H "X-Api-Key: ${SONARR_API_KEY}")
    ROOT_FOLDER=$(echo "$FOLDERS" | grep -o '"path":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "/tv")

    curl -s -X POST "${JELLYSEERR_URL}/api/v1/settings/sonarr" \
      -H "Content-Type: application/json" \
      -d '{
        "name": "Sonarr",
        "hostname": "sonarr.media.svc.cluster.local",
        "port": 8989,
        "apiKey": "'"${SONARR_API_KEY}"'",
        "useSsl": false,
        "baseUrl": "",
        "activeProfileId": '"${PROFILE_ID}"',
        "activeProfileName": "HD-1080p",
        "activeDirectory": "'"${ROOT_FOLDER}"'",
        "activeLanguageProfileId": 1,
        "activeAnimeProfileId": null,
        "activeAnimeDirectory": null,
        "activeAnimeLanguageProfileId": null,
        "is4k": false,
        "isDefault": true,
        "enableSeasonFolders": true,
        "externalUrl": "https://sonarr.nerine.dev",
        "syncEnabled": true,
        "preventSearch": false
      }' || echo "Failed to configure Sonarr"
  fi
else
  echo "Sonarr already configured"
fi

echo "Jellyseerr configuration complete!"

# Keep running to maintain sidecar (check periodically)
while true; do
  sleep 3600  # Check every hour
  echo "Configuration check completed at $(date)"
done
