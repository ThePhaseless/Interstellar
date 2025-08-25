#!/bin/bash
set -e

NAMESPACE=${NAMESPACE:-media}
TIMEOUT=${TIMEOUT:-300}  # 5 minutes default timeout
CHECK_INTERVAL=${CHECK_INTERVAL:-10}  # Check every 10 seconds

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

validate_secret() {
    local secret_name=$1
    local key_name=$2
    
    log "Checking secret: $secret_name, key: $key_name"
    
    # Check if secret exists
    if ! kubectl get secret "$secret_name" -n "$NAMESPACE" >/dev/null 2>&1; then
        log "Secret $secret_name does not exist"
        return 1
    fi
    
    # Get the secret value
    local secret_value
    secret_value=$(kubectl get secret "$secret_name" -n "$NAMESPACE" -o jsonpath="{.data.$key_name}" 2>/dev/null | base64 -d 2>/dev/null)
    
    if [ -z "$secret_value" ]; then
        log "Secret $secret_name key $key_name is empty"
        return 1
    fi
    
    # Check if value is still placeholder or invalid
    case "$secret_value" in
        "placeholder"|""|"PLACEHOLDER"|"TODO"|"CHANGEME")
            log "Secret $secret_name key $key_name contains placeholder value: $secret_value"
            return 1
            ;;
        *)
            # Check if it looks like a valid API key (at least 8 characters, alphanumeric)
            if [[ ${#secret_value} -lt 8 ]]; then
                log "Secret $secret_name key $key_name is too short (${#secret_value} chars)"
                return 1
            fi
            
            if [[ ! "$secret_value" =~ ^[a-zA-Z0-9]+$ ]]; then
                log "Secret $secret_name key $key_name contains invalid characters"
                return 1
            fi
            
            log "Secret $secret_name key $key_name is valid"
            return 0
            ;;
    esac
}

wait_for_secrets() {
    local secrets=("$@")
    local start_time=$(date +%s)
    
    log "Starting secret validation for: ${secrets[*]}"
    log "Timeout: ${TIMEOUT}s, Check interval: ${CHECK_INTERVAL}s"
    
    while true; do
        local all_valid=true
        
        for secret_spec in "${secrets[@]}"; do
            local secret_name=$(echo "$secret_spec" | cut -d: -f1)
            local key_name=$(echo "$secret_spec" | cut -d: -f2)
            
            if ! validate_secret "$secret_name" "$key_name"; then
                all_valid=false
                break
            fi
        done
        
        if [ "$all_valid" = true ]; then
            log "All secrets are valid! Proceeding..."
            return 0
        fi
        
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [ $elapsed -ge $TIMEOUT ]; then
            log "Timeout reached (${TIMEOUT}s). Giving up..."
            return 1
        fi
        
        log "Waiting ${CHECK_INTERVAL}s before next check... (elapsed: ${elapsed}s)"
        sleep $CHECK_INTERVAL
    done
}

# Parse command line arguments
if [ $# -eq 0 ]; then
    log "Usage: $0 secret1:key1 [secret2:key2] ..."
    log "Example: $0 prowlarr-api-key:api-key sonarr-api-key:api-key"
    exit 1
fi

# Install kubectl if not available
if ! command -v kubectl >/dev/null 2>&1; then
    log "Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    mv kubectl /usr/local/bin/
fi

# Wait for secrets
wait_for_secrets "$@"