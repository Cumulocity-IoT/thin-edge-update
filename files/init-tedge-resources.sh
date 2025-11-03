#!/bin/bash
set -e

# Function to check if running as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "This script must be run as root (sudo). Exiting."
        exit 1
    fi
}

# Function to clean podman storage
clean_podman_storage() {
    echo "Cleaning podman storage to resolve graph driver issues..."
    if [ -d "/home/tedge/.local/share/containers/storage" ]; then
        rm -rf "/home/tedge/.local/share/containers/storage"
        echo "Cleaned podman storage directory"
    fi
}

# Clean podman storage to resolve graph driver issues
clean_podman_storage

# Create networks if they don't exist
echo "Creating podman networks..."
if ! podman network exists tedge 2>/dev/null; then
    podman network create tedge
    echo "Created tedge network"
fi



# Create volume if it doesn't exist
echo "Creating podman volume..."
if ! podman volume exists tedge 2>/dev/null; then
    podman volume create tedge
    echo "Created tedge volume"
fi

# Create directory structure
echo "Creating configuration directory..."
sudo mkdir -p /home/tedge/edge/scripts/config

# Set appropriate permissions
echo "Setting directory permissions..."
sudo chown -R "$(id -u):$(id -g)" /home/tedge

echo "All tedge resources have been initialized successfully!"