#!/bin/bash
# Flannel 网络问题修复脚本
# 适用于 Kubernetes 集群中 Flannel CNI 插件问题

set -e

echo "=========================================="
echo "Flannel 网络问题诊断和修复脚本"
echo "=========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}请使用 root 用户运行此脚本${NC}"
    exit 1
fi

# 步骤 1: 诊断当前状态
echo "=========================================="
echo "步骤 1: 诊断当前状态"
echo "=========================================="

echo -e "\n${YELLOW}1.1 检查 Flannel DaemonSet...${NC}"
if kubectl get ds -n kube-system 2>/dev/null | grep -q flannel; then
    echo -e "${GREEN}✓ Flannel DaemonSet 已存在${NC}"
    kubectl get ds -n kube-system | grep flannel
    FLANNEL_EXISTS=true
else
    echo -e "${RED}✗ Flannel DaemonSet 不存在${NC}"
    FLANNEL_EXISTS=false
fi

echo -e "\n${YELLOW}1.2 检查 Flannel Pods...${NC}"
if kubectl get pods -n kube-system 2>/dev/null | grep -q flannel; then
    echo -e "${GREEN}✓ Flannel Pods 存在${NC}"
    kubectl get pods -n kube-system | grep flannel
else
    echo -e "${RED}✗ 没有发现 Flannel Pods${NC}"
fi

echo -e "\n${YELLOW}1.3 检查 /run/flannel/ 目录...${NC}"
if [ -d /run/flannel ]; then
    echo -e "${GREEN}✓ /run/flannel/ 目录存在${NC}"
    ls -la /run/flannel/ || true
else
    echo -e "${RED}✗ /run/flannel/ 目录不存在${NC}"
fi

echo -e "\n${YELLOW}1.4 检查 subnet.env 文件...${NC}"
if [ -f /run/flannel/subnet.env ]; then
    echo -e "${GREEN}✓ subnet.env 文件存在${NC}"
    cat /run/flannel/subnet.env
else
    echo -e "${RED}✗ subnet.env 文件不存在（这是问题的核心）${NC}"
fi

echo -e "\n${YELLOW}1.5 检查 CNI 配置目录...${NC}"
if [ -d /etc/cni/net.d ]; then
    echo -e "${GREEN}✓ CNI 配置目录存在${NC}"
    ls -la /etc/cni/net.d/
else
    echo -e "${RED}✗ CNI 配置目录不存在${NC}"
fi

echo -e "\n${YELLOW}1.6 获取集群 Pod CIDR...${NC}"
POD_CIDR=$(kubectl get pods kube-controller-manager-eetest-uccp-k8s2 -n kube-system -o yaml 2>/dev/null | grep -oP 'cluster-cidr=\K[0-9./]+' | head -1 || echo "")
if [ -z "$POD_CIDR" ]; then
    # 尝试另一种方法
    POD_CIDR=$(ps aux | grep kube-controller-manager | grep -oP 'cluster-cidr=\K[0-9./]+' | head -1 || echo "10.244.0.0/16")
fi
echo -e "${GREEN}集群 Pod CIDR: $POD_CIDR${NC}"

# 步骤 2: 提供修复选项
echo ""
echo "=========================================="
echo "步骤 2: 修复选项"
echo "=========================================="
echo ""
echo "检测到问题：CoreDNS Pods 无法启动，因为缺少 /run/flannel/subnet.env 文件"
echo ""
echo "请选择修复方案："
echo "1) 安装/重新安装 Flannel（推荐）"
echo "2) 仅删除并重新安装 Flannel"
echo "3) 使用国内镜像源安装 Flannel（如果网络受限）"
echo "4) 仅诊断，不修复"
echo "5) 退出"
echo ""
read -p "请输入选项 (1-5): " choice

