# OpenVPN 证书 + 用户名密码双重认证配置指南

## 概述

本方案实现了 OpenVPN 的双重认证机制：
1. **证书认证**：客户端必须拥有有效的证书和私钥
2. **用户名密码认证**：客户端必须提供正确的用户名和密码

只有同时通过两种认证，客户端才能成功连接到 VPN。

## 服务器信息

- **公网IP**：111.175.39.190
- **端口**：49512
- **协议**：UDP
- **VPN网段**：10.8.0.0/24

## 文件说明

### 1. checkpsw.sh
密码验证脚本，用于验证客户端提供的用户名和密码。

**部署位置**：`/etc/openvpn/checkpsw.sh`

### 2. psw-file
用户账号密码文件，存储允许连接的用户名和密码。

**部署位置**：`/etc/openvpn/psw-file`

**格式**：每行一个用户，用户名和密码用空格分隔
```
username1 password1
username2 password2
```

### 3. server.conf
完整的服务器配置文件，包含双重认证配置。

**部署位置**：`/etc/openvpn/server.conf`

### 4. client.ovpn
客户端配置文件模板。

## 部署步骤

### 服务器端配置

#### 步骤 1：部署密码验证脚本

```bash
# 复制脚本到OpenVPN目录
sudo cp checkpsw.sh /etc/openvpn/checkpsw.sh

# 设置执行权限
sudo chmod +x /etc/openvpn/checkpsw.sh
```

#### 步骤 2：创建用户密码文件

```bash
# 复制密码文件到OpenVPN目录
sudo cp psw-file /etc/openvpn/psw-file

# 设置严格的权限（仅root可读写）
sudo chmod 600 /etc/openvpn/psw-file
sudo chown root:root /etc/openvpn/psw-file
```

#### 步骤 3：编辑用户密码文件

```bash
sudo vi /etc/openvpn/psw-file
```

添加您的用户：
```
alice StrongPassword123!
bob SecurePass456@
charlie MyP@ssw0rd789
```

**密码建议**：
- 至少8个字符
- 包含大小写字母、数字和特殊字符
- 避免使用常见密码

#### 步骤 4：创建认证日志目录

```bash
# 创建日志文件并设置权限
sudo touch /var/log/openvpn-password.log
sudo chmod 600 /var/log/openvpn-password.log
sudo chown root:root /var/log/openvpn-password.log
```

#### 步骤 5：更新服务器配置

您的服务器配置文件已经包含了必要的双重认证配置：

```bash
# 检查配置文件中是否包含以下关键行
cat /etc/openvpn/server.conf | grep -E "auth-user-pass-verify|script-security|username-as-common-name"
```

应该看到：
```
auth-user-pass-verify /etc/openvpn/checkpsw.sh via-env
script-security 3
username-as-common-name
```

如果需要，可以用本方案提供的 `server.conf` 替换现有配置（建议先备份）：

```bash
# 备份现有配置
sudo cp /etc/openvpn/server.conf /etc/openvpn/server.conf.backup

# 使用新配置（请根据实际情况调整）
sudo cp server.conf /etc/openvpn/server.conf
```

#### 步骤 6：重启 OpenVPN 服务

```bash
# 重启OpenVPN服务
sudo systemctl restart openvpn@server

# 检查服务状态
sudo systemctl status openvpn@server

# 查看日志
sudo tail -f /var/log/openvpn-password.log
sudo journalctl -u openvpn@server -f
```

### 客户端配置

#### 步骤 1：生成客户端证书

如果还没有为客户端生成证书，需要先生成：

```bash
# 进入easy-rsa目录
cd /etc/openvpn/easy-rsa

# 生成客户端证书（例如：client1）
./easyrsa build-client-full client1 nopass

# 如果需要密码保护的私钥，去掉nopass参数
# ./easyrsa build-client-full client1
```

#### 步骤 2：创建客户端配置文件

使用提供的 `client.ovpn` 模板，替换其中的证书和密钥内容：

```bash
# 查看CA证书
cat /etc/openvpn/easy-rsa/pki/ca.crt

# 查看客户端证书
cat /etc/openvpn/easy-rsa/pki/issued/client1.crt

# 查看客户端私钥
sudo cat /etc/openvpn/easy-rsa/pki/private/client1.key

# 查看TLS认证密钥
cat /etc/openvpn/easy-rsa/ta.key
```

