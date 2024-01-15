#!/bin/bash

# Install Tailscale
echo "Installing Tailscale..."

## Add tailscale repository
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list

## Install tailscale
sudo apt-get update
sudo apt-get install tailscale

## Run tailscale
sudo tailscale up
echo "Done..."
