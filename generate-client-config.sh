#!/bin/bash
###########################################################
# OpenVPN 客户端配置文件生成脚本
# 自动生成包含所有证书的 .ovpn 文件
###########################################################

# 检查参数
if [ $# -lt 1 ]; then
    echo "使用方法: $0 <客户端名称> [输出目录]"
    echo "示例: $0 client1"
    echo "示例: $0 client1 /root/openvpn-clients"
    exit 1
fi

CLIENT_NAME=$1
OUTPUT_DIR=${2:-"/root/openvpn-clients"}
SERVER_IP="111.175.39.190"
SERVER_PORT="49512"
EASYRSA_DIR="/etc/openvpn/easy-rsa"

# 检查easy-rsa目录是否存在
if [ ! -d "$EASYRSA_DIR" ]; then
    echo "错误: easy-rsa目录不存在: $EASYRSA_DIR"
    exit 1
fi

# 检查客户端证书是否存在
if [ ! -f "$EASYRSA_DIR/pki/issued/${CLIENT_NAME}.crt" ]; then
    echo "错误: 客户端证书不存在: $EASYRSA_DIR/pki/issued/${CLIENT_NAME}.crt"
    echo ""
    echo "请先生成客户端证书："
    echo "  cd $EASYRSA_DIR"
    echo "  ./easyrsa build-client-full ${CLIENT_NAME} nopass"
    exit 1
fi

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

# 输出文件路径
OUTPUT_FILE="$OUTPUT_DIR/${CLIENT_NAME}.ovpn"

echo "正在生成客户端配置文件..."
echo "客户端名称: $CLIENT_NAME"
echo "输出文件: $OUTPUT_FILE"

# 生成配置文件
cat > "$OUTPUT_FILE" <<EOF
##############################################
# OpenVPN 客户端配置文件
# 客户端名称: ${CLIENT_NAME}
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')
##############################################

# 指定这是客户端
client

# 使用tun设备
dev tun

# 协议类型（必须与服务器匹配）
proto udp

# 服务器地址和端口
remote $SERVER_IP $SERVER_PORT

# 保持尝试连接
resolv-retry infinite

# 不绑定本地端口
nobind

# 持久化选项
persist-key
persist-tun

# 启用用户名密码认证
# OpenVPN会提示输入用户名和密码
auth-user-pass

# 如果想保存用户名密码到文件（不推荐）
# 创建文件userpass.txt，第一行用户名，第二行密码
# 然后取消下面的注释：
# auth-user-pass userpass.txt

# 验证服务器证书
remote-cert-tls server

# 加密算法（必须与服务器匹配）
cipher AES-256-CBC

# 日志级别
verb 3

# TLS密钥方向
key-direction 1

# 静默重复的日志消息
mute 20

##############################################
# 嵌入式证书和密钥
##############################################

<ca>
$(cat $EASYRSA_DIR/pki/ca.crt)
</ca>

<cert>
$(openssl x509 -in $EASYRSA_DIR/pki/issued/${CLIENT_NAME}.crt)
</cert>

<key>
$(cat $EASYRSA_DIR/pki/private/${CLIENT_NAME}.key)
</key>

<tls-auth>
$(cat $EASYRSA_DIR/ta.key)
</tls-auth>
EOF

# 设置文件权限
chmod 600 "$OUTPUT_FILE"

echo ""
echo "=========================================="
echo "客户端配置文件生成成功！"
echo "=========================================="
echo ""
echo "配置文件位置: $OUTPUT_FILE"
echo ""
echo "下一步操作："
echo "1. 将配置文件发送给客户端用户"
echo "2. 在 /etc/openvpn/psw-file 中为该用户添加账号密码"
echo "   例如: echo '${CLIENT_NAME} UserPassword123!' >> /etc/openvpn/psw-file"
echo ""
echo "客户端连接时需要："
echo "- 此配置文件 (${CLIENT_NAME}.ovpn)"
echo "- 用户名和密码（在psw-file中配置）"
echo ""
echo "Windows: 使用 OpenVPN GUI"
echo "Linux: sudo openvpn --config ${CLIENT_NAME}.ovpn"
echo "macOS: 使用 Tunnelblick"
echo "Android/iOS: 使用 OpenVPN Connect"
echo ""
