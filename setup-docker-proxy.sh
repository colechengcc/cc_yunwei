#!/bin/bash
# 配置 Docker BuildKit 代理 - 永久生效，不需要修改 Dockerfile

set -e

PROXY_HTTP="http://172.16.21.5:7890"
PROXY_HTTPS="http://172.16.21.5:7890"
NO_PROXY="127.0.0.1,localhost,reg.smvm.cn"

echo "========================================"
echo "配置 Docker BuildKit 代理"
echo "========================================"
echo "HTTP Proxy: $PROXY_HTTP"
echo "HTTPS Proxy: $PROXY_HTTPS"
echo "NO_PROXY: $NO_PROXY"
echo "========================================"
echo ""

# 创建 .docker 目录
mkdir -p ~/.docker

# 备份现有配置
if [ -f ~/.docker/config.json ]; then
    echo "发现现有配置，创建备份..."
    cp ~/.docker/config.json ~/.docker/config.json.backup.$(date +%Y%m%d_%H%M%S)
    echo "✓ 备份已保存到 ~/.docker/config.json.backup.*"
    echo ""
fi

# 检查是否已有 config.json
if [ -f ~/.docker/config.json ]; then
    echo "合并代理配置到现有文件..."
    # 使用 jq 合并（如果有的话）
    if command -v jq &> /dev/null; then
        jq --arg hp "$PROXY_HTTP" --arg hs "$PROXY_HTTPS" --arg np "$NO_PROXY" \
           '.proxies.default = {"httpProxy": $hp, "httpsProxy": $hs, "noProxy": $np}' \
           ~/.docker/config.json > ~/.docker/config.json.tmp
        mv ~/.docker/config.json.tmp ~/.docker/config.json
        echo "✓ 使用 jq 合并配置"
    else
        echo "警告: 未找到 jq 命令，将覆盖配置文件"
        echo "如需保留其他配置，请手动编辑 ~/.docker/config.json"
        cat > ~/.docker/config.json << EOF
{
  "proxies": {
    "default": {
      "httpProxy": "$PROXY_HTTP",
      "httpsProxy": "$PROXY_HTTPS",
      "noProxy": "$NO_PROXY"
    }
  }
}
EOF
    fi
else
    echo "创建新的配置文件..."
    cat > ~/.docker/config.json << EOF
{
  "proxies": {
    "default": {
      "httpProxy": "$PROXY_HTTP",
      "httpsProxy": "$PROXY_HTTPS",
      "noProxy": "$NO_PROXY"
    }
  }
}
EOF
fi

echo ""
echo "✓ Docker 配置已更新"
echo ""
echo "配置文件位置: ~/.docker/config.json"
echo ""
cat ~/.docker/config.json
echo ""

# 询问是否重启 Docker
echo "========================================"
echo "是否重启 Docker 服务？(建议重启)"
echo "========================================"
read -p "重启 Docker? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "重启 Docker..."
    if [ "$EUID" -ne 0 ]; then
        sudo systemctl restart docker
    else
        systemctl restart docker
    fi
    echo "✓ Docker 已重启"
else
    echo "跳过重启。注意：某些配置可能需要重启 Docker 才能生效。"
    echo "手动重启命令: sudo systemctl restart docker"
fi

echo ""
echo "========================================"
echo "配置完成！"
echo "========================================"
echo ""
echo "现在可以直接构建，无需修改 Dockerfile："
echo "  docker build -f Dockerfile.1.91-cross-aarch64-linux-gnu -t your-image ."
echo ""
echo "或使用构建脚本："
echo "  ./build-no-dockerfile-change.sh"
echo ""
