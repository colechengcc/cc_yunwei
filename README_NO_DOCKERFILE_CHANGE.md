# 不修改 Dockerfile 的解决方案

## 快速开始

### 方法 1：一键测试和构建（推荐）

```bash
# 1. 测试代理配置
./test-proxy.sh

# 2. 如果测试通过，直接构建
./build-no-dockerfile-change.sh Dockerfile.1.91-cross-aarch64-linux-gnu rust-cross:1.91
```

### 方法 2：永久配置（一次配置，永久生效）

```bash
# 1. 配置 Docker BuildKit 代理
./setup-docker-proxy.sh

# 2. 之后任何构建都会自动使用代理
docker build -f Dockerfile.1.91-cross-aarch64-linux-gnu -t rust-cross:1.91 .
```

---

## 三个核心脚本

### 1. `test-proxy.sh` - 诊断工具
测试代理是否可用，检查所有配置

```bash
./test-proxy.sh
```

**作用：**
- 测试当前代理 172.16.21.5:7890 是否可用
- 测试旧代理 172.16.21.69:7897 是否还在工作
- 检查 Docker 的所有代理配置
- 运行测试构建验证配置

### 2. `build-no-dockerfile-change.sh` - 构建工具
不修改 Dockerfile，通过参数传递代理配置

```bash
./build-no-dockerfile-change.sh [Dockerfile路径] [镜像名称]

# 示例
./build-no-dockerfile-change.sh Dockerfile.1.91-cross-aarch64-linux-gnu rust-cross:1.91
```

**作用：**
- 自动添加所有必要的 `--build-arg` 参数
- 使用正确的代理 172.16.21.5:7890
- 清除构建缓存避免使用旧配置

### 3. `setup-docker-proxy.sh` - 永久配置工具
配置 Docker BuildKit，之后所有构建自动使用代理

```bash
./setup-docker-proxy.sh
```

**作用：**
- 创建或更新 `~/.docker/config.json`
- 配置 BuildKit 代理（永久生效）
- 自动备份现有配置
- 可选重启 Docker 服务

---

## 解决方案对比

| 方案 | 是否修改 Dockerfile | 是否永久生效 | 适用场景 |
|------|-------------------|------------|---------|
| build-no-dockerfile-change.sh | ❌ 否 | ❌ 每次构建 | 快速测试 |
| setup-docker-proxy.sh | ❌ 否 | ✅ 永久 | 长期使用 |
| 修改 Dockerfile | ✅ 是 | ✅ 永久 | 代码固化 |

---

## 推荐流程

### 首次使用

```bash
# 步骤 1：测试当前环境
./test-proxy.sh

# 步骤 2：如果测试失败，配置 Docker
./setup-docker-proxy.sh

# 步骤 3：重新测试
./test-proxy.sh

# 步骤 4：开始构建
./build-no-dockerfile-change.sh Dockerfile.1.91-cross-aarch64-linux-gnu rust-cross:1.91
```

### 日常使用

**如果已经运行过 `setup-docker-proxy.sh`：**

```bash
# 直接构建，不需要任何额外参数
docker build -f Dockerfile.1.91-cross-aarch64-linux-gnu -t rust-cross:1.91 .
```

**如果没有配置，每次都需要：**

```bash
# 使用脚本（推荐）
./build-no-dockerfile-change.sh Dockerfile.1.91-cross-aarch64-linux-gnu rust-cross:1.91

# 或手动添加参数
docker build \
  --build-arg HTTP_PROXY=http://172.16.21.5:7890 \
  --build-arg HTTPS_PROXY=http://172.16.21.5:7890 \
  --build-arg http_proxy=http://172.16.21.5:7890 \
  --build-arg https_proxy=http://172.16.21.5:7890 \
  --no-cache \
  -f Dockerfile.1.91-cross-aarch64-linux-gnu \
  -t rust-cross:1.91 \
  .
```

---

## 原理说明

### 为什么不修改 Dockerfile 也能解决？

1. **--build-arg 传递环境变量**
   - 构建时注入环境变量
   - apt、curl 等命令会读取这些变量
   - 覆盖任何现有的代理配置

