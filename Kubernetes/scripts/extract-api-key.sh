#!/bin/bash

# Configuration via environment variables
APP_NAME=${APP_NAME:-"Unknown"}
CONFIG_FILE=${CONFIG_FILE:-"/config/config.xml"}
SECRET_NAME=${SECRET_NAME:-"${APP_NAME,,}-api-key"}
CHECK_INTERVAL=${CHECK_INTERVAL:-30}
XML_PATH=${XML_PATH:-"//ApiKey"}
OUTPUT_TYPE=${OUTPUT_TYPE:-"secret"}
NAMESPACE=${NAMESPACE:-$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)}

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$APP_NAME] $1"
}

# Install required packages
install_dependencies() {
    log "Installing dependencies..."
    if apk add --no-cache xmlstarlet kubectl >/dev/null 2>&1; then
        log "Dependencies installed successfully"
    else
        log "ERROR: Failed to install dependencies"
        exit 1
    fi
}

# Extract API key from XML
extract_api_key() {
    local config_file=$1
    local xml_path=$2

    if [ ! -f "$config_file" ]; then
        log "Config file not found: $config_file"
        return 1
    fi

    # Try multiple extraction methods
    local api_key=""

    # Method 1: xmlstarlet with provided path
    api_key=$(xmlstarlet sel -t -v "$xml_path" "$config_file" 2>/dev/null | tr -d '\n\r')

    # Method 2: fallback to common paths
    if [ -z "$api_key" ] || [ "$api_key" = "null" ]; then
        api_key=$(xmlstarlet sel -t -v "//Config/ApiKey" "$config_file" 2>/dev/null | tr -d '\n\r')
    fi

    # Method 3: grep fallback
    if [ -z "$api_key" ] || [ "$api_key" = "null" ]; then
        api_key=$(grep -oP '<ApiKey>\K[^<]+' "$config_file" 2>/dev/null | tr -d '\n\r')
    fi

    # Method 4: sed fallback
    if [ -z "$api_key" ] || [ "$api_key" = "null" ]; then
        api_key=$(sed -n 's/.*<ApiKey>\(.*\)<\/ApiKey>.*/\1/p' "$config_file" 2>/dev/null | tr -d '\n\r')
    fi

    echo "$api_key"
}

# Create or update Kubernetes secret
create_secret() {
    local secret_name=$1
    local api_key=$2
    local namespace=${3:-$NAMESPACE}

    kubectl create secret generic "$secret_name" \
        --from-literal=api-key="$api_key" \
        --namespace="$namespace" \
        --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1

    if [ $? -eq 0 ]; then
        log "Secret '$secret_name' updated successfully"
        return 0
    else
        log "ERROR: Failed to update secret '$secret_name'"
        return 1
    fi
}

# Create or update ConfigMap
create_configmap() {
    local configmap_name=$1
    local api_key=$2
    local namespace=${3:-$NAMESPACE}

    kubectl create configmap "$configmap_name" \
        --from-literal=api-key="$api_key" \
        --namespace="$namespace" \
        --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1

    if [ $? -eq 0 ]; then
        log "ConfigMap '$configmap_name' updated successfully"
        return 0
    else
        log "ERROR: Failed to update configmap '$configmap_name'"
        return 1
    fi
}

# Write to file
write_to_file() {
    local file_path=$1
    local api_key=$2

    local dir
    dir=$(dirname "$file_path")
    mkdir -p "$dir" 2>/dev/null

    if echo "$api_key" >"$file_path"; then
        log "API key written to file: $file_path"
        return 0
    else
        log "ERROR: Failed to write to file: $file_path"
        return 1
    fi
}

# Main processing function
process_api_key() {
    local api_key
    api_key=$(extract_api_key "$CONFIG_FILE" "$XML_PATH")

    if [ -n "$api_key" ] && [ "$api_key" != "null" ]; then
        log "API key extracted: ${api_key:0:8}..."

        case "$OUTPUT_TYPE" in
        "secret")
            create_secret "$SECRET_NAME" "$api_key"
            ;;
        "configmap")
            create_configmap "$SECRET_NAME" "$api_key"
            ;;
        "file")
            write_to_file "${OUTPUT_FILE:-/shared/${APP_NAME,,}-api-key}" "$api_key"
            ;;
        "all")
            create_secret "$SECRET_NAME" "$api_key"
            create_configmap "${SECRET_NAME}-cm" "$api_key"
            write_to_file "${OUTPUT_FILE:-/shared/${APP_NAME,,}-api-key}" "$api_key"
            ;;
        *)
            log "ERROR: Unknown output type: $OUTPUT_TYPE"
            return 1
            ;;
        esac
    else
        log "No valid API key found in $CONFIG_FILE"
        return 1
    fi
}

# Health check function
health_check() {
    if [ "$OUTPUT_TYPE" = "secret" ] || [ "$OUTPUT_TYPE" = "all" ]; then
        kubectl get secret "$SECRET_NAME" --namespace="$NAMESPACE" >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            log "WARNING: Secret '$SECRET_NAME' not found"
            return 1
        fi
    fi
    return 0
}

# Signal handlers
cleanup() {
    log "Received termination signal, cleaning up..."
    exit 0
}

trap cleanup TERM INT

# Main execution
main() {
    log "Starting Universal API Key Extractor"
    log "App: $APP_NAME"
    log "Config: $CONFIG_FILE"
    log "Secret: $SECRET_NAME"
    log "Output: $OUTPUT_TYPE"
    log "Interval: ${CHECK_INTERVAL}s"
    log "Namespace: $NAMESPACE"

    install_dependencies

    # Initial extraction with retry
    log "Performing initial API key extraction..."
    retry_count=0
    max_retries=10

    while [ $retry_count -lt $max_retries ]; do
        if process_api_key; then
            log "Initial extraction successful"
            break
        else
            retry_count=$((retry_count + 1))
            log "Initial extraction failed (attempt $retry_count/$max_retries)"
            if [ $retry_count -lt $max_retries ]; then
                sleep 10
            else
                log "ERROR: Initial extraction failed after $max_retries attempts"
            fi
        fi
    done

    # Continuous monitoring
    log "Starting continuous monitoring..."
    while true; do
        sleep "$CHECK_INTERVAL"
        process_api_key

        # Optional health check
        if [ -n "$HEALTH_CHECK" ] && [ "$HEALTH_CHECK" = "true" ]; then
            health_check
        fi
    done
}

# Execute main function
main "$@"
