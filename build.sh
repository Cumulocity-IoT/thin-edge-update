#!/bin/bash
set -e

# Configuration
REGISTRY="docker.io"
IMAGE_NAME="iot-thin-edge-solution"

# Prompt for Docker username
echo "Docker Hub Configuration"
echo "========================"
read -p "Enter your Docker Hub username: " DOCKER_USERNAME

if [ -z "$DOCKER_USERNAME" ]; then
    echo "Error: Docker username is required"
    exit 1
fi

# Generate version tag (timestamp-based)
VERSION=$(date +%Y%m%d.%H%M)

# Accept version as first argument, or use generated one
if [ -n "$1" ]; then
    VERSION="$1"
fi

# Full image reference
FULL_IMAGE="${REGISTRY}/${DOCKER_USERNAME}/${IMAGE_NAME}:${VERSION}"
LATEST_IMAGE="${REGISTRY}/${DOCKER_USERNAME}/${IMAGE_NAME}:latest"

# Platform selection
echo ""
echo "Select platform(s) to build for:"
echo "1) linux/amd64 only (recommended for Mac)"
echo "2) linux/amd64,linux/arm64"
echo "3) linux/amd64,linux/arm64,linux/arm/v7 (may fail on Mac)"
read -p "Enter choice [1]: " platform_choice
platform_choice=${platform_choice:-1}

case $platform_choice in
    1)
        PLATFORMS="linux/amd64"
        ;;
    2)
        PLATFORMS="linux/amd64,linux/arm64"
        ;;
    3)
        PLATFORMS="linux/amd64,linux/arm64,linux/arm/v7"
        ;;
    *)
        echo "Invalid choice, using linux/amd64"
        PLATFORMS="linux/amd64"
        ;;
esac

echo ""
echo "=========================================="
echo "Build Configuration"
echo "=========================================="
echo "Image Name: ${IMAGE_NAME}"
echo "Version: ${VERSION}"
echo "Registry: ${REGISTRY}"
echo "Username: ${DOCKER_USERNAME}"
echo "Platforms: ${PLATFORMS}"
echo ""
echo "Tags to be created:"
echo "  ${FULL_IMAGE}"
echo "  ${LATEST_IMAGE}"
echo "=========================================="
echo ""

# Confirm before building
read -p "Proceed with build? (y/n) [y]: " proceed
proceed=${proceed:-y}

if [[ ! "$proceed" =~ ^[Yy]$ ]]; then
    echo "Build cancelled."
    exit 0
fi

# Check if Dockerfile exists
if [ ! -f "Dockerfile" ]; then
    echo "Error: Dockerfile not found in current directory!"
    exit 1
fi

# Login to Docker Hub
echo ""
echo "Logging in to ${REGISTRY}..."
docker login ${REGISTRY}

# Create buildx builder
echo ""
echo "Setting up buildx builder..."
docker buildx rm multiarch-builder 2>/dev/null || true
docker buildx create --name multiarch-builder --driver docker-container --bootstrap --use

# Build and push
echo ""
echo "Building for platforms: ${PLATFORMS}..."
echo ""

docker buildx build \
  --platform ${PLATFORMS} \
  --tag ${FULL_IMAGE} \
  --tag ${LATEST_IMAGE} \
  --push \
  --progress=plain \
  .

echo ""
echo "=========================================="
echo "Build Complete!"
echo "=========================================="
echo "Successfully built and pushed:"
echo "  ${FULL_IMAGE}"
echo "  ${LATEST_IMAGE}"
echo ""
echo "Platforms: ${PLATFORMS}"
echo ""
echo "To use this image:"
echo "  docker pull ${FULL_IMAGE}"
echo "  docker run ${FULL_IMAGE}"
echo "=========================================="