# 不修改 Dockerfile 的解决方案

## 方案 1：使用 --build-arg（最简单，推荐）

直接在构建命令中传递代理参数：

```bash
docker build \
  --build-arg HTTP_PROXY=http://172.16.21.5:7890 \
  --build-arg HTTPS_PROXY=http://172.16.21.5:7890 \
  --build-arg http_proxy=http://172.16.21.5:7890 \
  --build-arg https_proxy=http://172.16.21.5:7890 \
  --build-arg NO_PROXY="127.0.0.1,localhost,reg.smvm.cn" \
  --build-arg no_proxy="127.0.0.1,localhost,reg.smvm.cn" \
  --no-cache \
  -f Dockerfile.1.91-cross-aarch64-linux-gnu \
  -t your-image-name \
  .
```

**说明**：
- `--build-arg` 会将变量注入到构建环境中
- 需要同时设置大小写版本（HTTP_PROXY 和 http_proxy）
- `--no-cache` 确保不使用旧的缓存层

---

## 方案 2：配置 Docker BuildKit（永久生效）

### 步骤 1：创建或编辑 Docker 配置文件

```bash
mkdir -p ~/.docker
cat > ~/.docker/config.json << 'EOF'
{
  "proxies": {
    "default": {
      "httpProxy": "http://172.16.21.5:7890",
      "httpsProxy": "http://172.16.21.5:7890",
      "noProxy": "127.0.0.1,localhost,reg.smvm.cn"
    }
  }
}
EOF
```

如果文件已存在，需要合并内容：

```bash
# 备份现有配置
cp ~/.docker/config.json ~/.docker/config.json.backup

# 编辑添加 proxies 部分
vi ~/.docker/config.json
```

### 步骤 2：重启 Docker（可选，建议重启）

```bash
systemctl restart docker
```

### 步骤 3：正常构建

```bash
docker build -f Dockerfile.1.91-cross-aarch64-linux-gnu -t your-image-name .
```

---

## 方案 3：修改 Docker 守护进程配置（系统级）

### 编辑 /etc/docker/daemon.json

```bash
cat > /etc/docker/daemon.json << 'EOF'
{
  "features": {
    "buildkit": true,
    "containerd-imagestore": true
  },
  "proxies": {
    "http-proxy": "http://172.16.21.5:7890",
    "https-proxy": "http://172.16.21.5:7890",
    "no-proxy": "127.0.0.1,localhost,reg.smvm.cn"
  }
}
EOF
```

### 重启 Docker

```bash
systemctl daemon-reload
systemctl restart docker
```

**注意**：这个配置格式可能因 Docker 版本而异，BuildKit 代理配置更推荐使用方案 2。

---

## 方案 4：使用 docker buildx（BuildKit 高级功能）

### 创建自定义 builder

```bash
docker buildx create --name mybuilder \
  --driver docker-container \
  --driver-opt env.HTTP_PROXY=http://172.16.21.5:7890 \
  --driver-opt env.HTTPS_PROXY=http://172.16.21.5:7890 \
  --use
```

### 使用该 builder 构建

```bash
docker buildx build \
  --builder mybuilder \
  -f Dockerfile.1.91-cross-aarch64-linux-gnu \
  -t your-image-name \
  --load \
  .
```

---

## 方案 5：创建构建配置文件（推荐用于团队）

### 创建 buildkit.toml 配置文件

```bash
cat > buildkit.toml << 'EOF'
[worker.oci]
  [[worker.oci.env]]
    name = "HTTP_PROXY"
    value = "http://172.16.21.5:7890"
  [[worker.oci.env]]
    name = "HTTPS_PROXY"
    value = "http://172.16.21.5:7890"
  [[worker.oci.env]]
    name = "http_proxy"
    value = "http://172.16.21.5:7890"
  [[worker.oci.env]]
    name = "https_proxy"
    value = "http://172.16.21.5:7890"
  [[worker.oci.env]]
    name = "NO_PROXY"
    value = "127.0.0.1,localhost,reg.smvm.cn"
EOF
```

### 使用配置构建

```bash
docker buildx create --name proxy-builder \
  --driver docker-container \
  --config buildkit.toml \
  --use

docker buildx build \
  -f Dockerfile.1.91-cross-aarch64-linux-gnu \
  -t your-image-name \
  --load \
  .
```

---

## 方案 6：临时设置环境变量（仅当前会话）

```bash
export DOCKER_BUILDKIT=1
export BUILDKIT_PROGRESS=plain

# 设置构建时环境变量
docker build \
  --build-arg HTTP_PROXY=http://172.16.21.5:7890 \
  --build-arg HTTPS_PROXY=http://172.16.21.5:7890 \
  --build-arg http_proxy=http://172.16.21.5:7890 \
  --build-arg https_proxy=http://172.16.21.5:7890 \
  --network=host \
  -f Dockerfile.1.91-cross-aarch64-linux-gnu \
  -t your-image-name \
  .
```

---

## 推荐方案优先级

### 快速测试（一次性）
**→ 方案 1（--build-arg）** ⭐⭐⭐⭐⭐

### 长期使用（个人）
**→ 方案 2（~/.docker/config.json）** ⭐⭐⭐⭐⭐

### 团队/多机器
**→ 方案 5（buildkit.toml）** ⭐⭐⭐⭐

### 系统级配置
**→ 方案 3（/etc/docker/daemon.json）** ⭐⭐⭐

---

## 验证配置是否生效

### 测试构建时代理

创建测试 Dockerfile：

```dockerfile
FROM ubuntu:20.04
RUN echo "HTTP_PROXY=$HTTP_PROXY" && \
    echo "HTTPS_PROXY=$HTTPS_PROXY" && \
    env | grep -i proxy
```

构建测试：

```bash
docker build --build-arg HTTP_PROXY=http://172.16.21.5:7890 -f test.dockerfile .
```

---

## 针对你的具体情况

根据你的错误日志，最快的解决方法：

```bash
docker build \
  --build-arg HTTP_PROXY=http://172.16.21.5:7890 \
  --build-arg HTTPS_PROXY=http://172.16.21.5:7890 \
  --build-arg http_proxy=http://172.16.21.5:7890 \
  --build-arg https_proxy=http://172.16.21.5:7890 \
  --no-cache \
  -f Dockerfile.1.91-cross-aarch64-linux-gnu \
  -t rust-cross-aarch64:1.91 \
  .
```

如果这个方法不行，说明基础镜像内部有硬编码的代理配置，那就需要使用方案 2 + 方案 1 的组合。

---

## 排查旧代理来源

如果上述方法都不行，检查基础镜像：

```bash
# 拉取基础镜像
docker pull ubuntu:20.04

# 检查基础镜像的配置
docker run --rm ubuntu:20.04 cat /etc/apt/apt.conf.d/* 2>/dev/null || echo "No apt proxy config"
docker run --rm ubuntu:20.04 env | grep -i proxy
```

如果基础镜像有硬编码的代理，需要在构建时覆盖：

```bash
docker build \
  --build-arg HTTP_PROXY=http://172.16.21.5:7890 \
  --build-arg HTTPS_PROXY=http://172.16.21.5:7890 \
  --build-arg http_proxy=http://172.16.21.5:7890 \
  --build-arg https_proxy=http://172.16.21.5:7890 \
  --no-cache \
  --network=host \
  -f Dockerfile.1.91-cross-aarch64-linux-gnu \
  .
```