将这些内容复制到 `client.ovpn` 文件的相应位置。

#### 步骤 3：生成完整的客户端配置文件（可选脚本）

为了方便，可以创建一个脚本自动生成客户端配置：

```bash
#!/bin/bash
# generate-client-config.sh

CLIENT_NAME=$1
OUTPUT_DIR="/root/openvpn-clients"
SERVER_IP="111.175.39.190"
SERVER_PORT="49512"

if [ -z "$CLIENT_NAME" ]; then
    echo "Usage: $0 <client-name>"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

cat > "$OUTPUT_DIR/${CLIENT_NAME}.ovpn" <<EOF
client
dev tun
proto udp
remote $SERVER_IP $SERVER_PORT
resolv-retry infinite
nobind
persist-key
persist-tun
auth-user-pass
remote-cert-tls server
cipher AES-256-CBC
verb 3
key-direction 1

<ca>
$(cat /etc/openvpn/easy-rsa/pki/ca.crt)
</ca>

<cert>
$(cat /etc/openvpn/easy-rsa/pki/issued/${CLIENT_NAME}.crt)
</cert>

<key>
$(cat /etc/openvpn/easy-rsa/pki/private/${CLIENT_NAME}.key)
</key>

<tls-auth>
$(cat /etc/openvpn/easy-rsa/ta.key)
</tls-auth>
EOF

echo "Client configuration generated: $OUTPUT_DIR/${CLIENT_NAME}.ovpn"
```

使用方法：
```bash
chmod +x generate-client-config.sh
./generate-client-config.sh client1
```

#### 步骤 4：分发客户端配置

将生成的 `.ovpn` 文件发送给用户，并告知他们的用户名和密码。

**安全建议**：
- 通过安全渠道传输配置文件（加密邮件、加密即时通讯等）
- 用户名和密码应通过独立的安全渠道告知
- 建议用户首次登录后立即修改密码

## 客户端连接

### Windows 客户端

