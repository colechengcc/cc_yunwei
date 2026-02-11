#!/bin/bash
###########################################################
# OpenVPN 用户名密码验证脚本
# 此脚本用于验证OpenVPN客户端提供的用户名和密码
###########################################################

# 密码文件路径
PASSFILE="/etc/openvpn/psw-file"

# 日志文件路径
LOG_FILE="/var/log/openvpn-password.log"

# 从环境变量中获取用户名和密码
# OpenVPN通过环境变量传递这些信息
USERNAME="$username"
PASSWORD="$password"

# 记录认证尝试（不记录密码）
echo "$(date '+%Y-%m-%d %H:%M:%S') - Authentication attempt for user: $USERNAME from IP: $untrusted_ip" >> "$LOG_FILE"

# 检查密码文件是否存在
if [ ! -f "$PASSFILE" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: Password file not found: $PASSFILE" >> "$LOG_FILE"
    exit 1
fi

# 检查用户名和密码是否为空
if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: Username or password is empty" >> "$LOG_FILE"
    exit 1
fi

# 从密码文件中读取并验证用户名和密码
# 密码文件格式：username password（每行一个用户）
while IFS= read -r line; do
    # 跳过空行和注释行
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    
    # 提取用户名和密码
    file_user=$(echo "$line" | awk '{print $1}')
    file_pass=$(echo "$line" | awk '{print $2}')
    
    # 比较用户名和密码
    if [ "$USERNAME" = "$file_user" ] && [ "$PASSWORD" = "$file_pass" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - SUCCESS: User $USERNAME authenticated successfully" >> "$LOG_FILE"
        exit 0
    fi
done < "$PASSFILE"

# 如果没有匹配的用户名密码组合
echo "$(date '+%Y-%m-%d %H:%M:%S') - FAILED: Invalid credentials for user $USERNAME" >> "$LOG_FILE"
exit 1
