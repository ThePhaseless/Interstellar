#!/bin/bash
set -e

echo "Initializing $APP_NAME with template config..."

# Copy template config to the container
if [ ! -f /config/config.xml ]; then
    echo "Copying template config.xml..."
    cp /config-template/arr-config.xml /config/config.xml
    chown 1000:1000 /config/config.xml
    chmod 644 /config/config.xml
else
    echo "Config.xml already exists, skipping template copy."
fi

echo "$APP_NAME initialization complete!"
