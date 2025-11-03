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
#!/bin/bash
set -e

# Function to safely clean podman storage
clean_podman_storage() {
    echo "Cleaning podman storage..."
    
    # First, stop and remove all containers
    echo "Stopping all containers..."
    podman stop --all 2>/dev/null || true
    
    echo "Removing all containers..."
    podman rm --all --force 2>/dev/null || true
    
    # Remove all images
    echo "Removing all images..."
    podman rmi --all --force 2>/dev/null || true
    
    # Use podman's built-in cleanup
    echo "Running podman system reset..."
    podman system reset --force 2>/dev/null || true
    
    # If storage directory still exists and has permission issues, use sudo
    if [ -d "$HOME/.local/share/containers/storage" ]; then
        echo "Removing storage directory with elevated permissions..."
        if ! rm -rf "$HOME/.local/share/containers/storage" 2>/dev/null; then
            echo "Need sudo to remove some files created by containers..."
            sudo rm -rf "$HOME/.local/share/containers/storage"
            # Recreate with correct ownership
            mkdir -p "$HOME/.local/share/containers/storage"
        fi
    fi
    
    echo "Podman storage cleaned successfully"
}

# Function to initialize resources
init_resources() {
    # Create networks if they don't exist
    echo "Creating podman networks..."
    if ! podman network exists tedge 2>/dev/null; then
        podman network create tedge
        echo "Created tedge network"
    else
        echo "Network 'tedge' already exists"
    fi

    # Create volume if it doesn't exist
    echo "Creating podman volume..."
    if ! podman volume exists tedge 2>/dev/null; then
        podman volume create tedge
        echo "Created tedge volume"
    else
        echo "Volume 'tedge' already exists"
    fi

    # Create directory structure
    echo "Creating configuration directory..."
    mkdir -p "$HOME/edge/scripts/config"

    echo "All tedge resources have been initialized successfully!"
}

# Main execution
main() {
    echo "Initializing tedge resources as user: $(whoami)"
    
    # Ask user if they want to clean storage
    read -p "Do you want to clean Podman storage? This will remove all containers and images! (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        clean_podman_storage
    else
        echo "Skipping storage cleanup"
    fi
    
    init_resources
}

main

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