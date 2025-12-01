#!/bin/bash
set -e

get_docker_username() {
    local registry="$1"
    local image_base="$2"
    
    # Note: Use double curly braces around .Repository
    local username=$(podman images --format '{{ ''.Repository'' }}' | \
                     grep "^${registry}/" | \
                     grep "/${image_base}$" | \
                     sed "s|^${registry}/||" | \
                     sed "s|/${image_base}$||" | \
                     head -n 1)
    
    if [ -n "$username" ]; then
        echo "$username"
        return 0
    fi
    
    username=$(podman login --get-login "${registry}" 2>/dev/null || echo "")
    if [ -n "$username" ]; then
        echo "$username"
        return 0
    fi
    
    return 1
}

REGISTRY="docker.io"
IMAGE_NAME="iot-thin-edge-solution"

DOCKER_USERNAME=$(get_docker_username "${REGISTRY}" "${IMAGE_NAME}")

if [ -z "$DOCKER_USERNAME" ]; then
    echo "Error: Could not determine Docker username. Please ensure:"
    echo "  1. You have images tagged as ${REGISTRY}/username/${IMAGE_NAME}, or"
    echo "  2. You are logged in to ${REGISTRY}"
    exit 1
fi

echo "Using Docker username: ${DOCKER_USERNAME}"
FULL_IMAGE="${REGISTRY}/${DOCKER_USERNAME}/${IMAGE_NAME}"

get_highest_local_tag() {
    local registry="$1"
    local username="$2"
    local image="$3"
    local full_image="${registry}/${username}/${image}"
    
    # Note: Use double curly braces around .Repository and .Tag
    local highest=$(podman images --format '{{ .Repository }}:{{ .Tag }}' | \
                    grep "^${full_image}:" | \
                    sed "s|^${full_image}:||" | \
                    grep -v '^latest$' | \
                    grep -v '^<none>$' | \
                    sort | \
                    tail -1)
    
    echo "$highest"
}

HIGHEST_TAG=$(get_highest_local_tag "$REGISTRY" "$DOCKER_USERNAME" "$IMAGE_NAME")

if [[ -z "$HIGHEST_TAG" ]]; then
    echo "Error: No local images found matching pattern ${FULL_IMAGE}:*" >&2
    echo "Available local images:" >&2
    podman images --format '{{ .Repository }}:{{ .Tag }}' | grep "${IMAGE_NAME}" || echo "None found"
    exit 1
fi

echo "Highest local tag: $HIGHEST_TAG"
echo "Full image reference: ${FULL_IMAGE}:${HIGHEST_TAG}"

podman network exists tedge || podman network create tedge

export S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0

podman create \
--name tedge-watch \
--network tedge \
-v "tedge-data:/data/tedge" \
-v "/home/tedge/edge/config:/etc/tedge/device-certs" \
-v "/run/user/$UID/podman/podman.sock:/var/run/docker.sock:rw" \
-e S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0 \
--env-file /home/tedge/edge/config/iot.cfg \
"$FULL_IMAGE":"$HIGHEST_TAG"

echo "Container tedge-watch created successfully"