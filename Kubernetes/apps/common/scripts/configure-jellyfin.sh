#!/bin/sh
# =============================================================================
# Automated Jellyfin Setup with Authentik SSO
# =============================================================================
# Completes the setup wizard, configures media libraries, installs and
# configures the 9p4 SSO plugin for Authentik OIDC authentication.
#
# Features:
#   - Automatic account creation on first SSO login
#   - Authentik as the ONLY login method (native login hidden)
#   - Group-based RBAC support via Authentik groups
#
# Required environment variables:
#   JELLYFIN_ADMIN_USER       - Admin username
#   JELLYFIN_ADMIN_PASSWORD   - Admin password (from secret)
#   JELLYFIN_DOMAIN           - Public domain (e.g., watch.nerine.dev)
#   AUTHENTIK_OIDC_ENDPOINT   - Authentik OIDC endpoint URL
#
# Required files:
#   /secrets/oidc-client-id     - OIDC client ID (from Bitwarden)
#   /secrets/oidc-client-secret - OIDC client secret (from Bitwarden)
# =============================================================================

JELLYFIN_URL="${JELLYFIN_URL:-http://localhost:8096}"
ADMIN_USER="${JELLYFIN_ADMIN_USER:-admin}"
ADMIN_PASSWORD="${JELLYFIN_ADMIN_PASSWORD:-}"
JELLYFIN_DOMAIN="${JELLYFIN_DOMAIN:-watch.nerine.dev}"
AUTHENTIK_OIDC_ENDPOINT="${AUTHENTIK_OIDC_ENDPOINT:-}"
OIDC_CLIENT_ID_FILE="/secrets/oidc-client-id"
OIDC_CLIENT_SECRET_FILE="/secrets/oidc-client-secret"
SSO_PLUGIN_REPO="https://raw.githubusercontent.com/9p4/jellyfin-plugin-sso/manifest-release/manifest.json"
SSO_PROVIDER_NAME="authentik"

if [ -z "$ADMIN_PASSWORD" ]; then
  echo "Error: JELLYFIN_ADMIN_PASSWORD must be set"
  exit 1
fi

# Read OIDC credentials from secret files
OIDC_CLIENT_ID=""
OIDC_CLIENT_SECRET=""
if [ -f "$OIDC_CLIENT_ID_FILE" ] && [ -f "$OIDC_CLIENT_SECRET_FILE" ]; then
  OIDC_CLIENT_ID=$(cat "$OIDC_CLIENT_ID_FILE")
  OIDC_CLIENT_SECRET=$(cat "$OIDC_CLIENT_SECRET_FILE")
fi

# --- Helper Functions ---

wait_for_jellyfin() {
  echo "Waiting for Jellyfin to be ready..."
  wait_timeout=300
  while ! curl -sf "${JELLYFIN_URL}/health" >/dev/null 2>&1 && [ $wait_timeout -gt 0 ]; do
    sleep 5
    wait_timeout=$((wait_timeout - 5))
  done
  if [ $wait_timeout -le 0 ]; then
    echo "Error: Jellyfin not ready after waiting"
    return 1
  fi
  echo "Jellyfin is ready"
  return 0
}

authenticate() {
  AUTH_HEADER="MediaBrowser Client=\"Setup\", Device=\"Script\", DeviceId=\"setup-sidecar\", Version=\"1.0\""
  LOGIN_RESPONSE=$(curl -s -X POST "${JELLYFIN_URL}/Users/AuthenticateByName" \
    -H "Content-Type: application/json" \
    -H "X-Emby-Authorization: ${AUTH_HEADER}" \
    -d "{\"Username\":\"${ADMIN_USER}\",\"Pw\":\"${ADMIN_PASSWORD}\"}" || echo "")
  TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"AccessToken":"[^"]*"' | cut -d'"' -f4 || echo "")
  if [ -z "$TOKEN" ]; then
    echo "Warning: Failed to get auth token"
    return 1
  fi
  AUTH="MediaBrowser Token=\"${TOKEN}\""
  return 0
}

# =============================================================================
# Phase 1: Setup Wizard
# =============================================================================

wait_for_jellyfin || exit 1

PUBLIC_INFO=$(curl -s "${JELLYFIN_URL}/System/Info/Public" || echo "{}")
STARTUP_COMPLETE=$(echo "$PUBLIC_INFO" | grep -o '"StartupWizardCompleted":[^,}]*' | cut -d: -f2 || echo "false")

if [ "$STARTUP_COMPLETE" = "true" ]; then
  echo "Jellyfin setup already complete, skipping wizard"
