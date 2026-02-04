# Clash Provider Pull Errors 解决方案

本仓库提供了针对 Clash Provider 拉取 EOF 错误的完整分析和解决方案。

## 问题描述

在使用 Clash 时，可能会遇到以下错误：

```
ERROR [Provider] F1 TV pull error: Get "https://raw.dler.io/...": EOF
ERROR [Provider] BBC iPlayer pull error: Get "https://raw.dler.io/...": EOF
ERROR [Provider] Line TV pull error: Get "https://raw.dler.io/...": EOF
ERROR [Provider] TikTok pull error: Get "https://raw.dler.io/...": EOF
```

这些 EOF (End of File) 错误通常由以下原因引起：
- 网络连接不稳定
- raw.dler.io 服务不可用
- DNS 解析问题
- 防火墙阻止
- 超时设置过短

## 文件说明

### 1. `provider-pull-errors-analysis.md`
详细的问题分析文档，包括：
- 根本原因分析
- 5种解决方案
- 诊断步骤
- 实施建议

### 2. `fix-provider-errors.sh`
自动化诊断和修复脚本，功能包括：
- 测试网络连接和 DNS 解析
- 检测所有 Provider URL 的可用性
- 自动测试备用 CDN (jsDelivr, GitHub Raw)
- 下载 Provider 规则文件到本地
- 生成配置建议

### 3. `clash-config-example.yaml`
完整的 Clash 配置示例，展示：
- 4种不同的 Provider 配置方案
- 如何使用 jsDelivr CDN
- 如何配置本地文件
- 健康检查和超时设置
- 完整的规则配置

## 快速开始

### 方法 1: 使用自动修复脚本 (推荐)

```bash
# 1. 赋予脚本执行权限
chmod +x fix-provider-errors.sh

# 2. 运行诊断脚本
./fix-provider-errors.sh
```

脚本会自动：
- 诊断网络问题
- 测试所有 Provider URL
- 查找可用的备用 CDN
- 下载规则文件到 `./providers/rules/` 目录
- 提供配置建议

### 方法 2: 手动配置

#### 选项 A: 使用 jsDelivr CDN (最简单)

修改 Clash 配置文件，将原来的 URL:
```yaml
https://raw.dler.io/dler-io/Rules/main/Clash/Provider/Media/F1%20TV.yaml
```

替换为:
```yaml
https://cdn.jsdelivr.net/gh/dler-io/Rules@main/Clash/Provider/Media/F1%20TV.yaml
```

#### 选项 B: 使用本地文件 (最稳定)

1. 创建目录：
```bash
mkdir -p ./providers/rules
```

2. 下载规则文件：
```bash
curl -o ./providers/rules/f1-tv.yaml \
  "https://cdn.jsdelivr.net/gh/dler-io/Rules@main/Clash/Provider/Media/F1%20TV.yaml"

curl -o ./providers/rules/bbc-iplayer.yaml \
  "https://cdn.jsdelivr.net/gh/dler-io/Rules@main/Clash/Provider/Media/BBC%20iPlayer.yaml"

curl -o ./providers/rules/line-tv.yaml \
  "https://cdn.jsdelivr.net/gh/dler-io/Rules@main/Clash/Provider/Media/Line%20TV.yaml"

curl -o ./providers/rules/tiktok.yaml \
  "https://cdn.jsdelivr.net/gh/dler-io/Rules@main/Clash/Provider/TikTok.yaml"
```

3. 修改 Clash 配置：
```yaml
rule-providers:
  F1-TV:
    type: file
    behavior: classical
    path: ./providers/rules/f1-tv.yaml
    
  BBC-iPlayer:
    type: file
    behavior: classical
    path: ./providers/rules/bbc-iplayer.yaml
```

## 解决方案对比

| 方案 | 稳定性 | 实施难度 | 维护成本 | 推荐度 |
|------|--------|----------|----------|--------|
| jsDelivr CDN | ⭐⭐⭐⭐ | ⭐ | ⭐ | ⭐⭐⭐⭐⭐ |
| 本地文件 | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| GitHub Raw | ⭐⭐⭐ | ⭐ | ⭐ | ⭐⭐⭐ |
| 原始 URL + 重试 | ⭐⭐ | ⭐⭐ | ⭐⭐ | ⭐⭐ |

## 诊断工具

### 测试 Provider 可用性
```bash
# 测试原始 URL
curl -v "https://raw.dler.io/dler-io/Rules/main/Clash/Provider/Media/F1%20TV.yaml"

# 测试 jsDelivr CDN
curl -v "https://cdn.jsdelivr.net/gh/dler-io/Rules@main/Clash/Provider/Media/F1%20TV.yaml"

# 测试 DNS 解析
nslookup raw.dler.io
```

### 查看 Clash 日志
```bash
# 实时查看日志
tail -f ~/.config/clash/logs/clash.log

# 或使用 systemd (如果适用)
journalctl -u clash -f
```

## 常见问题 (FAQ)

### Q1: 为什么会出现 EOF 错误？
**A:** EOF 错误表示连接在数据传输过程中被意外关闭。常见原因包括网络不稳定、服务器负载过高、DNS 问题或防火墙拦截。

### Q2: jsDelivr CDN 是什么？
**A:** jsDelivr 是一个免费的全球 CDN，可以加速 GitHub 仓库内容的访问。它比直接访问 GitHub Raw 更稳定可靠。

### Q3: 本地文件需要定期更新吗？
**A:** 是的。Provider 规则会定期更新以适应服务变化。建议每月更新一次，或使用脚本自动更新。

### Q4: 如何自动更新本地规则文件？
**A:** 可以创建一个 cron 任务：
```bash
# 编辑 crontab
crontab -e

# 添加每周日凌晨 3 点更新
0 3 * * 0 /path/to/fix-provider-errors.sh
```

### Q5: 所有 Provider 都失败怎么办？
**A:** 这通常表示 raw.dler.io 服务整体不可用。建议：
1. 立即切换到 jsDelivr CDN
2. 或使用已下载的本地文件
3. 检查 GitHub 仓库是否还在维护: https://github.com/dler-io/Rules

## 配置最佳实践

1. **使用本地缓存**: 即使使用 HTTP URL，也要配置 `path` 参数启用本地缓存
2. **合理设置更新间隔**: `interval: 86400` (24小时) 通常足够
3. **配置健康检查**: 对 proxy-providers 启用 health-check
4. **使用多个备用源**: 准备 jsDelivr 和本地文件两套配置
5. **监控日志**: 定期检查 Clash 日志，及时发现问题

## 示例配置

查看 `clash-config-example.yaml` 获取完整配置示例，包括：
- 4种 Provider 配置方式
- DNS 配置
- 代理组设置
- 规则配置
- 详细注释说明

## 相关资源

- **Clash 官方文档**: https://clash.wiki/
- **Clash Meta 文档**: https://wiki.metacubex.one/
- **dler-io Rules 仓库**: https://github.com/dler-io/Rules
- **jsDelivr CDN**: https://www.jsdelivr.com/
- **Clash for Windows**: https://github.com/Fndroid/clash_for_windows_pkg
- **ClashX (macOS)**: https://github.com/yichengchen/clashX

## 贡献

欢迎提交 Issue 和 Pull Request 来改进本解决方案。

## 许可证

MIT License

## 更新日志

- **2026-02-04**: 初始版本
  - 添加详细问题分析文档
  - 创建自动修复脚本
  - 提供完整配置示例
  - 编写使用说明
