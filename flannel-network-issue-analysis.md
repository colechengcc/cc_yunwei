# Kubernetes Flannel 网络问题分析

## 问题概述

从提供的日志可以看到，CoreDNS Pods 一直处于 `ContainerCreating` 状态，无法正常启动。

## 核心错误信息

```
Failed to create pod sandbox: rpc error: code = Unknown desc = failed to setup network for sandbox 
plugin type="flannel" failed (add): failed to load flannel 'subnet.env' file: 
open /run/flannel/subnet.env: no such file or directory
```

## 问题根因

**Flannel CNI 插件无法找到 `/run/flannel/subnet.env` 配置文件**

这个文件应该由 Flannel DaemonSet Pod 创建并维护，包含以下关键网络配置信息：
- FLANNEL_NETWORK：集群的 Pod 网络 CIDR
- FLANNEL_SUBNET：当前节点分配的子网
- FLANNEL_MTU：网络接口的 MTU 值
- FLANNEL_IPMASQ：是否启用 IP 伪装

## 可能的原因

### 1. Flannel DaemonSet 未安装或未运行
- Flannel 可能没有被正确部署到集群中
- Flannel Pod 可能因为某些原因未能启动

### 2. Flannel Pod 启动失败
- 镜像拉取失败
- 配置错误
- 权限问题

### 3. Flannel 与 kubeadm 初始化的 Pod CIDR 不匹配
- kubeadm init 时指定的 `--pod-network-cidr` 与 Flannel 配置不一致

## 诊断步骤

### 1. 检查 Flannel DaemonSet 是否存在
```bash
kubectl get ds -n kube-system | grep flannel
kubectl get pods -n kube-system | grep flannel
```

### 2. 如果 Flannel Pod 存在，查看其状态和日志
```bash
kubectl describe pod -n kube-system -l app=flannel
kubectl logs -n kube-system -l app=flannel
```

### 3. 检查节点上是否有 flannel 相关文件
```bash
ls -la /run/flannel/
ls -la /etc/cni/net.d/
```

### 4. 查看 kubeadm 初始化时的 Pod CIDR 配置
```bash
kubectl cluster-info dump | grep -m 1 cluster-cidr
# 或者查看 kube-controller-manager 的参数
kubectl get pods kube-controller-manager-eetest-uccp-k8s2 -n kube-system -o yaml | grep cluster-cidr
```

## 解决方案

### 方案 1: 安装/重新安装 Flannel（推荐）

#### 步骤 1: 下载 Flannel 配置文件
```bash
wget https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
```

#### 步骤 2: 检查并修改 Pod CIDR（如果需要）
查看当前集群的 Pod CIDR：
```bash
kubectl cluster-info dump | grep -m 1 cluster-cidr
```

如果集群使用的不是默认的 `10.244.0.0/16`，需要修改 `kube-flannel.yml` 中的网络配置：
```bash
# 编辑 kube-flannel.yml，找到 net-conf.json 部分
# 修改 "Network" 字段以匹配你的 Pod CIDR
```

#### 步骤 3: 应用 Flannel 配置
```bash
kubectl apply -f kube-flannel.yml
```

#### 步骤 4: 验证 Flannel 是否正常运行
```bash
kubectl get pods -n kube-system | grep flannel
kubectl get ds -n kube-system kube-flannel-ds
```

### 方案 2: 使用国内镜像源（如果拉取镜像有问题）

如果是镜像拉取问题，可以修改 Flannel 配置使用阿里云镜像：

```bash
# 下载配置文件
wget https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

# 替换镜像地址
sed -i 's|docker.io/flannel/flannel:.*|registry.cn-hangzhou.aliyuncs.com/google_containers/flannel:v0.22.0|g' kube-flannel.yml
sed -i 's|docker.io/flannel/flannel-cni-plugin:.*|registry.cn-hangzhou.aliyuncs.com/google_containers/flannel-cni-plugin:v1.1.2|g' kube-flannel.yml

# 应用配置
kubectl apply -f kube-flannel.yml
```

### 方案 3: 手动创建 subnet.env 文件（临时方案，不推荐）

这只是临时解决方法，不适合生产环境：

```bash
# 创建目录
mkdir -p /run/flannel

# 创建配置文件（需要根据实际集群配置修改）
cat > /run/flannel/subnet.env << EOF
FLANNEL_NETWORK=10.244.0.0/16
FLANNEL_SUBNET=10.244.0.1/24
FLANNEL_MTU=1450
FLANNEL_IPMASQ=true
EOF

# 重启 kubelet
systemctl restart kubelet
```

**注意**：这种方法只能临时解决单个节点的问题，且在节点重启后会失效。

## 验证修复

修复后，执行以下命令验证：

### 1. 检查 Flannel Pods 运行状态
```bash
kubectl get pods -n kube-system | grep flannel
# 应该看到 Flannel pods 都处于 Running 状态
```

### 2. 检查 CoreDNS Pods 状态
```bash
kubectl get pods -n kube-system | grep coredns
# CoreDNS pods 应该能够正常启动
```

### 3. 验证网络连通性
```bash
# 检查 subnet.env 文件是否已创建
ls -la /run/flannel/subnet.env
cat /run/flannel/subnet.env

# 检查 CNI 配置
ls -la /etc/cni/net.d/
```

### 4. 测试 Pod 网络
```bash
# 创建测试 Pod
kubectl run test-pod --image=busybox --restart=Never -- sleep 3600

# 检查 Pod 是否能获取 IP
kubectl get pod test-pod -o wide

# 清理测试 Pod
kubectl delete pod test-pod
```

## 常见问题

### Q1: Flannel 配置应用后 Pod 还是无法启动？
- 检查 Flannel Pod 的日志：`kubectl logs -n kube-system -l app=flannel`
- 可能需要重启 kubelet：`systemctl restart kubelet`

### Q2: 如何确认 Pod CIDR 配置？
```bash
# 方法 1: 查看 kube-controller-manager
ps aux | grep kube-controller-manager | grep cluster-cidr

# 方法 2: 查看 Pod 配置
kubectl get pod kube-controller-manager-eetest-uccp-k8s2 -n kube-system -o yaml | grep cluster-cidr

# 方法 3: 查看集群配置
kubectl cluster-info dump | grep -m 1 cluster-cidr
```

### Q3: 多节点集群中，只有部分节点有问题怎么办？
- 确保所有节点都运行了 Flannel DaemonSet Pod
- 检查节点间网络连通性
- 验证所有节点的防火墙配置

## 预防措施

1. **按正确顺序部署组件**
   - 先初始化 master 节点（使用正确的 `--pod-network-cidr`）
   - 立即部署 CNI 插件（Flannel）
   - 然后加入 worker 节点

2. **使用一致的网络配置**
   - 确保 kubeadm init 的 `--pod-network-cidr` 与 Flannel 配置一致
   - 默认 Flannel 使用 `10.244.0.0/16`

3. **验证网络插件状态**
   - 定期检查 Flannel DaemonSet 的运行状态
   - 监控 `/run/flannel/subnet.env` 文件的存在性

## 相关资源

- [Flannel 官方文档](https://github.com/flannel-io/flannel)
- [Kubernetes 网络模型](https://kubernetes.io/docs/concepts/cluster-administration/networking/)
- [kubeadm 安装指南](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)

## 总结

这是一个典型的 Kubernetes CNI 插件未正确安装的问题。**推荐的解决方案是安装或重新安装 Flannel DaemonSet**，这会自动在所有节点上创建必要的配置文件并启动网络组件。安装 Flannel 后，CoreDNS 和其他 Pods 应该能够正常启动。
