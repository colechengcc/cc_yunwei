#!/bin/bash
# Docker build script with proper proxy configuration

set -e

# Configuration
PROXY_HTTP="http://172.16.21.5:7890"
PROXY_HTTPS="http://172.16.21.5:7890"
NO_PROXY="127.0.0.1,localhost,reg.smvm.cn"
DOCKERFILE="Dockerfile.1.91-cross-aarch64-linux-gnu.fixed"
IMAGE_NAME="rust-cross-aarch64:1.91"

echo "Building Docker image with proxy settings..."
echo "HTTP_PROXY: $PROXY_HTTP"
echo "HTTPS_PROXY: $PROXY_HTTPS"
echo "NO_PROXY: $NO_PROXY"
echo ""

docker build \
  --build-arg HTTP_PROXY="$PROXY_HTTP" \
  --build-arg HTTPS_PROXY="$PROXY_HTTPS" \
  --build-arg http_proxy="$PROXY_HTTP" \
  --build-arg https_proxy="$PROXY_HTTPS" \
  --build-arg NO_PROXY="$NO_PROXY" \
  --build-arg no_proxy="$NO_PROXY" \
  --progress=plain \
  --no-cache \
  -f "$DOCKERFILE" \
  -t "$IMAGE_NAME" \
  . "$@"

echo ""
echo "Build completed successfully!"
echo "Image: $IMAGE_NAME"
