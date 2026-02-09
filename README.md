# Docker Build Proxy Issue - Solution Guide

## 问题分析 (Problem Analysis)

你的 Docker 构建失败是因为容器内的 `apt` 命令尝试使用代理 `172.16.21.69:7897`（返回 502 错误），而不是你配置的 `172.16.21.5:7890`。

**关键发现：**
- Docker 守护进程代理配置：`172.16.21.5:7890` ✓
- apt 实际使用的代理：`172.16.21.69:7897` ✗ (502 Bad Gateway)

## 为什么会出现 172.16.21.69？ (Why 172.16.21.69 appears?)

Docker 守护进程的代理设置**只对 Docker 本身有效**（拉取镜像时），**不会自动传递给构建过程中的容器**。

可能的原因：
1. 基础镜像中内置了旧的 APT 代理配置
2. 构建缓存层包含了旧的代理设置
3. 环境变量从宿主机继承

## 解决方案 (Solutions)

### 方案 1：使用修复后的 Dockerfile（推荐）

使用提供的 `Dockerfile.1.91-cross-aarch64-linux-gnu.fixed`：

```bash
chmod +x build-with-proxy.sh
./build-with-proxy.sh
```

### 方案 2：命令行传递代理参数

```bash
docker build \
  --build-arg HTTP_PROXY=http://172.16.21.5:7890 \
  --build-arg HTTPS_PROXY=http://172.16.21.5:7890 \
  --build-arg http_proxy=http://172.16.21.5:7890 \
  --build-arg https_proxy=http://172.16.21.5:7890 \
  --build-arg NO_PROXY="127.0.0.1,localhost,reg.smvm.cn" \
  --no-cache \
  -f Dockerfile.1.91-cross-aarch64-linux-gnu \
  .
```

### 方案 3：配置 Docker BuildKit 代理

复制提供的配置文件：

```bash
mkdir -p ~/.docker
cp docker-config-proxy.json ~/.docker/config.json
systemctl restart docker
```

### 方案 4：诊断当前配置

运行诊断脚本查看所有代理配置：

```bash
chmod +x diagnose-proxy.sh
./diagnose-proxy.sh
```

## 文件说明 (Files)

- `PROXY_ISSUE_ANALYSIS.md` - 详细的问题分析文档
- `Dockerfile.1.91-cross-aarch64-linux-gnu.fixed` - 修复后的 Dockerfile
- `build-with-proxy.sh` - 自动构建脚本（包含正确的代理配置）
- `diagnose-proxy.sh` - 诊断脚本，检查所有代理配置
- `docker-config-proxy.json` - Docker BuildKit 代理配置示例

## 快速修复步骤 (Quick Fix)

1. **检查代理是否可用：**
   ```bash
   curl -x http://172.16.21.5:7890 http://archive.ubuntu.com
   ```

2. **使用修复后的构建脚本：**
   ```bash
   chmod +x build-with-proxy.sh
   ./build-with-proxy.sh
   ```

3. **如果仍然失败，运行诊断：**
   ```bash
   chmod +x diagnose-proxy.sh
   ./diagnose-proxy.sh
   ```

## Dockerfile 关键修复点

在原 Dockerfile 的 RUN 命令之前添加：

```dockerfile
# 设置代理环境变量
ENV HTTP_PROXY=http://172.16.21.5:7890
ENV HTTPS_PROXY=http://172.16.21.5:7890
ENV http_proxy=http://172.16.21.5:7890
ENV https_proxy=http://172.16.21.5:7890

# 清除旧的 APT 代理配置
RUN rm -f /etc/apt/apt.conf.d/proxy.conf /etc/apt/apt.conf.d/*proxy* || true

# 显式配置 APT 代理
RUN echo "Acquire::http::Proxy \"http://172.16.21.5:7890\";" > /etc/apt/apt.conf.d/01proxy \
    && echo "Acquire::https::Proxy \"http://172.16.21.5:7890\";" >> /etc/apt/apt.conf.d/01proxy
```

## 常见问题 (FAQ)

**Q: 为什么 Docker 守护进程的代理配置不起作用？**  
A: Docker 守护进程代理只用于拉取镜像，不会自动传递给容器内的命令。

**Q: 如何确认代理是否正常工作？**  
A: 运行 `curl -x http://172.16.21.5:7890 http://archive.ubuntu.com` 测试。

**Q: 是否需要重启 Docker？**  
A: 修改 `~/.docker/config.json` 后需要重启，但使用 `--build-arg` 不需要。

**Q: 如何永久解决这个问题？**  
A: 推荐同时使用 Dockerfile 中的 ENV 设置和 ~/.docker/config.json 配置。

## 更多信息

查看 `PROXY_ISSUE_ANALYSIS.md` 了解详细的技术分析和多种解决方案。
