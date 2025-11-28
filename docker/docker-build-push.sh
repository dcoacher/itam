#!/bin/bash
# Script to build and push ITAM app to Docker Hub

set -e

# Configuration
DOCKER_USERNAME="${DOCKER_USERNAME:-}"
IMAGE_NAME="itam-app"
IMAGE_TAG="${IMAGE_TAG:-latest}"

# Check if Docker Hub username is provided
if [ -z "$DOCKER_USERNAME" ]; then
    echo "Error: DOCKER_USERNAME environment variable is not set"
    echo "Usage: DOCKER_USERNAME=yourusername ./docker/docker-build-push.sh"
    echo "Or: export DOCKER_USERNAME=yourusername && ./docker/docker-build-push.sh"
    exit 1
fi

FULL_IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "========================================="
echo "Building and pushing ITAM app to Docker Hub"
echo "========================================="
echo "Docker Hub Username: $DOCKER_USERNAME"
echo "Image Name: $FULL_IMAGE_NAME"
echo ""

# Step 1: Build the Docker image
# Run from project root, use -f to specify Dockerfile location
echo "Step 1: Building Docker image..."
cd "$(dirname "$0")/.." || exit 1
docker build -f docker/Dockerfile -t "${FULL_IMAGE_NAME}" -t "${DOCKER_USERNAME}/${IMAGE_NAME}:latest" .

if [ $? -ne 0 ]; then
    echo "Error: Docker build failed!"
    exit 1
fi

echo "✓ Docker image built successfully"
echo ""

# Step 2: Login to Docker Hub (if not already logged in)
echo "Step 2: Checking Docker Hub login..."
if ! docker info | grep -q "Username"; then
    echo "Please login to Docker Hub:"
    docker login
    if [ $? -ne 0 ]; then
        echo "Error: Docker Hub login failed!"
        exit 1
    fi
fi

echo "✓ Docker Hub login verified"
echo ""

# Step 3: Push the image to Docker Hub
echo "Step 3: Pushing image to Docker Hub..."
docker push "${FULL_IMAGE_NAME}"
docker push "${DOCKER_USERNAME}/${IMAGE_NAME}:latest"

if [ $? -ne 0 ]; then
    echo "Error: Docker push failed!"
    exit 1
fi

echo "✓ Image pushed successfully"
echo ""

echo "========================================="
echo "Success! Image available at:"
echo "  ${FULL_IMAGE_NAME}"
echo ""
echo "Next steps:"
echo "1. Update helm/values.yaml:"
echo "   image.repository: docker.io/${DOCKER_USERNAME}/${IMAGE_NAME}"
echo "2. Deploy to Kubernetes using Helm"
echo "========================================="


