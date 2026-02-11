# OpenVPN 双重认证快速部署指南

## 5分钟快速部署

### 服务器端（3步）

#### 1️⃣ 部署密码验证脚本

```bash
# 复制并设置权限
sudo cp checkpsw.sh /etc/openvpn/checkpsw.sh
sudo chmod +x /etc/openvpn/checkpsw.sh

# 创建日志文件
sudo touch /var/log/openvpn-password.log
sudo chmod 600 /var/log/openvpn-password.log
```

#### 2️⃣ 配置用户账号密码

```bash
# 复制密码文件
sudo cp psw-file /etc/openvpn/psw-file
sudo chmod 600 /etc/openvpn/psw-file

# 编辑添加您的用户
sudo vi /etc/openvpn/psw-file
```

添加用户格式：
```
username1 password1
username2 password2
```

#### 3️⃣ 更新服务器配置并重启

```bash
# 备份现有配置
sudo cp /etc/openvpn/server.conf /etc/openvpn/server.conf.backup

# 在您现有的 server.conf 中确认包含以下配置：
# auth-user-pass-verify /etc/openvpn/checkpsw.sh via-env
# script-security 3
# username-as-common-name
# key-direction 0

# 重启服务
sudo systemctl restart openvpn@server
sudo systemctl status openvpn@server
```

✅ 服务器端配置完成！

---

### 客户端（2步）

#### 1️⃣ 生成客户端证书（如果还没有）

```bash
cd /etc/openvpn/easy-rsa
./easyrsa build-client-full client1 nopass
```

#### 2️⃣ 生成客户端配置文件

```bash
# 使用自动生成脚本
chmod +x generate-client-config.sh
./generate-client-config.sh client1

# 配置文件将生成在：/root/openvpn-clients/client1.ovpn
```

✅ 客户端配置完成！

---

## 快速验证

### 检查服务器状态

```bash
# 检查OpenVPN服务
sudo systemctl status openvpn@server

# 检查端口监听
sudo netstat -ulnp | grep 49512

# 查看认证日志
sudo tail -f /var/log/openvpn-password.log
```

### 客户端连接测试

```bash
# Linux客户端
sudo openvpn --config client1.ovpn

# 输入用户名和密码时，使用在psw-file中配置的账号
```

---

## 关键配置说明

### 双重认证工作原理

```
客户端连接
    ↓
证书验证（第一道防线）
    ↓ 通过
密码验证（第二道防线）
    ↓ 通过
连接成功
```

### 关键文件

| 文件 | 路径 | 作用 |
|------|------|------|
| checkpsw.sh | /etc/openvpn/checkpsw.sh | 密码验证脚本 |
| psw-file | /etc/openvpn/psw-file | 用户密码文件 |
| server.conf | /etc/openvpn/server.conf | 服务器配置 |
| ca.crt | /etc/openvpn/easy-rsa/pki/ca.crt | CA证书 |
| ta.key | /etc/openvpn/easy-rsa/ta.key | TLS密钥 |

---

## 常用操作

### 添加新用户

```bash
# 1. 生成证书
cd /etc/openvpn/easy-rsa
./easyrsa build-client-full newuser nopass

# 2. 添加密码
echo "newuser SecurePassword123!" | sudo tee -a /etc/openvpn/psw-file

# 3. 生成配置文件
./generate-client-config.sh newuser
```

### 删除用户

```bash
# 1. 从密码文件删除
sudo sed -i '/^username /d' /etc/openvpn/psw-file

# 2. 吊销证书（可选但推荐）
cd /etc/openvpn/easy-rsa
./easyrsa revoke username
./easyrsa gen-crl

# 3. 在server.conf中启用CRL（如果还没有）
echo "crl-verify /etc/openvpn/easy-rsa/pki/crl.pem" | sudo tee -a /etc/openvpn/server.conf
sudo systemctl restart openvpn@server
```

### 修改密码

```bash
# 直接编辑密码文件
sudo vi /etc/openvpn/psw-file

# 不需要重启OpenVPN，修改立即生效
```

### 查看在线用户

```bash
cat /etc/openvpn/openvpn-status.log
```

---

## 故障排查

### 连接失败？

```bash
# 1. 检查服务器端口
sudo netstat -ulnp | grep 49512

# 2. 检查防火墙
sudo firewall-cmd --list-all
# 或
sudo iptables -L -n | grep 49512

# 3. 查看服务日志
sudo journalctl -u openvpn@server -n 50

# 4. 查看认证日志
sudo tail -20 /var/log/openvpn-password.log
```

### 密码认证失败？

```bash
# 1. 检查密码文件格式
cat /etc/openvpn/psw-file
# 确保用户名和密码之间只有一个空格

# 2. 检查脚本权限
ls -l /etc/openvpn/checkpsw.sh
# 应该有执行权限 (-rwxr-xr-x)

# 3. 手动测试脚本
sudo username=testuser password=testpass /etc/openvpn/checkpsw.sh
echo $?  # 0=成功, 1=失败
```

### 证书问题？

```bash
# 验证证书有效性
openssl verify -CAfile /etc/openvpn/easy-rsa/pki/ca.crt \
    /etc/openvpn/easy-rsa/pki/issued/client1.crt

# 查看证书有效期
openssl x509 -in /etc/openvpn/easy-rsa/pki/issued/client1.crt \
    -noout -dates
```

---

## 安全建议

### ✅ 必须做的

- [ ] 使用强密码（至少12字符，包含大小写字母、数字、特殊字符）
- [ ] 设置正确的文件权限（psw-file: 600）
- [ ] 定期更换密码
- [ ] 定期备份配置和证书
- [ ] 监控认证日志

### 🔒 推荐做的

- [ ] 配置防火墙限制访问IP
- [ ] 启用日志轮转
- [ ] 定期检查证书有效期
- [ ] 不再使用的证书及时吊销
- [ ] 考虑使用哈希密码而非明文

---

## 测试清单

在生产环境使用前，请完成以下测试：

- [ ] 使用正确的用户名和密码可以连接
- [ ] 使用错误的密码无法连接
- [ ] 没有在psw-file中的用户无法连接
- [ ] 没有证书无法连接
- [ ] 连接后可以访问推送的路由
- [ ] 认证日志正确记录
- [ ] 可以同时连接多个客户端

---

## 服务器信息

- **公网IP**: 111.175.39.190
- **端口**: 49512
- **协议**: UDP
- **VPN网段**: 10.8.0.0/24
- **推送路由**: 
  - 172.17.5.68/32
  - 172.17.5.69/32
- **DNS**: 192.168.222.72

---

## 更多信息

详细文档请参考：[README.md](README.md)

有问题？检查认证日志：
```bash
sudo tail -f /var/log/openvpn-password.log
```