else
  echo "Running Jellyfin setup wizard..."
  curl -sf -X POST "${JELLYFIN_URL}/Startup/Configuration" \
    -H "Content-Type: application/json" \
    -d '{"UICulture":"en-US","MetadataCountryCode":"US","PreferredMetadataLanguage":"en"}' || true
  curl -sf "${JELLYFIN_URL}/Startup/User" >/dev/null 2>&1 || true
  echo "Creating admin user '${ADMIN_USER}'..."
  curl -sf -X POST "${JELLYFIN_URL}/Startup/User" \
    -H "Content-Type: application/json" \
    -d "{\"Name\":\"${ADMIN_USER}\",\"Password\":\"${ADMIN_PASSWORD}\"}" || true
  curl -sf -X POST "${JELLYFIN_URL}/Startup/RemoteAccess" \
    -H "Content-Type: application/json" \
    -d '{"EnableRemoteAccess":true,"EnableAutomaticPortMapping":false}' || true
  curl -sf -X POST "${JELLYFIN_URL}/Startup/Complete" || true
  echo "Setup wizard completed"
fi

# =============================================================================
# Phase 2: Authenticate & Configure Libraries
# =============================================================================

authenticate || { echo "Cannot authenticate, exiting"; exec sleep infinity; }

LIBRARIES=$(curl -s "${JELLYFIN_URL}/Library/VirtualFolders" \
  -H "X-Emby-Authorization: ${AUTH}" || echo "[]")

if ! echo "$LIBRARIES" | grep -q '"Movies"'; then
  echo "Adding Movies library..."
  curl -sf -X POST "${JELLYFIN_URL}/Library/VirtualFolders?name=Movies&collectionType=movies&refreshLibrary=false" \
    -H "X-Emby-Authorization: ${AUTH}" \
    -H "Content-Type: application/json" \
    -d '{"LibraryOptions":{"EnableRealtimeMonitor":true,"EnablePhotos":false,"PathInfos":[{"Path":"/media/movies"}]}}' || true
fi

if ! echo "$LIBRARIES" | grep -q '"TV Shows"'; then
  echo "Adding TV Shows library..."
  curl -sf -X POST "${JELLYFIN_URL}/Library/VirtualFolders?name=TV%20Shows&collectionType=tvshows&refreshLibrary=false" \
    -H "X-Emby-Authorization: ${AUTH}" \
    -H "Content-Type: application/json" \
    -d '{"LibraryOptions":{"EnableRealtimeMonitor":true,"EnablePhotos":false,"PathInfos":[{"Path":"/media/tv"}]}}' || true
fi

# =============================================================================
# Phase 3: Install SSO Plugin
# =============================================================================

if [ -z "$OIDC_CLIENT_ID" ] || [ -z "$OIDC_CLIENT_SECRET" ] || [ -z "$AUTHENTIK_OIDC_ENDPOINT" ]; then
  echo "Warning: OIDC credentials or endpoint not configured, skipping SSO setup"
  echo "  OIDC_CLIENT_ID set: $([ -n "$OIDC_CLIENT_ID" ] && echo yes || echo no)"
  echo "  OIDC_CLIENT_SECRET set: $([ -n "$OIDC_CLIENT_SECRET" ] && echo yes || echo no)"
  echo "  AUTHENTIK_OIDC_ENDPOINT: ${AUTHENTIK_OIDC_ENDPOINT:-not set}"
  echo "Jellyfin setup complete (without SSO)"
  exec sleep infinity
fi

# Check if SSO plugin is already active
SSO_CHECK=$(curl -s -o /dev/null -w "%{http_code}" \
  "${JELLYFIN_URL}/sso/OID/Get?api_key=${TOKEN}" 2>/dev/null || echo "000")

if [ "$SSO_CHECK" = "200" ]; then
  echo "SSO plugin already active, skipping installation"
