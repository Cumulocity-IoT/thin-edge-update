#!/bin/bash
set -e

get_docker_username() {
    local registry="$1"
    local image_base="$2"
    
    # Try to find any image matching the pattern registry/*/image_base
    local username=$(podman images --format '{.Repository}' | \
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

REGISTRY="docker.io"
IMAGE_NAME="iot-thin-edge-solution"

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

# Function to get highest tag from local images only
get_highest_local_tag() {
    local registry="$1"
    local username="$2"
    local image="$3"
    local full_image="${registry}/${username}/${image}"
    
    local highest=$(podman images --format '{.Repository}:{.Tag}' | \
                    grep "^${full_image}:" | \
                    sed "s|^${full_image}:||" | \
                    grep -E '^[0-9]+(\.[0-9]+)*$' | \
                    sort -V | \
                    tail -1)
    
    echo "$highest"
}

HIGHEST_TAG=$(get_highest_local_tag "$REGISTRY" "$DOCKER_USERNAME" "$IMAGE_NAME")

if [[ -n "$HIGHEST_TAG" ]]; then
    echo "Highest local tag: $HIGHEST_TAG"
    echo "Full image reference: ${FULL_IMAGE}:${HIGHEST_TAG}"
else
    echo "Error: No local images found matching pattern ${FULL_IMAGE}:*" >&2
    echo "Available local images:" >&2
    podman images | grep -E "(REPOSITORY|${IMAGE_NAME})" || echo "None found"
    exit 1
fi

# Set S6_CMD_WAIT_FOR_SERVICES_MAXTIME to 0 to wait forever
export S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0

# Create container (systemd will handle cleanup via ExecStartPre)
podman create \
--name tedge \
--network tedge \
-p "1883:1883" \
-p "8000:8000" \
-p "8001:8001" \
-v "tedge-data:/data/tedge" \
-v "/home/tedge/edge/config:/local-conf" \
-e TEDGE_C8Y_OPERATIONS_AUTO_LOG_UPLOAD=always \
-e TEDGE_MQTT_BRIDGE_BUILT_IN=true \
-e TEDGE_DEVICE_CERT_PATH=/local-conf/tedge-certificate.pem \
-e TEDGE_DEVICE_KEY_PATH=/local-conf/tedge-private-key.pem \
-v "/run/user/$UID/podman/podman.sock:/var/run/docker.sock:rw" \
--env-file /home/tedge/edge/config/iot.cfg \
"$FULL_IMAGE":"$HIGHEST_TAG"