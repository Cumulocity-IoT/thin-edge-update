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
TEDGE_USER="tedge"
TEDGE_UID=$(id -u ${TEDGE_USER})
SYSTEMD_USER_DIR="/home/${TEDGE_USER}/.config/systemd/user"
SCRIPT_DIR="/home/${TEDGE_USER}/edge/scripts"

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
chown -R ${TEDGE_USER}:${TEDGE_USER} "${SYSTEMD_USER_DIR}"
chown -R ${TEDGE_USER}:${TEDGE_USER} "${SCRIPT_DIR}"
chmod 644 "${SYSTEMD_USER_DIR}/tedge-container.service"
chmod 644 "${SYSTEMD_USER_DIR}/tedge-container-restart.service"
chmod 644 "${SYSTEMD_USER_DIR}/tedge-container-restart.path"

# Enable lingering for tedge user to allow services to run without user login
echo "Enabling lingering for ${TEDGE_USER} user..."
loginctl enable-linger ${TEDGE_USER}

# Reload systemd user units and enable services
echo "Reloading systemd user units..."
runuser -l ${TEDGE_USER} -c "XDG_RUNTIME_DIR=/run/user/${TEDGE_UID} systemctl --user daemon-reload"

echo "Enabling services..."
runuser -l ${TEDGE_USER} -c "XDG_RUNTIME_DIR=/run/user/${TEDGE_UID} systemctl --user enable tedge-container.service"
runuser -l ${TEDGE_USER} -c "XDG_RUNTIME_DIR=/run/user/${TEDGE_UID} systemctl --user enable tedge-container-restart.path"

echo "Starting services..."
runuser -l ${TEDGE_USER} -c "XDG_RUNTIME_DIR=/run/user/${TEDGE_UID} systemctl --user start tedge-container.service"
runuser -l ${TEDGE_USER} -c "XDG_RUNTIME_DIR=/run/user/${TEDGE_UID} systemctl --user start tedge-container-restart.path"

echo ""
echo "Installation complete! Services have been installed and started."
echo ""
echo "Useful commands:"
echo "  Check service status:"
echo "    sudo -u ${TEDGE_USER} XDG_RUNTIME_DIR=/run/user/${TEDGE_UID} systemctl --user status tedge-container.service"
echo ""
echo "  View logs:"
echo "    sudo -u ${TEDGE_USER} XDG_RUNTIME_DIR=/run/user/${TEDGE_UID} journalctl --user -u tedge-container.service -f"
echo ""
echo "  List all user services:"
echo "    sudo -u ${TEDGE_USER} XDG_RUNTIME_DIR=/run/user/${TEDGE_UID} systemctl --user list-units"