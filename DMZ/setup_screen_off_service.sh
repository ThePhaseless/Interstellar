#!/bin/bash

# Install screen_off.service
echo "Installing screen-off.service..."
sudo cp ./Scripts/screen-off.service /etc/systemd/system/screen-off.service

sudo systemctl daemon-reload
sudo systemctl enable screen-off.service
sudo systemctl start screen-off.service
echo "Done..."