1. 安装 [OpenVPN GUI](https://openvpn.net/community-downloads/)
2. 将 `.ovpn` 文件放到 `C:\Program Files\OpenVPN\config\` 目录
3. 右键点击系统托盘的 OpenVPN 图标，选择配置文件
4. 点击"连接"
5. 输入用户名和密码

### Linux 客户端

```bash
# 安装OpenVPN
sudo apt install openvpn  # Debian/Ubuntu
sudo yum install openvpn  # CentOS/RHEL

# 连接（会提示输入用户名密码）
sudo openvpn --config client.ovpn

# 或者后台运行
sudo openvpn --config client.ovpn --daemon
```

### macOS 客户端

1. 安装 [Tunnelblick](https://tunnelblick.net/)
2. 双击 `.ovpn` 文件导入配置
3. 点击连接
4. 输入用户名和密码

### Android 客户端

1. 从 Google Play 安装 "OpenVPN for Android"
2. 导入 `.ovpn` 文件
3. 连接时输入用户名和密码

### iOS 客户端

1. 从 App Store 安装 "OpenVPN Connect"
2. 通过邮件、iTunes 或云存储导入 `.ovpn` 文件
3. 连接时输入用户名和密码

## 用户管理

### 添加用户

```bash
# 编辑密码文件
sudo vi /etc/openvpn/psw-file

# 添加一行：username password
echo "newuser NewPassword123!" | sudo tee -a /etc/openvpn/psw-file

# 不需要重启OpenVPN服务，修改立即生效
```

### 删除用户

```bash
# 编辑密码文件，删除对应的行
sudo vi /etc/openvpn/psw-file

# 或使用sed删除
sudo sed -i '/^username /d' /etc/openvpn/psw-file
```

### 修改密码

```bash
# 编辑密码文件，修改对应用户的密码
sudo vi /etc/openvpn/psw-file
```

### 查看在线用户

```bash
# 查看OpenVPN状态
cat /etc/openvpn/openvpn-status.log

# 实时监控
watch -n 1 cat /etc/openvpn/openvpn-status.log
```

## 日志和监控

### 查看认证日志

```bash
# 查看密码认证日志
sudo tail -f /var/log/openvpn-password.log

# 查看OpenVPN服务日志
sudo journalctl -u openvpn@server -f

# 查看系统日志
sudo tail -f /var/log/syslog | grep openvpn
```

### 日志格式

密码认证日志格式：
```
2026-02-11 10:30:15 - Authentication attempt for user: alice from IP: 111.175.39.100
2026-02-11 10:30:15 - SUCCESS: User alice authenticated successfully
```

失败的认证：
```
2026-02-11 10:35:20 - Authentication attempt for user: baduser from IP: 111.175.39.101
2026-02-11 10:35:20 - FAILED: Invalid credentials for user baduser
```

### 日志轮转

为防止日志文件过大，建议配置日志轮转：

```bash
# 创建日志轮转配置
sudo cat > /etc/logrotate.d/openvpn-auth <<EOF
/var/log/openvpn-password.log {
    daily
    rotate 30
    compress
    delaycompress
    notifempty
    create 600 root root
    missingok
}
EOF
```

## 安全加固建议

### 1. 使用强密码策略

- 强制密码长度至少12个字符
- 要求包含大小写字母、数字和特殊字符
- 定期更换密码
- 禁止重复使用旧密码

### 2. 密码文件加密（可选）

如果担心明文密码，可以使用哈希密码：

修改 `checkpsw.sh` 使用MD5/SHA256哈希：

```bash
#!/bin/bash
PASSFILE="/etc/openvpn/psw-file"
LOG_FILE="/var/log/openvpn-password.log"

USERNAME="$username"
PASSWORD="$password"

# 对密码进行SHA256哈希
PASSWORD_HASH=$(echo -n "$PASSWORD" | sha256sum | awk '{print $1}')

echo "$(date '+%Y-%m-%d %H:%M:%S') - Authentication attempt for user: $USERNAME" >> "$LOG_FILE"

while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    
    file_user=$(echo "$line" | awk '{print $1}')
    file_pass_hash=$(echo "$line" | awk '{print $2}')
    
    if [ "$USERNAME" = "$file_user" ] && [ "$PASSWORD_HASH" = "$file_pass_hash" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - SUCCESS: User $USERNAME authenticated" >> "$LOG_FILE"
        exit 0
    fi
done < "$PASSFILE"

echo "$(date '+%Y-%m-%d %H:%M:%S') - FAILED: Invalid credentials for user $USERNAME" >> "$LOG_FILE"
exit 1
```

密码文件格式改为（密码的SHA256哈希）：
```
alice ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f
```

生成哈希：
```bash
echo -n "YourPassword" | sha256sum
```

### 3. 限制登录尝试

可以在 `checkpsw.sh` 中添加失败次数限制，防止暴力破解。

### 4. 使用防火墙

```bash
# 仅允许特定IP访问OpenVPN端口
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="允许的IP段" port port="49512" protocol="udp" accept'
sudo firewall-cmd --reload

# 或使用iptables
sudo iptables -A INPUT -p udp --dport 49512 -s 允许的IP段 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 49512 -j DROP
```

### 5. 证书有效期管理

- 定期检查证书有效期
- 过期前及时续期
- 吊销不再使用的证书

```bash
# 查看证书有效期
openssl x509 -in /etc/openvpn/easy-rsa/pki/issued/client1.crt -noout -dates

# 吊销证书
cd /etc/openvpn/easy-rsa
./easyrsa revoke client1
./easyrsa gen-crl

# 更新服务器配置使用CRL
echo "crl-verify /etc/openvpn/easy-rsa/pki/crl.pem" >> /etc/openvpn/server.conf
```

### 6. 启用两步验证（高级）

可以集成 Google Authenticator 或其他 OTP 方案，实现三因素认证：
- 证书（你有什么）
- 密码（你知道什么）
- OTP（你拥有的设备）

## 故障排查

### 问题 1：客户端无法连接

**检查项**：
1. 服务器防火墙是否开放 49512/UDP 端口
2. 云服务器安全组是否开放 49512/UDP 端口
3. OpenVPN 服务是否正常运行
4. 证书是否有效

```bash
# 检查端口
sudo netstat -ulnp | grep 49512

# 检查服务状态
sudo systemctl status openvpn@server

# 测试端口连通性（从客户端）
nc -vuz 111.175.39.190 49512
```

### 问题 2：密码认证失败

**检查项**：
1. 用户名密码是否正确
2. psw-file 文件格式是否正确（用户名和密码之间只有一个空格）
3. checkpsw.sh 是否有执行权限
4. 查看认证日志

```bash
# 查看认证日志
sudo tail -20 /var/log/openvpn-password.log

# 检查脚本权限
ls -l /etc/openvpn/checkpsw.sh

# 手动测试脚本
sudo username=testuser password=testpass /etc/openvpn/checkpsw.sh
echo $?  # 应该返回 0（成功）或 1（失败）
```

### 问题 3：证书认证失败

**检查项**：
1. CA证书、客户端证书、私钥是否匹配
2. 证书是否过期
3. tls-auth 密钥是否正确

```bash
# 验证证书
openssl verify -CAfile /etc/openvpn/easy-rsa/pki/ca.crt /etc/openvpn/easy-rsa/pki/issued/client1.crt

# 查看证书详情
openssl x509 -in /etc/openvpn/easy-rsa/pki/issued/client1.crt -noout -text
```

### 问题 4：连接成功但无法访问网络

**检查项**：
1. 服务器路由配置
2. 客户端路由是否正确推送
3. 服务器是否启用了IP转发

```bash
# 检查IP转发
sudo sysctl net.ipv4.ip_forward
# 应该返回 1，如果是 0，执行：
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf

# 检查NAT规则（如果需要访问互联网）
sudo iptables -t nat -L POSTROUTING -n -v
```

### 问题 5：日志文件无法写入

**检查项**：
1. 日志文件是否存在
2. 权限是否正确

```bash
# 创建并设置权限
sudo touch /var/log/openvpn-password.log
sudo chmod 666 /var/log/openvpn-password.log
```

## 性能优化

### 1. 使用 UDP 协议

UDP 比 TCP 性能更好，已在配置中使用。

### 2. 启用压缩

如果带宽有限，可以启用压缩（增加CPU使用）：

```bash
# 在 server.conf 中添加
compress lz4-v2
push "compress lz4-v2"

# 在 client.ovpn 中添加
compress lz4-v2
```

### 3. 调整 keepalive 参数

根据网络环境调整：

```bash
# 稳定网络
keepalive 10 120

# 不稳定网络
keepalive 5 60
```

### 4. 使用更快的加密算法

如果设备性能有限，可以考虑使用 AES-128-CBC：

```bash
cipher AES-128-CBC
```

## 备份和恢复

### 重要文件备份

```bash
# 创建备份目录
sudo mkdir -p /root/openvpn-backup

# 备份配置和密钥
sudo tar -czf /root/openvpn-backup/openvpn-$(date +%Y%m%d).tar.gz \
    /etc/openvpn/server.conf \
    /etc/openvpn/checkpsw.sh \
    /etc/openvpn/psw-file \
    /etc/openvpn/easy-rsa/pki/

# 定期备份（添加到crontab）
0 2 * * * tar -czf /root/openvpn-backup/openvpn-$(date +\%Y\%m\%d).tar.gz /etc/openvpn/
```

### 恢复

```bash
# 解压备份
sudo tar -xzf /root/openvpn-backup/openvpn-20260211.tar.gz -C /

# 重启服务
sudo systemctl restart openvpn@server
```

## 常见问题 FAQ

### Q1: 可以只使用密码认证，不用证书吗？

A: 不建议。证书认证提供了更强的安全性。双重认证可以确保：
- 证书被盗时，没有密码也无法登录
- 密码泄露时，没有证书也无法登录

### Q2: 可以为不同用户分配不同的权限吗？

A: 可以使用 client-config-dir 功能，为不同用户配置不同的路由和权限。

### Q3: 如何实现客户端之间互相访问？

A: 在 server.conf 中取消注释：
```bash
client-to-client
```

### Q4: 密码文件可以存储在数据库中吗？

A: 可以修改 checkpsw.sh 脚本，从数据库查询用户名密码。

### Q5: 支持 LDAP/Active Directory 认证吗？

A: 可以使用 openvpn-auth-ldap 插件集成 LDAP 认证。

## 联系和支持

如有问题，请检查：
1. OpenVPN 官方文档：https://openvpn.net/community-resources/
2. 系统日志：`/var/log/openvpn-password.log` 和 `journalctl -u openvpn@server`
3. OpenVPN 社区论坛：https://forums.openvpn.net/

## 更新日志

- 2026-02-11: 初始版本，实现证书+密码双重认证

---

**安全提醒**：
- 定期更新 OpenVPN 和系统软件
- 使用强密码
- 妥善保管证书和私钥
- 定期审计访问日志
- 及时吊销不再使用的证书
