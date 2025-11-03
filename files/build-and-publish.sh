#!/bin/bash
set -e

# Configuration
REGISTRY="docker.io"
IMAGE_NAME="iot-thin-edge-solution"
VERSION=$(date +%Y%m%d.%H%M)  # Format: YYYYMMDD.HHMM
FULL_IMAGE="${REGISTRY}/${IMAGE_NAME}:${VERSION}"

# Function to check docker hub credentials
check_docker_login() {
    echo "Checking Docker Hub login status..."
    if ! podman login --get-login "${REGISTRY}" >/dev/null 2>&1; then
        echo "Not logged in to Docker Hub. Please login first:"
        podman login "${REGISTRY}"
    fi
}

# Function to build the image
build_image() {
    local build_id="$1"
    echo "Building image ${FULL_IMAGE}..."
    podman build \
        --network=host \
        --build-arg BUILD_ID="${build_id}" \
        --format docker \
        -t "${FULL_IMAGE}" \
        .
    
    # Tag as latest
    podman tag "${FULL_IMAGE}" "${REGISTRY}/${IMAGE_NAME}:latest"
}

# Function to publish the image
publish_image() {
    echo "Publishing image ${FULL_IMAGE}..."
    podman push "${FULL_IMAGE}"
    echo "Publishing latest tag..."
    podman push "${REGISTRY}/${IMAGE_NAME}:latest"
}

# Main execution
main() {
    # Check if we're in the right directory (where Dockerfile exists)
    if [ ! -f "Dockerfile" ]; then
        echo "Error: Dockerfile not found in current directory"
        exit 1
    fi

    # Check Docker Hub login
    check_docker_login

    # Build the image
    build_image "${VERSION}"

    # Publish the image
    publish_image

    echo "Successfully built and published:"
    echo "  - ${FULL_IMAGE}"
    echo "  - ${REGISTRY}/${IMAGE_NAME}:latest"
}

# Run main function
main