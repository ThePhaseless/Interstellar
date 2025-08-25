#!/bin/bash
set -e

echo "Configuring Prowlarr indexers..."

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
            {"name": "apiKey", "value": "'"$SONARR_API_KEY"'"},
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
            {"name": "apiKey", "value": "'"$RADARR_API_KEY"'"},
            {"name": "syncLevel", "value": "fullSync"}
        ],
        "tags": []
    }'

echo "Prowlarr configuration completed!"
