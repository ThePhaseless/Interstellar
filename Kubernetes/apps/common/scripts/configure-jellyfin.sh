#!/bin/sh
# =============================================================================
# Automated Jellyfin Setup
# =============================================================================
# Completes the setup wizard, configures media libraries, and creates users
# from the VIP email list (passwordless accounts behind oauth2-proxy).
#
# Required environment variables:
#   JELLYFIN_ADMIN_USER     - Admin username (hardcoded to "admin")
#   JELLYFIN_ADMIN_PASSWORD - Admin password (from secret)
#
# Required files:
#   /secrets/vip-emails     - VIP email list (one per line)
# =============================================================================

JELLYFIN_URL="${JELLYFIN_URL:-http://localhost:8096}"
ADMIN_USER="${JELLYFIN_ADMIN_USER:-admin}"
ADMIN_PASSWORD="${JELLYFIN_ADMIN_PASSWORD:-}"
VIP_EMAILS_FILE="/secrets/vip-emails"

if [ -z "$ADMIN_PASSWORD" ]; then
  echo "Error: JELLYFIN_ADMIN_PASSWORD must be set"
  exit 1
fi

# Wait for Jellyfin to be ready
echo "Waiting for Jellyfin to be ready..."
timeout=300
while ! curl -sf "${JELLYFIN_URL}/health" > /dev/null 2>&1 && [ $timeout -gt 0 ]; do
  sleep 5
  timeout=$((timeout - 5))
done

if [ $timeout -le 0 ]; then
  echo "Error: Jellyfin not ready after waiting"
  exit 1
fi

echo "Jellyfin is ready"

# Check if setup wizard is already complete
PUBLIC_INFO=$(curl -s "${JELLYFIN_URL}/System/Info/Public" || echo "{}")
STARTUP_COMPLETE=$(echo "$PUBLIC_INFO" | grep -o '"StartupWizardCompleted":[^,}]*' | cut -d: -f2 || echo "false")

if [ "$STARTUP_COMPLETE" = "true" ]; then
  echo "Jellyfin setup already complete, skipping wizard"
else
  echo "Running Jellyfin setup wizard..."

  # Step 1: Set preferred language/culture
  curl -sf -X POST "${JELLYFIN_URL}/Startup/Configuration" \
    -H "Content-Type: application/json" \
    -d '{"UICulture":"en-US","MetadataCountryCode":"US","PreferredMetadataLanguage":"en"}' \
    || echo "Warning: Failed to set initial configuration"

  # Step 2: Get initial user info
  curl -sf "${JELLYFIN_URL}/Startup/User" > /dev/null 2>&1 || true

  # Step 3: Create admin user
  echo "Creating admin user '${ADMIN_USER}'..."
  curl -sf -X POST "${JELLYFIN_URL}/Startup/User" \
    -H "Content-Type: application/json" \
    -d "{\"Name\":\"${ADMIN_USER}\",\"Password\":\"${ADMIN_PASSWORD}\"}" \
    || echo "Warning: Failed to create admin user"

  # Step 4: Configure remote access
  curl -sf -X POST "${JELLYFIN_URL}/Startup/RemoteAccess" \
    -H "Content-Type: application/json" \
    -d '{"EnableRemoteAccess":true,"EnableAutomaticPortMapping":false}' \
    || echo "Warning: Failed to configure remote access"

  # Step 5: Complete the setup wizard
  curl -sf -X POST "${JELLYFIN_URL}/Startup/Complete" \
    || echo "Warning: Failed to complete wizard"

  echo "Setup wizard completed"
fi

# Authenticate to get API token
AUTH_HEADER="MediaBrowser Client=\"Setup\", Device=\"Script\", DeviceId=\"setup-sidecar\", Version=\"1.0\""
LOGIN_RESPONSE=$(curl -s -X POST "${JELLYFIN_URL}/Users/AuthenticateByName" \
  -H "Content-Type: application/json" \
  -H "X-Emby-Authorization: ${AUTH_HEADER}" \
  -d "{\"Username\":\"${ADMIN_USER}\",\"Pw\":\"${ADMIN_PASSWORD}\"}" || echo "")

TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"AccessToken":"[^"]*"' | cut -d'"' -f4 || echo "")

