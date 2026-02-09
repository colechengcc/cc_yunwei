# 快速答案：为什么失败？为什么出现 21.69？

## 失败原因

你的 Docker 构建失败是因为：

**容器内的 apt 命令使用了错误的代理 `172.16.21.69:7897`，这个代理返回 502 Bad Gateway 错误。**

错误信息：
```
Err:3 http://archive.archive.ubuntu.com/ubuntu focal-updates InRelease
  502  Bad Gateway [IP: 172.16.21.69 7897]
```

## 为什么会出现 172.16.21.69？

虽然你配置 Docker 使用 `172.16.21.5:7890`，但是：

1. **Docker 守护进程的代理配置不会自动传递给构建中的容器**
   - Docker 守护进程代理：只用于 Docker 拉取镜像
   - 容器内的命令（apt、curl）：需要单独配置代理

2. **旧的代理配置残留**
   - 在你的 `/etc/profile` 中发现了注释掉的旧配置：
     ```bash
     #export https_proxy=http://172.16.21.69:7897 http_proxy=http://172.16.21.69:7897
     ```
   - 这个旧代理可能在以下地方残留：
     - 基础镜像的 APT 配置文件
     - Docker 构建缓存
     - 基础镜像的环境变量

## 解决方法

### 最快的解决方案：

在你的 Dockerfile **开头**添加这些行：

```dockerfile
FROM ubuntu:20.04 as base

# 强制使用正确的代理
ENV HTTP_PROXY=http://172.16.21.5:7890
ENV HTTPS_PROXY=http://172.16.21.5:7890
ENV http_proxy=http://172.16.21.5:7890
ENV https_proxy=http://172.16.21.5:7890

# 清除旧的 APT 代理配置
RUN rm -f /etc/apt/apt.conf.d/*proxy* || true

# 显式配置 APT 使用正确的代理
RUN echo "Acquire::http::Proxy \"http://172.16.21.5:7890\";" > /etc/apt/apt.conf.d/01proxy \
    && echo "Acquire::https::Proxy \"http://172.16.21.5:7890\";" >> /etc/apt/apt.conf.d/01proxy

# 然后继续你的原始 RUN 命令
RUN apt update && apt -y install ...
```

### 或者使用构建参数：

```bash
docker build \
  --build-arg HTTP_PROXY=http://172.16.21.5:7890 \
  --build-arg HTTPS_PROXY=http://172.16.21.5:7890 \
  --build-arg http_proxy=http://172.16.21.5:7890 \
  --build-arg https_proxy=http://172.16.21.5:7890 \
  --no-cache \
  -f Dockerfile.1.91-cross-aarch64-linux-gnu \
  .
```

## 总结

| 代理地址 | 配置位置 | 状态 | 说明 |
|---------|---------|------|------|
| 172.16.21.5:7890 | Docker 守护进程 | ✓ 正常 | 你当前的代理 |
| 172.16.21.69:7897 | 容器内 APT | ✗ 502错误 | 旧的代理配置 |

**问题根源**：Docker 守护进程的代理配置不会传递给容器内的进程，导致 apt 使用了基础镜像或缓存中的旧代理配置。

**解决方案**：在 Dockerfile 中显式设置环境变量和 APT 代理配置，覆盖任何旧的设置。

---

参考 `README.md` 和 `PROXY_ISSUE_ANALYSIS.md` 了解更多详细信息和其他解决方案。
