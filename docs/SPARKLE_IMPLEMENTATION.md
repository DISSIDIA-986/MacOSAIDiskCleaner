# Sparkle 自动更新实现完成

## ✅ 已完成的工作

### 1. 代码实现

#### UpdateManager.swift (`MacOSAIDiskCleaner/Features/Updates/UpdateManager.swift`)
- ✅ 完整的 SPUUpdaterDelegate 实现
- ✅ @Published 状态管理属性
- ✅ 版本信息查询方法
- ✅ 自动更新控制方法
- ✅ 详细的日志记录 (Logger.appupdates)

#### Info.plist (`MacOSAIDiskCleaner/Info.plist`)
- ✅ SUFeedURL 配置 (GitHub Pages URL)
- ✅ SUPublicEDKey 占位符 (需要替换为实际公钥)
- ✅ SUScheduledCheckInterval (24 小时)
- ✅ SUEnableAutomaticChecks (启用自动检查)

#### Logger.swift (`MacOSAIDiskCleaner/Core/Logging/Logger.swift`)
- ✅ 添加 appupdates 日志类别

### 2. 自动化脚本

#### generate_appcast.sh (`scripts/generate_appcast.sh`)
- ✅ EdDSA 签名生成
- ✅ appcast.xml 生成 (Sparkle 2.x 兼容)
- ✅ XML 格式验证
- ✅ 详细的错误处理和日志
- ✅ 执行权限设置

#### Release Workflow (`.github/workflows/release.yml`)
- ✅ 版本号自动提取 (从 Git tag)
- ✅ Info.plist 动态更新
- ✅ Sparkle 签名工具自动安装
- ✅ DMG 创建 (APFS 格式 + 压缩)
- ✅ EdDSA 签名生成
- ✅ appcast.xml 自动生成
- ✅ GitHub Release 创建
- ✅ GitHub Pages 自动部署

### 3. 文档

- ✅ **SPARKLE_SETUP.md**: 完整配置指南 (7 个章节)
- ✅ **SPARKLE_QUICKSTART.md**: 快速检查清单
- ✅ **SPARKLE_SUMMARY.md**: 技术架构详解

## ⚠️ 需要手动完成的步骤

### 步骤 1: 添加 Sparkle SPM 依赖 (必须使用 Xcode GUI)

这是唯一无法自动化的步骤，需要在 Xcode 中手动操作:

1. 打开 `MacOSAIDiskCleaner.xcodeproj`
2. 选择项目 → MacOSAIDiskCleaner target → "Package Dependencies" 标签
3. 点击 "+" → 输入: `https://github.com/sparkle-project/Sparkle`
4. 选择版本: `Up to Next Major Version` → `2.0.0`
5. 确保 Sparkle 库被勾选 → "MacOSAIDiskCleaner" target
6. 点击 "Add Package"
7. Clean Build Folder (⌘⇧K) → 重新构建

**验证命令**:
```bash
grep -i sparkle MacOSAIDiskCleaner.xcodeproj/project.pbxproj
```

### 步骤 2: 生成 EdDSA 密钥对

```bash
# 1. 下载 Sparkle 工具
# 访问: https://github.com/sparkle-project/Sparkle/releases
# 下载并解压: Sparkle-*.tar.xz

# 2. 生成密钥
./Sparkle/bin/generate_keys -p

# 输出示例:
# Private key: <私钥字符串>
# Public key:  <公钥字符串>

# 3. 保存私钥到本地 (不要提交到 Git!)
mkdir -p ~/.sparkle_keys
echo "<私钥字符串>" > ~/.sparkle_keys/MacOSAIDiskCleaner_private_key.pem
chmod 600 ~/.sparkle_keys/MacOSAIDiskCleaner_private_key.pem

# 4. 配置公钥到 Info.plist
# 编辑 MacOSAIDiskCleaner/Info.plist:
# <key>SUPublicEDKey</key>
# <string><公钥字符串></string>
```