case $choice in
    1)
        echo ""
        echo "=========================================="
        echo "方案 1: 安装/重新安装 Flannel"
        echo "=========================================="
        
        # 如果已存在，先删除
        if [ "$FLANNEL_EXISTS" = true ]; then
            echo -e "\n${YELLOW}删除现有 Flannel DaemonSet...${NC}"
            kubectl delete -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml 2>/dev/null || true
            echo "等待 5 秒..."
            sleep 5
        fi
        
        echo -e "\n${YELLOW}下载 Flannel 配置文件...${NC}"
        wget -O /tmp/kube-flannel.yml https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
        
        # 检查是否需要修改 Pod CIDR
        if [ "$POD_CIDR" != "10.244.0.0/16" ] && [ -n "$POD_CIDR" ]; then
            echo -e "\n${YELLOW}检测到非默认 Pod CIDR: $POD_CIDR${NC}"
            echo -e "${YELLOW}正在修改 Flannel 配置...${NC}"
            sed -i "s|\"Network\": \"10.244.0.0/16\"|\"Network\": \"$POD_CIDR\"|g" /tmp/kube-flannel.yml
        fi
        
        echo -e "\n${YELLOW}应用 Flannel 配置...${NC}"
        kubectl apply -f /tmp/kube-flannel.yml
        
        echo -e "\n${GREEN}Flannel 安装完成！${NC}"
        ;;
        
    2)
        echo ""
        echo "=========================================="
        echo "方案 2: 删除并重新安装 Flannel"
        echo "=========================================="
        
        echo -e "\n${YELLOW}删除现有 Flannel...${NC}"
        kubectl delete ds kube-flannel-ds -n kube-system 2>/dev/null || true
        kubectl delete cm kube-flannel-cfg -n kube-system 2>/dev/null || true
        kubectl delete sa flannel -n kube-system 2>/dev/null || true
        echo "等待 5 秒..."
        sleep 5
        
        echo -e "\n${YELLOW}重新安装 Flannel...${NC}"
        kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
        
        echo -e "\n${GREEN}Flannel 重新安装完成！${NC}"
        ;;
        
    3)
        echo ""
        echo "=========================================="
        echo "方案 3: 使用国内镜像源安装 Flannel"
        echo "=========================================="
        
        # 如果已存在，先删除
        if [ "$FLANNEL_EXISTS" = true ]; then
            echo -e "\n${YELLOW}删除现有 Flannel DaemonSet...${NC}"
            kubectl delete -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml 2>/dev/null || true
            echo "等待 5 秒..."
            sleep 5
        fi
        
        echo -e "\n${YELLOW}下载 Flannel 配置文件...${NC}"
        wget -O /tmp/kube-flannel.yml https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
        
        echo -e "\n${YELLOW}替换为国内镜像源...${NC}"
        # 使用阿里云镜像
        sed -i 's|docker.io/flannel/flannel:.*|registry.cn-hangzhou.aliyuncs.com/google_containers/flannel:v0.22.0|g' /tmp/kube-flannel.yml
        sed -i 's|docker.io/flannel/flannel-cni-plugin:.*|registry.cn-hangzhou.aliyuncs.com/google_containers/flannel-cni-plugin:v1.1.2|g' /tmp/kube-flannel.yml
        
        # 检查是否需要修改 Pod CIDR
        if [ "$POD_CIDR" != "10.244.0.0/16" ] && [ -n "$POD_CIDR" ]; then
            echo -e "\n${YELLOW}检测到非默认 Pod CIDR: $POD_CIDR${NC}"
            echo -e "${YELLOW}正在修改 Flannel 配置...${NC}"
            sed -i "s|\"Network\": \"10.244.0.0/16\"|\"Network\": \"$POD_CIDR\"|g" /tmp/kube-flannel.yml
        fi
        
        echo -e "\n${YELLOW}应用 Flannel 配置...${NC}"
        kubectl apply -f /tmp/kube-flannel.yml
        
        echo -e "\n${GREEN}Flannel 安装完成（使用国内镜像）！${NC}"
        ;;
        
    4)
        echo ""
        echo "=========================================="
        echo "仅诊断模式 - 不执行修复"
        echo "=========================================="
        echo -e "${YELLOW}诊断完成，未执行任何修复操作${NC}"
        exit 0
        ;;
        
    5)
        echo "退出脚本"
        exit 0
        ;;
        
    *)
        echo -e "${RED}无效的选项${NC}"
        exit 1
        ;;
esac

# 步骤 3: 验证修复
echo ""
echo "=========================================="
echo "步骤 3: 验证修复结果"
echo "=========================================="

echo -e "\n${YELLOW}等待 10 秒让 Flannel Pods 启动...${NC}"
sleep 10

echo -e "\n${YELLOW}3.1 检查 Flannel Pods 状态...${NC}"
kubectl get pods -n kube-system | grep flannel

echo -e "\n${YELLOW}3.2 检查 Flannel DaemonSet 状态...${NC}"
kubectl get ds -n kube-system | grep flannel

echo -e "\n${YELLOW}3.3 等待 Flannel 完全就绪...${NC}"
kubectl wait --for=condition=ready pod -l app=flannel -n kube-system --timeout=60s || true

echo -e "\n${YELLOW}3.4 检查 subnet.env 文件...${NC}"
if [ -f /run/flannel/subnet.env ]; then
    echo -e "${GREEN}✓ subnet.env 文件已创建${NC}"
    cat /run/flannel/subnet.env
else
    echo -e "${YELLOW}⚠ subnet.env 文件尚未创建，可能需要等待更长时间${NC}"
    echo "提示: Flannel Pod 需要完全启动后才会创建此文件"
fi

echo -e "\n${YELLOW}3.5 检查 CoreDNS Pods 状态...${NC}"
kubectl get pods -n kube-system | grep coredns

echo ""
echo "=========================================="
echo "修复完成"
echo "=========================================="
echo ""
echo -e "${GREEN}如果 CoreDNS Pods 仍然处于 ContainerCreating 状态，请:${NC}"
echo "1. 等待 1-2 分钟让 Flannel 完全初始化"
echo "2. 检查 Flannel Pod 日志: kubectl logs -n kube-system -l app=flannel"
echo "3. 如果需要，重启 kubelet: systemctl restart kubelet"
echo ""
echo "查看实时 Pod 状态:"
echo "kubectl get pods -n kube-system -w"
