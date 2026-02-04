#!/bin/bash

# Provider Pull Errors 修复脚本
# 用于诊断和修复 Clash Provider 拉取错误

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Provider URLs
PROVIDERS=(
  "F1 TV|https://raw.dler.io/dler-io/Rules/main/Clash/Provider/Media/F1%20TV.yaml"
  "BBC iPlayer|https://raw.dler.io/dler-io/Rules/main/Clash/Provider/Media/BBC%20iPlayer.yaml"
  "Line TV|https://raw.dler.io/dler-io/Rules/main/Clash/Provider/Media/Line%20TV.yaml"
  "TikTok|https://raw.dler.io/dler-io/Rules/main/Clash/Provider/TikTok.yaml"
)

# 备用 CDN
BACKUP_CDNS=(
  "jsDelivr|https://cdn.jsdelivr.net/gh/dler-io/Rules@main/Clash/Provider"
  "GitHub Raw|https://raw.githubusercontent.com/dler-io/Rules/main/Clash/Provider"
)

# 配置
MAX_RETRIES=3
TIMEOUT=10
OUTPUT_DIR="./providers/rules"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Clash Provider 错误诊断和修复工具${NC}"
echo -e "${BLUE}========================================${NC}\n"

# 函数: 测试 URL 可用性
test_url() {
  local url=$1
  local name=$2
  local retry=$3
  
  if curl -f -s -o /dev/null --max-time $TIMEOUT "$url" 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

# 函数: 下载文件
download_file() {
  local url=$1
  local output=$2
  local name=$3
  
  echo -e "${YELLOW}正在下载: $name${NC}"
  
  for i in $(seq 1 $MAX_RETRIES); do
    if curl -f -s -L --max-time $TIMEOUT -o "$output" "$url" 2>/dev/null; then
      echo -e "${GREEN}✓ 下载成功: $name${NC}"
      return 0
    else
      echo -e "${RED}✗ 第 $i 次尝试失败${NC}"
      if [ $i -lt $MAX_RETRIES ]; then
        sleep 2
      fi
    fi
  done
  
  echo -e "${RED}✗ 下载失败: $name${NC}"
  return 1
}

# 1. 测试网络连接
echo -e "${BLUE}[1/4] 测试网络连接${NC}\n"

echo "测试 raw.dler.io DNS 解析..."
if nslookup raw.dler.io >/dev/null 2>&1; then
  echo -e "${GREEN}✓ DNS 解析成功${NC}\n"
else
  echo -e "${RED}✗ DNS 解析失败${NC}\n"
fi

# 2. 测试原始 Provider URLs
echo -e "${BLUE}[2/4] 测试原始 Provider URLs${NC}\n"

failed_providers=()
for provider_info in "${PROVIDERS[@]}"; do
  IFS='|' read -r name url <<< "$provider_info"
  
  echo -n "测试 $name ... "
  if test_url "$url" "$name"; then
    echo -e "${GREEN}✓ 可用${NC}"
  else
    echo -e "${RED}✗ 不可用${NC}"
    failed_providers+=("$provider_info")
  fi
done

echo ""

# 3. 如果有失败的 Provider，测试备用 CDN
if [ ${#failed_providers[@]} -gt 0 ]; then
  echo -e "${BLUE}[3/4] 测试备用 CDN${NC}\n"
  
  working_cdn=""
  for cdn_info in "${BACKUP_CDNS[@]}"; do
    IFS='|' read -r cdn_name cdn_base <<< "$cdn_info"
    
    echo "测试 $cdn_name..."
    # 测试第一个失败的 provider
    first_failed="${failed_providers[0]}"
    IFS='|' read -r name url <<< "$first_failed"
    
    # 构造备用 URL
    if [[ "$cdn_name" == "jsDelivr" ]]; then
      if [[ "$url" == *"/Media/"* ]]; then
        file_path=$(echo "$url" | sed 's|.*Provider/Media/||')
        test_url="$cdn_base/Media/$file_path"
      else
        file_path=$(echo "$url" | sed 's|.*Provider/||')
        test_url="$cdn_base/$file_path"
      fi
    else
      if [[ "$url" == *"/Media/"* ]]; then
        file_path=$(echo "$url" | sed 's|.*Provider/Media/||')
        test_url="$cdn_base/Media/$file_path"
      else
        file_path=$(echo "$url" | sed 's|.*Provider/||')
        test_url="$cdn_base/$file_path"
      fi
    fi
    
    if test_url "$test_url" "$cdn_name"; then
      echo -e "${GREEN}✓ $cdn_name 可用${NC}\n"
      working_cdn="$cdn_info"
      break
    else
      echo -e "${RED}✗ $cdn_name 不可用${NC}\n"
    fi
  done
  
  # 4. 下载文件到本地
  if [ -n "$working_cdn" ] || [ ${#failed_providers[@]} -lt ${#PROVIDERS[@]} ]; then
    echo -e "${BLUE}[4/4] 下载 Provider 规则到本地${NC}\n"
    
    # 创建输出目录
    mkdir -p "$OUTPUT_DIR"
    
    for provider_info in "${PROVIDERS[@]}"; do
      IFS='|' read -r name url <<< "$provider_info"
      
      # 生成文件名
      filename=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
      output_file="$OUTPUT_DIR/${filename}.yaml"
      
      # 尝试原始 URL
      if test_url "$url" "$name"; then
        download_file "$url" "$output_file" "$name"
      elif [ -n "$working_cdn" ]; then
        # 尝试备用 CDN
        IFS='|' read -r cdn_name cdn_base <<< "$working_cdn"
        
        if [[ "$cdn_name" == "jsDelivr" ]]; then
          if [[ "$url" == *"/Media/"* ]]; then
            file_path=$(echo "$url" | sed 's|.*Provider/Media/||')
            backup_url="$cdn_base/Media/$file_path"
          else
            file_path=$(echo "$url" | sed 's|.*Provider/||')
            backup_url="$cdn_base/$file_path"
          fi
        else
          if [[ "$url" == *"/Media/"* ]]; then
            file_path=$(echo "$url" | sed 's|.*Provider/Media/||')
            backup_url="$cdn_base/Media/$file_path"
          else
            file_path=$(echo "$url" | sed 's|.*Provider/||')
            backup_url="$cdn_base/$file_path"
          fi
        fi
        
        download_file "$backup_url" "$output_file" "$name (via $cdn_name)"
      fi
    done
    
    echo ""
    echo -e "${GREEN}文件已下载到: $OUTPUT_DIR${NC}\n"
  fi
else
  echo -e "${GREEN}所有 Provider 都可用！${NC}\n"
  echo -e "${BLUE}[3/4] 跳过备用 CDN 测试${NC}\n"
  echo -e "${BLUE}[4/4] 跳过本地下载${NC}\n"
fi

# 生成配置建议
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}配置建议${NC}"
echo -e "${BLUE}========================================${NC}\n"

if [ ${#failed_providers[@]} -eq 0 ]; then
  echo "当前所有 Provider 都可以访问。"
  echo "如果 Clash 仍然报错，请检查："
  echo "1. Clash 的超时配置"
  echo "2. 系统防火墙设置"
  echo "3. 代理配置是否正确"
else
  echo "检测到以下 Provider 无法访问："
  for provider_info in "${failed_providers[@]}"; do
    IFS='|' read -r name url <<< "$provider_info"
    echo "  - $name"
  done
  echo ""
  
  if [ -n "$working_cdn" ]; then
    IFS='|' read -r cdn_name cdn_base <<< "$working_cdn"
    echo -e "${GREEN}建议方案 1: 使用 $cdn_name${NC}"
    echo "将 Clash 配置中的 Provider URL 替换为："
    echo "  $cdn_base/..."
    echo ""
  fi
  
  if [ -d "$OUTPUT_DIR" ] && [ "$(ls -A $OUTPUT_DIR)" ]; then
    echo -e "${GREEN}建议方案 2: 使用本地文件${NC}"
    echo "修改 Clash 配置使用本地 Provider："
    echo ""
    echo "rule-providers:"
    for provider_info in "${PROVIDERS[@]}"; do
      IFS='|' read -r name url <<< "$provider_info"
      filename=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
      key=$(echo "$name" | tr ' ' '-')
      echo "  $key:"
      echo "    type: file"
      echo "    behavior: classical"
      echo "    path: $OUTPUT_DIR/${filename}.yaml"
      echo ""
    done
  fi
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}诊断完成${NC}"
echo -e "${BLUE}========================================${NC}"