else
  echo "SSO plugin not active (HTTP ${SSO_CHECK}), installing..."

  # Add SSO plugin repository
  REPOS=$(curl -s "${JELLYFIN_URL}/Repositories" \
    -H "X-Emby-Authorization: ${AUTH}" || echo "[]")

  if ! echo "$REPOS" | grep -q "jellyfin-plugin-sso"; then
    echo "Adding SSO plugin repository..."
    if [ "$REPOS" = "[]" ] || [ -z "$REPOS" ]; then
      NEW_REPOS="[{\"Name\":\"SSO-Auth\",\"Url\":\"${SSO_PLUGIN_REPO}\",\"Enabled\":true}]"
    else
      NEW_REPOS=$(echo "$REPOS" | sed "s|]$|,{\"Name\":\"SSO-Auth\",\"Url\":\"${SSO_PLUGIN_REPO}\",\"Enabled\":true}]|")
    fi
    curl -sf -X POST "${JELLYFIN_URL}/Repositories" \
      -H "X-Emby-Authorization: ${AUTH}" \
      -H "Content-Type: application/json" \
      -d "$NEW_REPOS" || echo "Warning: Failed to add SSO plugin repository"
  fi

  # Install the SSO-Auth plugin (package name is "SSO Authentication" in the manifest)
  echo "Installing SSO Authentication plugin package..."
  ENCODED_REPO=$(printf '%s' "$SSO_PLUGIN_REPO" | sed 's/:/%3A/g; s|/|%2F|g')
  curl -sf -X POST \
    "${JELLYFIN_URL}/Packages/Installed/SSO%20Authentication?repositoryUrl=${ENCODED_REPO}" \
    -H "X-Emby-Authorization: ${AUTH}" || echo "Warning: Failed to install SSO-Auth plugin"

  # Restart Jellyfin to activate the plugin
  echo "Restarting Jellyfin to activate SSO plugin..."
  curl -sf -X POST "${JELLYFIN_URL}/System/Restart" \
    -H "X-Emby-Authorization: ${AUTH}" || true

  # Wait for Jellyfin to go down and come back
  sleep 15
  wait_for_jellyfin || { echo "Error: Jellyfin failed to restart"; exec sleep infinity; }

  # Re-authenticate (old token invalidated by restart)
  sleep 5
  authenticate || { echo "Cannot re-authenticate after restart"; exec sleep infinity; }

  # Verify SSO plugin is now active
  retries=6
  while [ $retries -gt 0 ]; do
    SSO_VERIFY=$(curl -s -o /dev/null -w "%{http_code}" \
      "${JELLYFIN_URL}/sso/OID/Get?api_key=${TOKEN}" 2>/dev/null || echo "000")
    if [ "$SSO_VERIFY" = "200" ]; then
      echo "SSO plugin is active"
      break
    fi
    echo "SSO plugin not yet active (HTTP ${SSO_VERIFY}), retrying in 10s..."
    sleep 10
    retries=$((retries - 1))
  done

  if [ "$SSO_VERIFY" != "200" ]; then
    echo "Error: SSO plugin failed to activate after restart"
    exec sleep infinity
  fi
fi

# =============================================================================
# Phase 4: Configure SSO Provider (Authentik OIDC)
# =============================================================================

echo "Configuring SSO provider '${SSO_PROVIDER_NAME}'..."

# Build SSO config JSON — use printf to safely handle special characters
# schemeOverride=https: Traefik terminates TLS so the plugin sees http:// requests,
# but the browser loads pages via https://. Without the override, the callback page
# embeds an http:// iframe which is blocked as mixed content, causing "Logging in..." to hang.
printf '{"oidEndpoint":"%s","oidClientId":"%s","oidSecret":"%s","enabled":true,"enableAuthorization":true,"enableAllFolders":true,"enabledFolders":[],"adminRoles":[],"roles":[],"enableFolderRoles":false,"folderRoleMapping":[],"roleClaim":"groups","oidScopes":["groups"],"defaultProvider":"SSO-Auth-OpenID","defaultUsernameClaim":"preferred_username","schemeOverride":"https"}' \
  "$AUTHENTIK_OIDC_ENDPOINT" "$OIDC_CLIENT_ID" "$OIDC_CLIENT_SECRET" > /tmp/sso-config.json

curl -sf -X POST \
  "${JELLYFIN_URL}/sso/OID/Add/${SSO_PROVIDER_NAME}?api_key=${TOKEN}" \
  -H "Content-Type: application/json" \
  -d @/tmp/sso-config.json || echo "Warning: Failed to configure SSO provider"
rm -f /tmp/sso-config.json

echo "SSO provider '${SSO_PROVIDER_NAME}' configured"

# =============================================================================
# Phase 5: Configure Branding (SSO Login Button)
# =============================================================================

echo "Configuring login branding (SSO-only login)..."

# Login disclaimer: SSO button replaces the native login form
# Custom CSS: hides native username/password fields, shows only SSO button
curl -sf -X POST "${JELLYFIN_URL}/System/Configuration/branding" \
  -H "X-Emby-Authorization: ${AUTH}" \
  -H "Content-Type: application/json" \
  -d '{"LoginDisclaimer":"<form action=\"/sso/OID/start/authentik\"><button class=\"raised block emby-button button-submit\">Sign in with Authentik</button></form>","CustomCss":"a.raised.emby-button{padding:.9em 1em;color:inherit!important}.disclaimerContainer{display:block}#loginPage .manualLoginForm .inputContainer,#loginPage .manualLoginForm .button-submit,#loginPage .manualLoginForm .checkboxContainer{display:none!important}"}' \
  || echo "Warning: Failed to configure branding"

echo "Login branding configured — SSO is now the only visible login method"

# =============================================================================
# Done
# =============================================================================

echo "Jellyfin setup with Authentik SSO complete!"
echo "  Domain: https://${JELLYFIN_DOMAIN}"
echo "  OIDC Endpoint: ${AUTHENTIK_OIDC_ENDPOINT}"
echo "  Provider: ${SSO_PROVIDER_NAME}"
echo "  Auto-create accounts: enabled"
echo "  Default auth provider: SSO-Auth-OpenID"

# Keep sidecar alive to prevent restart loops
exec sleep infinity
