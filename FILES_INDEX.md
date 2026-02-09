# 文件索引 / Files Index

## 🚀 快速开始（从这里开始）

| 文件 | 说明 | 用途 |
|------|------|------|
| **使用指南.md** | 中文完整指南 | 👈 从这里开始！ |
| **README_NO_DOCKERFILE_CHANGE.md** | 不修改 Dockerfile 的方案 | 详细使用说明 |
| **QUICK_ANSWER.md** | 快速答案 | 3分钟了解问题和解决方案 |

---

## 🛠️ 可执行脚本（直接运行）

### 1. test-proxy.sh ⭐ 诊断工具
```bash
./test-proxy.sh
```
**作用：**
- 测试所有代理是否可用
- 检查 Docker 配置
- 运行测试构建
- 识别问题所在

**何时使用：** 首次使用、遇到问题时

---

### 2. build-no-dockerfile-change.sh ⭐⭐ 构建工具
```bash
./build-no-dockerfile-change.sh Dockerfile.1.91-cross-aarch64-linux-gnu rust-cross:1.91
```
**作用：**
- 自动添加代理参数构建
- 不修改 Dockerfile
- 适合临时构建

**何时使用：** 每次构建时（如果没有永久配置）

---

### 3. setup-docker-proxy.sh ⭐⭐⭐ 永久配置
```bash
./setup-docker-proxy.sh
```
**作用：**
- 配置 Docker BuildKit 代理
- 一次配置，永久生效
- 之后无需任何参数

**何时使用：** 首次设置（推荐）

---

## 📖 文档文件

### 主要文档

| 文件 | 语言 | 内容 | 适合人群 |
|------|------|------|---------|
| **使用指南.md** | 中文 | 完整的使用指南 | 所有人 |
| **QUICK_ANSWER.md** | 中文 | 为什么失败？为什么21.69？ | 想快速了解的人 |
| **README_NO_DOCKERFILE_CHANGE.md** | 中文 | 不修改Dockerfile的完整方案 | 深度使用者 |
| **NO_DOCKERFILE_CHANGE_SOLUTION.md** | 英文 | 6种解决方案详解 | 技术人员 |
| **PROXY_ISSUE_ANALYSIS.md** | 英文 | 问题根源分析 | 想深入了解的人 |
| **README.md** | 中英 | 原始完整文档 | 技术人员 |

### 其他文件

| 文件 | 说明 |
|------|------|
| **Dockerfile.1.91-cross-aarch64-linux-gnu.fixed** | 修复后的 Dockerfile（参考） |
| **docker-config-proxy.json** | Docker 配置模板 |
| **diagnose-proxy.sh** | 旧的诊断脚本（被 test-proxy.sh 替代） |
| **build-with-proxy.sh** | 旧的构建脚本（被 build-no-dockerfile-change.sh 替代） |

---

## 🎯 根据你的需求选择

### 我想快速了解问题
→ 阅读 **QUICK_ANSWER.md**

### 我想立即解决问题
→ 运行 `./build-no-dockerfile-change.sh`

### 我想永久配置
→ 运行 `./setup-docker-proxy.sh`

### 我想了解所有方案
→ 阅读 **使用指南.md** 或 **README_NO_DOCKERFILE_CHANGE.md**

### 我想深入了解原理
→ 阅读 **PROXY_ISSUE_ANALYSIS.md**

### 我遇到问题需要诊断
→ 运行 `./test-proxy.sh`

---

## 📋 典型使用流程

### 流程 1：快速测试（不配置系统）

```bash
# 步骤 1：诊断
./test-proxy.sh

# 步骤 2：构建
./build-no-dockerfile-change.sh Dockerfile.1.91-cross-aarch64-linux-gnu rust-cross:1.91
```

### 流程 2：永久配置（推荐）

```bash
# 步骤 1：诊断
./test-proxy.sh

# 步骤 2：永久配置
./setup-docker-proxy.sh

# 步骤 3：之后正常构建
docker build -f Dockerfile.1.91-cross-aarch64-linux-gnu -t rust-cross:1.91 .
```

### 流程 3：故障排查

```bash
# 步骤 1：运行诊断
./test-proxy.sh

# 步骤 2：根据输出找到问题

# 步骤 3：阅读相关文档
# - 如果代理不通 → PROXY_ISSUE_ANALYSIS.md
# - 如果配置问题 → README_NO_DOCKERFILE_CHANGE.md
```

---

## 🔧 命令速查

### 一键命令

```bash
# 测试环境
./test-proxy.sh

# 快速构建
./build-no-dockerfile-change.sh Dockerfile.1.91-cross-aarch64-linux-gnu rust-cross:1.91

# 永久配置
./setup-docker-proxy.sh
```

### 手动命令

```bash
# 带参数构建
docker build \
  --build-arg HTTP_PROXY=http://172.16.21.5:7890 \
  --build-arg HTTPS_PROXY=http://172.16.21.5:7890 \
  --build-arg http_proxy=http://172.16.21.5:7890 \
  --build-arg https_proxy=http://172.16.21.5:7890 \
  --no-cache \
  -f Dockerfile.1.91-cross-aarch64-linux-gnu \
  -t rust-cross:1.91 \
  .

# 测试代理
curl -x http://172.16.21.5:7890 http://archive.ubuntu.com

# 清除缓存
docker builder prune -af
```

---

## 🎁 推荐阅读顺序

1. **使用指南.md** - 了解问题和解决方案
2. 运行 **test-proxy.sh** - 诊断当前环境
3. 运行 **setup-docker-proxy.sh** 或 **build-no-dockerfile-change.sh**
4. 如有问题，查看 **README_NO_DOCKERFILE_CHANGE.md**

---

## 📞 问题对照表

| 你的问题 | 查看文件 | 运行脚本 |
|---------|---------|---------|
| 为什么构建失败？ | QUICK_ANSWER.md | test-proxy.sh |
| 为什么是21.69而不是21.5？ | QUICK_ANSWER.md | - |
| 如何不改Dockerfile解决？ | 使用指南.md | build-no-dockerfile-change.sh |
| 如何永久配置？ | README_NO_DOCKERFILE_CHANGE.md | setup-docker-proxy.sh |
| 有哪些解决方案？ | NO_DOCKERFILE_CHANGE_SOLUTION.md | - |
| 如何诊断问题？ | - | test-proxy.sh |
| 代理配置原理？ | PROXY_ISSUE_ANALYSIS.md | - |

---

## 💡 小贴士

1. **首次使用必看：** 使用指南.md
2. **最常用脚本：** build-no-dockerfile-change.sh
3. **一劳永逸：** setup-docker-proxy.sh
4. **遇到问题：** test-proxy.sh + README_NO_DOCKERFILE_CHANGE.md

---

最后更新：2026-02-09