2. **~/.docker/config.json 配置 BuildKit**
   - BuildKit 是 Docker 的新构建引擎
   - 读取用户配置文件中的代理设置
   - 自动应用到所有构建

3. **为什么两个方案都需要？**
   - BuildKit 代理：控制 BuildKit 自己的网络请求
   - --build-arg：控制容器内命令的网络请求
   - 最佳实践：两个都配置

---

## 故障排查

### 问题 1：构建仍然使用旧代理

**症状：**
```
Err:3 http://archive.ubuntu.com/ubuntu focal-updates InRelease
  502  Bad Gateway [IP: 172.16.21.69 7897]
```

**解决：**
```bash
# 清除所有缓存
docker builder prune -af

# 使用 --no-cache 重新构建
./build-no-dockerfile-change.sh Dockerfile.1.91-cross-aarch64-linux-gnu rust-cross:1.91
```

### 问题 2：代理无法连接

**检查：**
```bash
# 测试代理
curl -x http://172.16.21.5:7890 http://archive.ubuntu.com

# 如果失败，检查代理服务
telnet 172.16.21.5 7890
```

### 问题 3：BuildKit 配置不生效

**解决：**
```bash
# 重启 Docker
sudo systemctl restart docker

# 验证配置
cat ~/.docker/config.json

# 检查 Docker 是否使用 BuildKit
docker info | grep BuildKit
```

### 问题 4：权限问题

**症状：**
```
permission denied while trying to connect to the Docker daemon socket
```

**解决：**
```bash
# 添加当前用户到 docker 组
sudo usermod -aG docker $USER

# 重新登录或
newgrp docker
```

---

## 技术细节

### --build-arg 的作用域

```dockerfile
FROM ubuntu:20.04

# ARG 必须在 FROM 之后声明才能使用 --build-arg
ARG HTTP_PROXY
ARG HTTPS_PROXY

# 转换为 ENV 在整个构建过程中可用
ENV HTTP_PROXY=$HTTP_PROXY
ENV HTTPS_PROXY=$HTTPS_PROXY

RUN apt update  # 会使用上面的代理
```

**注意：** 即使 Dockerfile 中没有 ARG 声明，--build-arg 设置的变量也会作为环境变量在构建过程中可用。

### BuildKit 配置优先级

1. `~/.docker/config.json` (用户配置，优先级最高)
2. `/etc/docker/daemon.json` (系统配置)
3. 环境变量
4. 默认值

---

## 常见问题 FAQ

**Q: 为什么要设置 HTTP_PROXY 和 http_proxy 两个？**  
A: 不同程序对环境变量大小写的处理不同。设置两个确保兼容性。

**Q: NO_PROXY 有什么用？**  
A: 指定哪些地址不走代理，比如本地地址和内网地址。

**Q: --no-cache 是必须的吗？**  
A: 首次构建时建议使用，确保不使用旧的缓存层。成功后可以去掉加快构建。

**Q: 配置后是否影响 docker pull？**  
A: 不会。docker pull 使用 Docker 守护进程的代理配置（/etc/systemd/system/docker.service.d/proxy.conf）。

**Q: 可以为不同的构建使用不同的代理吗？**  
A: 可以。使用 --build-arg 时可以为每个构建指定不同的代理。

---

## 查看更多

- `NO_DOCKERFILE_CHANGE_SOLUTION.md` - 详细的所有解决方案
- `PROXY_ISSUE_ANALYSIS.md` - 问题根源分析
- `QUICK_ANSWER.md` - 快速答案

---

## 总结

✅ **最简单的方法：**
```bash
./build-no-dockerfile-change.sh Dockerfile.1.91-cross-aarch64-linux-gnu rust-cross:1.91
```

✅ **一劳永逸的方法：**
```bash
./setup-docker-proxy.sh
# 之后所有构建自动使用代理
```

✅ **诊断工具：**
```bash
./test-proxy.sh
```

这三个脚本解决所有问题，无需修改 Dockerfile！
