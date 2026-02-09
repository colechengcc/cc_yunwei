#!/bin/bash
# 测试代理配置是否正常工作

PROXY_HTTP="http://172.16.21.5:7890"
PROXY_OLD="http://172.16.21.69:7897"

echo "========================================"
echo "测试代理连接"
echo "========================================"
echo ""

echo "1. 测试当前代理 (172.16.21.5:7890)"
echo "-----------------------------------"
if curl -x "$PROXY_HTTP" -I -s -m 10 http://archive.ubuntu.com 2>&1 | head -5; then
    echo "✓ 当前代理可用"
else
    echo "✗ 当前代理不可用"
fi
echo ""

echo "2. 测试旧代理 (172.16.21.69:7897)"
echo "-----------------------------------"
if curl -x "$PROXY_OLD" -I -s -m 10 http://archive.ubuntu.com 2>&1 | head -5; then
    echo "✓ 旧代理仍然可用"
else
    echo "✗ 旧代理不可用（这就是为什么构建失败）"
fi
echo ""

echo "3. 测试直连（无代理）"
echo "-----------------------------------"
if curl -I -s -m 10 http://archive.ubuntu.com 2>&1 | head -5; then
    echo "✓ 直连可用"
else
    echo "✗ 直连不可用"
fi
echo ""

echo "4. 测试 HTTPS 站点"
echo "-----------------------------------"
if curl -x "$PROXY_HTTP" -I -s -m 10 https://sh.rustup.rs 2>&1 | head -5; then
    echo "✓ HTTPS 代理可用"
else
    echo "✗ HTTPS 代理不可用"
fi
echo ""

echo "========================================"
echo "Docker 代理配置检查"
echo "========================================"
echo ""

echo "Docker 守护进程代理:"
systemctl show docker | grep -i Environment | grep -i proxy || echo "未配置"
echo ""

echo "Docker Info 代理:"
docker info 2>/dev/null | grep -i proxy || echo "未显示代理"
echo ""

echo "Docker 配置文件 (~/.docker/config.json):"
if [ -f ~/.docker/config.json ]; then
    cat ~/.docker/config.json
else
    echo "文件不存在"
fi
echo ""

echo "========================================"
echo "测试 Docker 构建时代理"
echo "========================================"
echo ""

# 创建临时测试 Dockerfile
cat > /tmp/test-proxy.dockerfile << 'EOF'
FROM ubuntu:20.04
RUN echo "=== 环境变量 ===" && \
    env | grep -i proxy || echo "无代理环境变量" && \
    echo "=== APT 配置 ===" && \
    cat /etc/apt/apt.conf.d/* 2>/dev/null | grep -i proxy || echo "无 APT 代理配置" && \
    echo "=== 测试 apt update ===" && \
    apt update
EOF

echo "运行测试构建（带代理参数）..."
docker build \
  --build-arg HTTP_PROXY="$PROXY_HTTP" \
  --build-arg HTTPS_PROXY="$PROXY_HTTP" \
  --build-arg http_proxy="$PROXY_HTTP" \
  --build-arg https_proxy="$PROXY_HTTP" \
  --progress=plain \
  --no-cache \
  -f /tmp/test-proxy.dockerfile \
  -t test-proxy \
  /tmp 2>&1 | tail -30

TEST_STATUS=$?
echo ""

if [ $TEST_STATUS -eq 0 ]; then
    echo "✓ 测试构建成功！代理配置正确"
else
    echo "✗ 测试构建失败！需要进一步检查"
fi
echo ""

# 清理
rm -f /tmp/test-proxy.dockerfile

echo "========================================"
echo "总结"
echo "========================================"
echo ""
if [ $TEST_STATUS -eq 0 ]; then
    echo "✓ 代理配置正常，可以开始构建"
    echo ""
    echo "使用以下命令构建："
    echo "  ./build-no-dockerfile-change.sh Dockerfile.1.91-cross-aarch64-linux-gnu"
else
    echo "✗ 代理配置有问题，建议："
    echo ""
    echo "1. 确认代理服务器可用："
    echo "   curl -x $PROXY_HTTP http://archive.ubuntu.com"
    echo ""
    echo "2. 配置 Docker BuildKit 代理："
    echo "   ./setup-docker-proxy.sh"
    echo ""
    echo "3. 检查防火墙和网络设置"
fi
echo ""
