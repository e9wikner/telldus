#!/bin/bash
set -euo pipefail

IMAGE_NAME="telldus"
IMAGE_TAG="latest"
BUILDER="telldus-builder"

usage() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Build the Telldus Core Docker image with multi-architecture support.

Options:
  --load              Build single-platform image for local use (default).
                      Platform: linux/amd64
                      Tag: telldus:latest

  --push <registry>   Build and push multi-platform image to a registry.
                      Platforms: linux/amd64,linux/arm64
                      Tag: <registry>/telldus:latest
                      Example: $(basename "$0") --push ghcr.io/user

  --help              Show this help message and exit.

Examples:
  $(basename "$0") --load
  $(basename "$0") --push ghcr.io/username
EOF
}

setup_builder() {
	if ! docker buildx inspect "$BUILDER" >/dev/null 2>&1; then
		echo "Creating Docker buildx builder: $BUILDER"
		docker buildx create --name "$BUILDER" --driver docker-container --bootstrap
	fi
	docker buildx use "$BUILDER"
}

# Default action
ACTION="--load"
REGISTRY_PREFIX=""

# Parse arguments
if [ $# -eq 0 ]; then
	ACTION="--load"
elif [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
	usage
	exit 0
elif [ "$1" = "--load" ]; then
	ACTION="--load"
	if [ $# -gt 1 ]; then
		echo "Error: --load does not accept additional arguments." >&2
		usage >&2
		exit 1
	fi
elif [ "$1" = "--push" ]; then
	ACTION="--push"
	if [ $# -lt 2 ]; then
		echo "Error: --push requires a registry prefix argument." >&2
		usage >&2
		exit 1
	fi
	REGISTRY_PREFIX="$2"
else
	echo "Error: Unknown argument '$1'" >&2
	usage >&2
	exit 1
fi

setup_builder

if [ "$ACTION" = "--load" ]; then
	echo "Building single-platform image: ${IMAGE_NAME}:${IMAGE_TAG} (linux/amd64)"
	docker buildx build \
		--platform linux/amd64 \
		--tag "${IMAGE_NAME}:${IMAGE_TAG}" \
		--load \
		.
	echo "Build complete: ${IMAGE_NAME}:${IMAGE_TAG}"
else
	FULL_TAG="${REGISTRY_PREFIX}/${IMAGE_NAME}:${IMAGE_TAG}"
	echo "Building multi-platform image: ${FULL_TAG} (linux/amd64, linux/arm64)"
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--tag "${FULL_TAG}" \
		--push \
		.
	echo "Build and push complete: ${FULL_TAG}"
fi