### 步骤 3: 配置 GitHub Secrets

1. 访问: https://github.com/DISSIDIA-986/MacOSAIDiskCleaner/settings/secrets/actions
2. 点击 "New repository secret"
3. Name: `SPARKLE_PRIVATE_KEY`
4. Value: `<你的私钥字符串>`
5. 点击 "Add secret"

**验证**:
```bash
gh secret list
# 应显示: SPARKLE_PRIVATE_KEY  Updated  ...
```

### 步骤 4: 初始化 GitHub Pages

```bash
cd /Users/niuyp/Documents/github.com/MacOSAIDiskCleaner

# 创建 gh-pages 分支
git checkout --orphan gh-pages
git rm -rf .

# 创建重定向首页
cat > index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>MacOS AI Disk Cleaner Updates</title>
    <meta http-equiv="refresh" content="0;url=https://github.com/DISSIDIA-986/MacOSAIDiskCleaner/releases">
</head>
<body><p>Redirecting...</p></body>
</html>
EOF

git add .
git commit -m "Initialize GitHub Pages"
git push origin gh-pages
git checkout main
```

然后访问: https://github.com/DISSIDIA-986/MacOSAIDiskCleaner/settings/pages
- Source: Branch `gh-pages` / `/ (root)`
- 点击 Save

### 步骤 5: 测试完整流程

```bash
# 1. 本地测试构建
xcodebuild clean -project MacOSAIDiskCleaner.xcodeproj -scheme MacOSAIDiskCleaner
xcodebuild -project MacOSAIDiskCleaner.xcodeproj \
  -scheme MacOSAIDiskCleaner \
  -configuration Release build

# 2. 运行应用
open build/Release/MacOSAIDiskCleaner.app

# 3. 点击 "Check for Updates…"
# 应该显示更新检查对话框 (或 "Already on latest version")

# 4. 创建测试版本
git tag -a v0.0.1-test -m "Test release"
git push origin v0.0.1-test

# 5. 观察 Actions 执行
# 访问: https://github.com/DISSIDIA-986/MacOSAIDiskCleaner/actions

# 6. 验证输出
gh release view v0.0.1-test
curl -s https://dissidia-986.github.io/MacOSAIDiskCleaner/appcast.xml
```

## 📁 文件清单

### 新建文件

```
scripts/generate_appcast.sh          # appcast.xml 生成脚本 (可执行)
.github/workflows/release.yml        # 自动发布工作流
docs/SPARKLE_SETUP.md                # 完整配置指南
docs/SPARKLE_QUICKSTART.md           # 快速开始指南
docs/SPARKLE_SUMMARY.md              # 技术架构详解
```

### 修改文件

```
MacOSAIDiskCleaner/Features/Updates/UpdateManager.swift  # 增强 UpdateManager
MacOSAIDiskCleaner/Info.plist                            # 更新 Sparkle 配置
MacOSAIDiskCleaner/Core/Logging/Logger.swift              # 添加 appupdates 类别
```

## 🚀 如何使用

### 日常发布流程

完成上述配置后，发布新版本只需:

```bash
# 1. 创建版本标签
git tag -a v0.1.0 -m "Release v0.1.0"

# 2. 推送标签 (自动触发 GitHub Actions)
git push origin v0.1.0

# 3. 等待 5-10 分钟，访问 Releases 页面验证
# https://github.com/DISSIDIA-986/MacOSAIDiskCleaner/releases
```

**自动化步骤**:
- ✅ 提取版本号
- ✅ 更新 Info.plist
- ✅ 构建 Release 版本
- ✅ 创建 DMG
- ✅ 生成签名
- ✅ 创建 appcast.xml
- ✅ 发布到 GitHub Releases
- ✅ 部署到 GitHub Pages

### 用户更新体验