if [ -z "$TOKEN" ]; then
  echo "Warning: Failed to get auth token, skipping further configuration"
  exit 0
fi

AUTH="MediaBrowser Token=\"${TOKEN}\""

# --- Configure media libraries ---
LIBRARIES=$(curl -s "${JELLYFIN_URL}/Library/VirtualFolders" \
  -H "X-Emby-Authorization: ${AUTH}" || echo "[]")

if ! echo "$LIBRARIES" | grep -q '"Movies"'; then
  echo "Adding Movies library..."
  curl -sf -X POST "${JELLYFIN_URL}/Library/VirtualFolders?name=Movies&collectionType=movies&refreshLibrary=false" \
    -H "X-Emby-Authorization: ${AUTH}" \
    -H "Content-Type: application/json" \
    -d '{"LibraryOptions":{"EnableRealtimeMonitor":true,"EnablePhotos":false,"PathInfos":[{"Path":"/media/movies"}]}}' \
    || echo "Warning: Failed to add Movies library"
fi

if ! echo "$LIBRARIES" | grep -q '"TV Shows"'; then
  echo "Adding TV Shows library..."
  curl -sf -X POST "${JELLYFIN_URL}/Library/VirtualFolders?name=TV%20Shows&collectionType=tvshows&refreshLibrary=false" \
    -H "X-Emby-Authorization: ${AUTH}" \
    -H "Content-Type: application/json" \
    -d '{"LibraryOptions":{"EnableRealtimeMonitor":true,"EnablePhotos":false,"PathInfos":[{"Path":"/media/tv"}]}}' \
    || echo "Warning: Failed to add TV Shows library"
fi

# --- Create VIP users (passwordless, behind oauth2-proxy) ---
if [ -f "$VIP_EMAILS_FILE" ]; then
  echo "Creating VIP users from email list..."

  EXISTING_USERS=$(curl -s "${JELLYFIN_URL}/Users" \
    -H "X-Emby-Authorization: ${AUTH}" || echo "[]")

  while IFS= read -r email || [ -n "$email" ]; do
    # Trim whitespace, skip empty lines and comments
    email=$(echo "$email" | tr -d '[:space:]')
    [ -z "$email" ] && continue
    echo "$email" | grep -q '^#' && continue

    # Check if user already exists (use email as username)
    if echo "$EXISTING_USERS" | grep -q "\"${email}\""; then
      echo "User '${email}' already exists, skipping"
      continue
    fi

    echo "Creating user '${email}'..."
    CREATE_RESPONSE=$(curl -s -X POST "${JELLYFIN_URL}/Users/New" \
      -H "X-Emby-Authorization: ${AUTH}" \
      -H "Content-Type: application/json" \
      -d "{\"Name\":\"${email}\"}" || echo "")

    USER_ID=$(echo "$CREATE_RESPONSE" | grep -o '"Id":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "")

    if [ -n "$USER_ID" ]; then
      # Disable password (auth handled by oauth2-proxy)
      curl -s -X POST "${JELLYFIN_URL}/Users/${USER_ID}/Password" \
        -H "X-Emby-Authorization: ${AUTH}" \
        -H "Content-Type: application/json" \
        -d '{"ResetPassword":true}' > /dev/null 2>&1 || true

      # Set user policy: allow media playback, no admin
      curl -s -X POST "${JELLYFIN_URL}/Users/${USER_ID}/Policy" \
        -H "X-Emby-Authorization: ${AUTH}" \
        -H "Content-Type: application/json" \
        -d '{"IsAdministrator":false,"IsDisabled":false,"EnableAllFolders":true,"EnableMediaPlayback":true,"EnableAudioPlaybackTranscoding":true,"EnableVideoPlaybackTranscoding":true,"EnablePlaybackRemuxing":true,"EnableContentDownloading":true,"EnableRemoteAccess":true}' \
        > /dev/null 2>&1 || true

      echo "Created user '${email}' (no password)"
    else
      echo "Warning: Failed to create user '${email}'"
    fi
  done < "$VIP_EMAILS_FILE"
else
  echo "Warning: VIP emails file not found at ${VIP_EMAILS_FILE}, skipping user creation"
fi

echo "Jellyfin setup and configuration complete!"

# Keep sidecar alive to prevent restart loops
exec sleep infinity
