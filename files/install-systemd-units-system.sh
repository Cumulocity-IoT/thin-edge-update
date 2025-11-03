#!/bin/bash
set -e

# Function to check if running as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "This script must be run as root (sudo). Exiting."
        exit 1
    fi
}

# Check if running as root
check_root

# Set variables
SYSTEMD_USER_DIR="/etc/xdg/systemd/user"
SCRIPT_DIR="/home/tedge/edge/scripts"

# Create required directories
echo "Creating systemd and script directories..."
mkdir -p "${SYSTEMD_USER_DIR}"
mkdir -p "${SCRIPT_DIR}"

# Copy systemd unit files
echo "Installing systemd unit files..."
cp systemd/tedge-container.service "${SYSTEMD_USER_DIR}/"
cp systemd/tedge-container-restart.service "${SYSTEMD_USER_DIR}/"
cp systemd/tedge-container-restart.path "${SYSTEMD_USER_DIR}/"

# Copy script files
echo "Installing scripts..."
cp files/start-tedge-container.sh "${SCRIPT_DIR}/"
chmod +x "${SCRIPT_DIR}/start-tedge-container.sh"

# Set proper permissions
echo "Setting permissions..."
chown -R tedge:tedge "${SCRIPT_DIR}"
chmod 644 "${SYSTEMD_USER_DIR}/tedge-container.service"
chmod 644 "${SYSTEMD_USER_DIR}/tedge-container-restart.service"
chmod 644 "${SYSTEMD_USER_DIR}/tedge-container-restart.path"

# Reload systemd user units
echo "Reloading systemd user units..."
systemctl daemon-reload

# Enable and start the services for the tedge user
echo "Enabling and starting services..."
runuser -l tedge -c 'XDG_RUNTIME_DIR=/run/user/$(id -u) systemctl --user daemon-reload'
runuser -l tedge -c 'XDG_RUNTIME_DIR=/run/user/$(id -u) systemctl --user enable tedge-container.service'
runuser -l tedge -c 'XDG_RUNTIME_DIR=/run/user/$(id -u) systemctl --user enable tedge-container-restart.path'
runuser -l tedge -c 'XDG_RUNTIME_DIR=/run/user/$(id -u) systemctl --user start tedge-container.service'
runuser -l tedge -c 'XDG_RUNTIME_DIR=/run/user/$(id -u) systemctl --user start tedge-container-restart.path'

# Enable lingering for tedge user to allow services to run without user login
loginctl enable-linger tedge

echo "Installation complete! Services have been installed and started."
echo "You can check the status with:"
echo "runuser -l tedge -c 'XDG_RUNTIME_DIR=/run/user/\$(id -u) systemctl --user status tedge-container.service'"