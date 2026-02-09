#!/bin/bash
# Diagnostic script to check proxy configuration

echo "=== Docker Daemon Proxy Settings ==="
systemctl show docker | grep -i proxy || echo "No proxy settings found"
echo ""

echo "=== Docker Daemon Config File ==="
cat /etc/systemd/system/docker.service.d/proxy.conf 2>/dev/null || echo "File not found"
echo ""

echo "=== Docker Info Proxy ==="
docker info | grep -i proxy
echo ""

echo "=== Docker Config JSON ==="
cat ~/.docker/config.json 2>/dev/null || echo "File not found"
echo ""

echo "=== System Environment Proxy ==="
env | grep -i proxy || echo "No proxy environment variables"
echo ""

echo "=== Testing Proxies ==="
echo "Testing 172.16.21.5:7890..."
curl -x http://172.16.21.5:7890 -I -s -m 5 http://archive.ubuntu.com 2>&1 | head -3
echo ""

echo "Testing 172.16.21.69:7897..."
curl -x http://172.16.21.69:7897 -I -s -m 5 http://archive.ubuntu.com 2>&1 | head -3
echo ""

echo "=== Searching for Old Proxy References ==="
echo "Checking /etc for 172.16.21.69..."
grep -r "172.16.21.69" /etc/ 2>/dev/null || echo "Not found in /etc"
echo ""

echo "=== Docker BuildKit Config ==="
cat /etc/docker/daemon.json 2>/dev/null
echo ""
