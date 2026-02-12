# Flannel 网络问题快速修复命令

## 问题症状
```
Failed to create pod sandbox: plugin type="flannel" failed (add): 
failed to load flannel 'subnet.env' file: open /run/flannel/subnet.env: no such file or directory
```

## 快速修复（推荐方案）

### 方法 1: 直接安装 Flannel
```bash
# 应用 Flannel 配置
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

# 等待 Flannel Pods 启动
kubectl wait --for=condition=ready pod -l app=flannel -n kube-system --timeout=120s

# 验证状态
kubectl get pods -n kube-system | grep flannel
```

### 方法 2: 使用国内镜像（网络受限时）
```bash
# 下载配置文件
wget https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml -O kube-flannel.yml

# 替换为阿里云镜像
sed -i 's|docker.io/flannel/flannel:|registry.cn-hangzhou.aliyuncs.com/google_containers/flannel:|g' kube-flannel.yml

# 应用配置
kubectl apply -f kube-flannel.yml

# 验证状态
kubectl get pods -n kube-system -w
```

### 方法 3: 如果已安装但有问题，重新部署
```bash
# 删除现有 Flannel
kubectl delete -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

# 等待删除完成
sleep 5

# 重新安装
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

# 监控 Pods 状态
kubectl get pods -n kube-system -w
```

## 诊断命令

### 检查 Flannel 状态
```bash
# 检查 Flannel DaemonSet
kubectl get ds -n kube-system | grep flannel

# 检查 Flannel Pods
kubectl get pods -n kube-system | grep flannel

# 查看 Flannel 日志
kubectl logs -n kube-system -l app=flannel

# 详细查看某个 Flannel Pod
kubectl describe pod -n kube-system -l app=flannel
```

### 检查节点本地文件
```bash
# 检查 subnet.env 文件
ls -la /run/flannel/
cat /run/flannel/subnet.env

# 检查 CNI 配置
ls -la /etc/cni/net.d/
cat /etc/cni/net.d/10-flannel.conflist
```

### 检查集群网络配置
```bash
# 查看 Pod CIDR 配置
kubectl cluster-info dump | grep -m 1 cluster-cidr

# 或者
kubectl get pods -n kube-system -l component=kube-controller-manager -o yaml | grep cluster-cidr

# 或者在节点上
ps aux | grep kube-controller-manager | grep cluster-cidr
```

### 检查 CoreDNS 状态
```bash
# 查看 CoreDNS Pods
kubectl get pods -n kube-system | grep coredns

# 查看 CoreDNS Pod 详情
kubectl describe pod -n kube-system -l k8s-app=kube-dns

# 查看事件
kubectl get events -n kube-system --sort-by='.lastTimestamp'
```

## 验证修复

### 1. 检查 Flannel 运行正常
```bash
kubectl get pods -n kube-system | grep flannel
# 期望输出: 所有 Flannel Pods 都是 Running 状态
```

### 2. 检查 subnet.env 文件已创建
```bash
cat /run/flannel/subnet.env
# 期望输出:
# FLANNEL_NETWORK=10.244.0.0/16
# FLANNEL_SUBNET=10.244.0.1/24
# FLANNEL_MTU=1450
# FLANNEL_IPMASQ=true
```

### 3. 检查 CoreDNS 正常启动
```bash
kubectl get pods -n kube-system | grep coredns
# 期望输出: CoreDNS Pods 都是 Running 状态，READY 显示 1/1
```

### 4. 测试 Pod 网络
```bash
# 创建测试 Pod
kubectl run test-nginx --image=nginx --restart=Never

# 检查 Pod IP
kubectl get pod test-nginx -o wide

# 如果 Pod 成功获得 IP 并运行，说明网络已修复
# 清理测试 Pod
kubectl delete pod test-nginx
```

## 常见问题处理

### 问题 1: Flannel Pod 一直处于 Init 或 Pending 状态
```bash
# 查看详细信息
kubectl describe pod -n kube-system -l app=flannel

# 可能的原因：镜像拉取失败，考虑使用国内镜像源
```

### 问题 2: 安装后 CoreDNS 仍然 ContainerCreating
```bash
# 等待 Flannel 完全就绪
kubectl wait --for=condition=ready pod -l app=flannel -n kube-system --timeout=120s

# 检查 subnet.env 是否已创建
ls -la /run/flannel/subnet.env

# 如果文件存在但 CoreDNS 仍有问题，重启 kubelet
systemctl restart kubelet

# 删除问题 Pod 让其重建
kubectl delete pod -n kube-system coredns-66f779496c-542lf
kubectl delete pod -n kube-system coredns-66f779496c-z66tq
```

### 问题 3: Pod CIDR 不匹配
```bash
# 查看集群的 Pod CIDR
kubectl cluster-info dump | grep -m 1 cluster-cidr

# 下载并修改 Flannel 配置
wget https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

# 编辑文件，找到 net-conf.json，修改 Network 字段
# 例如，如果集群使用 10.100.0.0/16
# 将 "Network": "10.244.0.0/16" 改为 "Network": "10.100.0.0/16"

# 应用修改后的配置
kubectl apply -f kube-flannel.yml
```

### 问题 4: 权限或 SELinux 问题
```bash
# 检查 SELinux 状态
getenforce

# 如果是 Enforcing，临时设置为 Permissive 测试
setenforce 0

# 如果问题解决，需要配置 SELinux 策略或永久禁用
# 编辑 /etc/selinux/config
# SELINUX=permissive
```

## 一键修复脚本

如果你想要自动化修复，可以使用提供的脚本：

```bash
# 赋予执行权限
chmod +x fix-flannel-network.sh

# 运行脚本
./fix-flannel-network.sh
```

## 重要提示

1. **安装 Flannel 前确认 Pod CIDR**
   - Flannel 默认使用 `10.244.0.0/16`
   - 如果 kubeadm init 时使用了不同的 CIDR，需要修改 Flannel 配置

2. **Flannel 版本兼容性**
   - 确保 Flannel 版本与 Kubernetes 版本兼容
   - 建议使用最新的稳定版本

3. **网络策略**
   - 确保节点间网络互通
   - 检查防火墙规则不会阻止 Flannel 流量
   - Flannel 使用 UDP 8285 和 8472 端口（VXLAN）

4. **多节点集群**
   - Flannel 是 DaemonSet，会在所有节点上运行
   - 确保所有节点都能正常运行 Flannel Pod
