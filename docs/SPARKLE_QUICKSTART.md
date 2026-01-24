# Sparkle 快速配置检查清单

快速完成 Sparkle 自动更新的核心配置步骤。

## ✅ 前置检查

- [ ] Xcode 14+ 已安装
- [ ] macOS 12+ 开发环境
- [ ] GitHub 仓库访问权限

## 📋 配置步骤

### 1. 添加 Sparkle SPM 依赖 ⚠️ (Xcode GUI 操作)

1. 打开 `MacOSAIDiskCleaner.xcodeproj`
2. 项目 → MacOSAIDiskCleaner target → "Package Dependencies" 标签
3. 点击 "+" → 输入 URL: `https://github.com/sparkle-project/Sparkle`
4. 选择 Version: `Up to Next Major Version` → `2.0.0`
5. 勾选 Sparkle 库 → "MacOSAIDiskCleaner" target
6. 点击 "Add Package"

**验证**:
```bash
grep -i sparkle MacOSAIDiskCleaner.xcodeproj/project.pbxproj
```

### 2. 生成 EdDSA 密钥对

```bash
# 下载 Sparkle 工具
# 访问: https://github.com/sparkle-project/Sparkle/releases
# 下载并解压: Sparkle-*.tar.xz

# 生成密钥
./Sparkle/bin/generate_keys -p

# 保存私钥 (不要提交到 Git!)
mkdir -p ~/.sparkle_keys
echo "<私钥字符串>" > ~/.sparkle_keys/MacOSAIDiskCleaner_private_key.pem
chmod 600 ~/.sparkle_keys/MacOSAIDiskCleaner_private_key.pem
```

### 3. 配置公钥到 Info.plist

编辑 `MacOSAIDiskCleaner/Info.plist`:

```xml
<key>SUPublicEDKey</key>
<string>你的公钥字符串</string>
```

### 4. 配置 GitHub Secrets

访问: https://github.com/DISSIDIA-986/MacOSAIDiskCleaner/settings/secrets/actions

- **Name**: `SPARKLE_PRIVATE_KEY`
- **Value**: 你的私钥字符串

### 5. 初始化 GitHub Pages

```bash
cd MacOSAIDiskCleaner

# 创建 gh-pages 分支
git checkout --orphan gh-pages
git rm -rf .

# 创建首页
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

访问 https://github.com/DISSIDIA-986/MacOSAIDiskCleaner/settings/pages:
- Source: Branch `gh-pages` / `/ (root)`
- 点击 Save

### 6. 本地测试

```bash
# Clean Build
xcodebuild clean -project MacOSAIDiskCleaner.xcodeproj -scheme MacOSAIDiskCleaner

# 构建
xcodebuild -project MacOSAIDiskCleaner.xcodeproj \
  -scheme MacOSAIDiskCleaner \
  -configuration Release build

# 运行应用并点击 "Check for Updates…"
open build/Release/MacOSAIDiskCleaner.app
```

### 7. 测试完整发布流程

```bash
# 创建测试标签
git tag -a v0.0.1-test -m "Test release"
git push origin v0.0.1-test

# 观察 Actions: https://github.com/DISSIDIA-986/MacOSAIDiskCleaner/actions
# 验证 Release 创建: https://github.com/DISSIDIA-986/MacOSAIDiskCleaner/releases
```

## 🎯 完成检查

- [ ] Sparkle SPM 依赖已添加
- [ ] EdDSA 密钥对已生成
- [ ] 公钥已配置到 Info.plist
- [ ] 私钥已存储到 GitHub Secrets
- [ ] GitHub Pages 已启用
- [ ] 本地构建成功
- [ ] 测试 Release 成功
- [ ] appcast.xml 可访问

## 🚀 发布正式版本

```bash
# 创建生产版本标签
git tag -a v0.1.0 -m "Release v0.1.0"
git push origin v0.1.0

# 自动触发 GitHub Actions
# - 构建 DMG
# - 签名并生成 appcast.xml
# - 创建 GitHub Release
# - 部署到 GitHub Pages
```

## 🔍 验证命令

```bash
# 验证 Sparkle 集成
codesign -dvvv build/Release/MacOSAIDiskCleaner.app | grep -i sparkle

# 验证 appcast.xml
curl -s https://dissidia-986.github.io/MacOSAIDiskCleaner/appcast.xml | xmllint --format -

# 查看版本
plutil -p MacOSAIDiskCleaner/Info.plist | grep CFBundleShortVersionString

# 列出 GitHub Secrets
gh secret list

# 查看 Release
gh release list
```

## ❓ 遇到问题？

详细文档: `docs/SPARKLE_SETUP.md`

常见问题:
- **Sparkle 未集成**: Clean Build (⌘⇧K) → 重新构建
- **appcast.xml 无法访问**: 检查 GitHub Pages 配置
- **签名验证失败**: 验证公私钥匹配
- **Actions 失败**: 检查 GitHub Secrets 配置

## 📚 相关资源

- [完整配置指南](SPARKLE_SETUP.md)
- [Sparkle 官方文档](https://sparkle-project.org/documentation/)
- [实现计划](../cnDocs/implementation_plan.md#sparkle-自动更新集成)

---

**提示**: 第一次配置建议先使用测试标签 (`v0.0.1-test`) 验证完整流程，确认无误后再发布正式版本。
