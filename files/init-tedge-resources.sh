#!/bin/bash
set -e

# Create networks if they don't exist
echo "Creating podman networks..."
podman network exists tedge || podman network create tedge

# Create volume if it doesn't exist
echo "Creating podman volume..."
podman volume exists tedge || podman volume create tedge

# Create directory structure
echo "Creating configuration directory..."
sudo mkdir -p /home/tedge/edge/scripts/config

# Set appropriate permissions
echo "Setting directory permissions..."
sudo chown -R "$(id -u):$(id -g)" /home/tedge

echo "All tedge resources have been initialized successfully!"