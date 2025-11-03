#!/bin/bash
set -e

# Configuration
REGISTRY="docker.io"
DOCKER_USERNAME=""
IMAGE_NAME="iot-thin-edge-solution"
VERSION=$(date +%Y%m%d.%H%M)  # Format: YYYYMMDD.HHMM

# Function to get docker hub username
get_docker_username() {
    DOCKER_USERNAME=$(podman login --get-login "${REGISTRY}" 2>/dev/null || echo "")
    if [ -z "${DOCKER_USERNAME}" ]; then
        echo "Error: Not logged in to Docker Hub"
        return 1
    fi
    echo "Using Docker Hub username: ${DOCKER_USERNAME}"
}

# Function to check docker hub credentials
check_docker_login() {
    echo "Checking Docker Hub login status..."
    if ! get_docker_username; then
        echo "Please login first:"
        podman login "${REGISTRY}"
        get_docker_username || exit 1
    fi
}

# Function to build the image
build_image() {
    local build_id="$1"
    local full_image="${REGISTRY}/${DOCKER_USERNAME}/${IMAGE_NAME}:${VERSION}"
    
    echo "Building image ${full_image}..."
    podman build \
        --network=host \
        --build-arg BUILD_ID="${build_id}" \
        --format docker \
        -t "${full_image}" \
        .
    
    # Tag as latest
    podman tag "${full_image}" "${REGISTRY}/${DOCKER_USERNAME}/${IMAGE_NAME}:latest"
}

# Function to publish the image
publish_image() {
    local full_image="${REGISTRY}/${DOCKER_USERNAME}/${IMAGE_NAME}:${VERSION}"
    
    echo "Publishing image ${full_image}..."
    podman push "${full_image}"
    echo "Publishing latest tag..."
    podman push "${REGISTRY}/${DOCKER_USERNAME}/${IMAGE_NAME}:latest"
}

# Main execution
main() {
    # Check if we're in the right directory (where Dockerfile exists)
    if [ ! -f "Dockerfile" ]; then
        echo "Error: Dockerfile not found in current directory"
        exit 1
    fi

    # Check Docker Hub login and get username
    check_docker_login

    # Build the image
    build_image "${VERSION}"

    # Publish the image
    publish_image

    echo "Successfully built and published:"
    echo "  - ${REGISTRY}/${DOCKER_USERNAME}/${IMAGE_NAME}:${VERSION}"
    echo "  - ${REGISTRY}/${DOCKER_USERNAME}/${IMAGE_NAME}:latest"
}

# Run main function
main