1. 应用启动时自动检查更新 (每 24 小时)
2. 或用户手动点击 "Check for Updates…"
3. 发现新版本时显示提示
4. 用户点击 "Install Update"
5. 下载 DMG (后台)
6. 验证 EdDSA 签名
7. 安装并提示重启

## 🔒 安全考虑

### 已实现的安全措施

- ✅ **EdDSA 签名**: 所有更新包都经过签名验证
- ✅ **私钥保护**: 存储在 GitHub Secrets，不暴露在代码中
- ✅ **HTTPS 传输**: appcast.xml 通过 HTTPS 托管
- ✅ **公钥内置**: 硬编码在 Info.plist 中
- ✅ **条件编译**: 未集成 Sparkle 时应用仍可运行

### 安全最佳实践

- ❌ **不要将私钥提交到 Git**
- ✅ **定期轮换密钥** (建议每年一次)
- ✅ **监控 GitHub Actions 日志**
- ✅ **验证每次发布的签名**

## 📚 文档导航

| 文档 | 用途 | 何时阅读 |
|------|------|---------|
| `SPARKLE_QUICKSTART.md` | 快速配置检查清单 | 第一次配置时 |
| `SPARKLE_SETUP.md` | 完整配置指南 | 遇到问题时 |
| `SPARKLE_SUMMARY.md` | 技术架构详解 | 深入理解实现 |

## ❓ 常见问题

### Q: 为什么必须使用 Xcode GUI 添加 SPM 依赖?
A: Xcode 项目文件 (project.pbxproj) 是复杂的二进制/文本混合格式，手动编辑容易破坏项目结构。Xcode GUI 是最安全可靠的方式。

### Q: 如何验证 Sparkle 已正确集成?
A:
```bash
# 1. 验证 SPM 依赖
grep -i sparkle MacOSAIDiskCleaner.xcodeproj/project.pbxproj

# 2. 验证代码签名
codesign -dvvv build/Release/MacOSAIDiskCleaner.app | grep -i sparkle

# 3. 运行应用并检查更新
open build/Release/MacOSAIDiskCleaner.app
# 点击 "Check for Updates…"
```

### Q: 私钥丢失怎么办?
A:
1. 重新生成密钥对: `./Sparkle/bin/generate_keys -p`
2. 更新 Info.plist (公钥)
3. 更新 GitHub Secrets (私钥)
4. 重新发布应用 (包含新公钥)

### Q: 如何在开发环境禁用自动更新?
A: UpdateManager 使用条件编译，如果 SPM 依赖未添加，所有更新功能都会安全降级。或者可以临时修改 Info.plist:
```xml
<key>SUEnableAutomaticChecks</key>
<false/>
```

### Q: Actions 执行失败怎么办?
A:
1. 检查 GitHub Secrets: `gh secret list`
2. 查看 Actions 日志 (GitHub Actions 页面)
3. 常见错误:
   - "SPARKLE_PRIVATE_KEY not set": 配置 GitHub Secret
   - "Failed to sign DMG": 验证私钥格式
   - "Failed to create release": 检查 token 权限

## 🎯 下一步行动

1. **立即完成**: 步骤 1 (添加 SPM 依赖) - 这会解锁后续所有功能
2. **接下来完成**: 步骤 2-3 (密钥生成和 Secrets 配置)
3. **然后完成**: 步骤 4-5 (GitHub Pages 初始化和测试)
4. **验证成功后**: 发布第一个正式版本 v0.1.0

## 💡 提示

- 第一次配置建议使用测试标签 (如 `v0.0.1-test`)
- 验证完整流程无误后再发布正式版本
- 保存好私钥的备份 (推荐使用密码管理器)
- 定期检查 Sparkle 框架更新

---

**构建状态**: ✅ BUILD SUCCEEDED
**最后更新**: 2025-01-23
**Sparkle 版本**: 2.x
**最低系统要求**: macOS 12.0+

**需要帮助?** 查看 `docs/SPARKLE_SETUP.md` 或提交 GitHub Issue
