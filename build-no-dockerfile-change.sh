#!/bin/bash
# Docker 构建脚本 - 不修改 Dockerfile
# 通过构建参数传递代理配置

set -e

# 配置参数
PROXY_HTTP="http://172.16.21.5:7890"
PROXY_HTTPS="http://172.16.21.5:7890"
NO_PROXY="127.0.0.1,localhost,reg.smvm.cn"
DOCKERFILE="${1:-Dockerfile.1.91-cross-aarch64-linux-gnu}"
IMAGE_NAME="${2:-rust-cross-aarch64:1.91}"

echo "========================================"
echo "Docker 构建 - 不修改 Dockerfile"
echo "========================================"
echo "Dockerfile: $DOCKERFILE"
echo "Image Name: $IMAGE_NAME"
echo "HTTP Proxy: $PROXY_HTTP"
echo "HTTPS Proxy: $PROXY_HTTPS"
echo "NO_PROXY: $NO_PROXY"
echo "========================================"
echo ""

# 检查 Dockerfile 是否存在
if [ ! -f "$DOCKERFILE" ]; then
    echo "错误: Dockerfile '$DOCKERFILE' 不存在！"
    echo ""
    echo "用法: $0 [Dockerfile路径] [镜像名称]"
    echo "示例: $0 Dockerfile.1.91-cross-aarch64-linux-gnu rust-cross:1.91"
    exit 1
fi

echo "开始构建..."
echo ""

# 执行构建
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
  .

BUILD_STATUS=$?

echo ""
echo "========================================"
if [ $BUILD_STATUS -eq 0 ]; then
    echo "✓ 构建成功！"
    echo "镜像: $IMAGE_NAME"
    echo ""
    echo "运行镜像："
    echo "  docker run -it $IMAGE_NAME bash"
else
    echo "✗ 构建失败！"
    echo ""
    echo "故障排查建议："
    echo "1. 检查代理是否可用："
    echo "   curl -x $PROXY_HTTP http://archive.ubuntu.com"
    echo ""
    echo "2. 检查 Docker 配置："
    echo "   ./diagnose-proxy.sh"
    echo ""
    echo "3. 尝试配置 BuildKit 代理："
    echo "   ./setup-docker-proxy.sh"
fi
echo "========================================"

exit $BUILD_STATUS
