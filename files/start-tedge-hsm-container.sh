#!/bin/bash
set -e

# Configuration
IMAGE_NAME="iot-thin-edge-solution"
CONFIG_FILE="/home/tedge/edge/config/update-${IMAGE_NAME}.cfg"
REGISTRY="docker.io"

# Function to read image from config file
get_image_from_config() {
    local config_file="$1"
    
    if [[ -f "$config_file" ]]; then
        # Source the config file and extract CURRENT_IMAGE
        local current_image
        current_image=$(grep "^CURRENT_IMAGE=" "$config_file" | cut -d'=' -f2-)
        
        if [[ -n "$current_image" ]]; then
            echo "$current_image"
            return 0
        fi
    fi
    
    return 1
}

# Function to get docker username from image reference
get_docker_username_from_image() {
    local full_image="$1"
    local registry="$2"
    
    # Extract username from full image path: registry/username/image:tag
    local username
    username=$(echo "$full_image" | sed "s|^${registry}/||" | cut -d'/' -f1)
    echo "$username"
}

# Function to get docker username (original function)
get_docker_username() {
    local registry="$1"
    local image_base="$2"
    
    # Try to find any image matching the pattern registry/*/image_base
    local username
    username=$(podman images --format '{.Repository}' | \
                     grep "^${registry}/" | \
                     grep "/${image_base}$" | \
                     sed "s|^${registry}/||" | \
                     sed "s|/${image_base}$||" | \
                     head -n 1)
    
    if [ -n "$username" ]; then
        echo "$username"
        return 0
    fi
    
    # Fallback: try to get from podman login
    username=$(podman login --get-login "${registry}" 2>/dev/null || echo "")
    if [ -n "$username" ]; then
        echo "$username"
        return 0
    fi
    
    # No username found
    return 1
}

# Function to get highest tag from local images only
get_highest_local_tag() {
    local registry="$1"
    local username="$2"
    local image="$3"
    local full_image="${registry}/${username}/${image}"
    
    local highest
    highest=$(podman images --format '{.Repository}:{.Tag}' | \
                    grep "^${full_image}:" | \
                    sed "s|^${full_image}:||" | \
                    grep -E '^[0-9]+(\.[0-9]+)*$' | \
                    sort -V | \
                    tail -1)
    
    echo "$highest"
}

# Try to get image from config file first
LATEST_IMAGE=$(get_image_from_config "$CONFIG_FILE")

if [[ -n "$LATEST_IMAGE" ]]; then
    echo "Using image from config file: $LATEST_IMAGE"
    
    # Extract Docker username from the config image
    DOCKER_USERNAME=$(get_docker_username_from_image "$LATEST_IMAGE" "$REGISTRY")
    FULL_IMAGE="${REGISTRY}/${DOCKER_USERNAME}/${IMAGE_NAME}"
    
    # Extract tag from LATEST_IMAGE
    HIGHEST_TAG=$(echo "$LATEST_IMAGE" | grep -oP ':[^:]+$' | sed 's/^://')
    
    if [[ -z "$HIGHEST_TAG" ]]; then
        echo "Warning: Could not extract tag from $LATEST_IMAGE"
        echo "Falling back to local image detection..."
        LATEST_IMAGE=""
    else
        echo "Extracted tag: $HIGHEST_TAG"
    fi
fi

# Fallback to original behavior if config file doesn't exist or is empty
if [[ -z "$LATEST_IMAGE" ]]; then
    echo "Config file not found or empty, detecting from local images..."
    
    # Auto-detect Docker username
    DOCKER_USERNAME=$(get_docker_username "${REGISTRY}" "${IMAGE_NAME}")
    
    if [ -z "$DOCKER_USERNAME" ]; then
        echo "Error: Could not determine Docker username. Please ensure:"
        echo "  1. You have images tagged as ${REGISTRY}/username/${IMAGE_NAME}, or"
        echo "  2. You are logged in to ${REGISTRY}"
        exit 1
    fi
    
    echo "Using Docker username: ${DOCKER_USERNAME}"
    FULL_IMAGE="${REGISTRY}/${DOCKER_USERNAME}/${IMAGE_NAME}"
    
    HIGHEST_TAG=$(get_highest_local_tag "$REGISTRY" "$DOCKER_USERNAME" "$IMAGE_NAME")
    
    if [[ -n "$HIGHEST_TAG" ]]; then
        echo "Highest local tag: $HIGHEST_TAG"
        LATEST_IMAGE="${FULL_IMAGE}:${HIGHEST_TAG}"
    else
        echo "Error: No local images found matching pattern ${FULL_IMAGE}:*" >&2
        echo "Available local images:" >&2
        podman images | grep -E "(REPOSITORY|${IMAGE_NAME})" || echo "None found"
        exit 1
    fi
fi

echo "Full image reference: $LATEST_IMAGE"

# Export variables for use in other scripts
export HIGHEST_TAG
export LATEST_IMAGE

echo "Variables set:"
echo "  HIGHEST_TAG=$HIGHEST_TAG"
echo "  LATEST_IMAGE=$LATEST_IMAGE"

# Set S6_CMD_WAIT_FOR_SERVICES_MAXTIME to 0 to wait forever ...
export S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0

# Remove existing container if it exists
podman rm -f tedge 2>/dev/null || true

podman run -d \
--userns keep-id \
--name tedge \
--network tedge \
--restart always \
--replace \
-p "1883:1883" \
-p "8000:8000" \
-p "8001:8001" \
-v "tedge-data:/data/tedge" \
-v "/home/tedge/edge/config:/local-conf" \
-e TEDGE_C8Y_OPERATIONS_AUTO_LOG_UPLOAD=always \
-e TEDGE_MQTT_BRIDGE_BUILT_IN=true \
-e TEDGE_DEVICE_CERT_PATH=/local-conf/tedge-certificate.pem \
-e TEDGE_DEVICE_CRYPTOKI_MODE=socket \
-v "/run/user/$UID/podman/podman.sock:/var/run/docker.sock:rw" \
-v "/run/user/$UID/tedge-p11-server:/run/tedge-p11-server" \
--env-file /home/tedge/edge/config/iot.cfg \
"$LATEST_IMAGE"