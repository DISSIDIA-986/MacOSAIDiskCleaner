# Sparkle 自动更新配置指南

本指南详细说明如何为 MacOSAIDiskCleaner 配置 Sparkle 自动更新功能。

## 概述

**架构流程**:
```
App → Sparkle Framework → GitHub Pages (appcast.xml) → GitHub Releases (DMG)
```

**安全机制**:
- **EdDSA 签名**: 所有更新包都使用 EdDSA 私钥签名
- **公钥验证**: App 内置公钥，验证下载的更新包
- **HTTPS 传输**: appcast.xml 通过 HTTPS 安全传输

## 前置要求

- Xcode 14+ (Swift Package Manager 支持)
- macOS 12+ (开发环境)
- GitHub 账号 (用于托管和发布)

## 配置步骤

### 步骤 1: 添加 Sparkle SPM 依赖

**⚠️ 此步骤需要 Xcode GUI 操作，无法自动化**

1. 打开 `MacOSAIDiskCleaner.xcodeproj`

2. 选择项目导航器中的项目文件 → **MacOSAIDiskCleaner** target

3. 选择 **"Package Dependencies"** 标签

4. 点击 **"+"** 按钮

5. 在搜索框中输入 Sparkle 包 URL:
   ```
   https://github.com/sparkle-project/Sparkle
   ```
   或选择 Sparkle（如果出现在推荐列表中）

6. 在 **"Dependency Rule"** 中选择:
   - **Version**: `Up to Next Major Version`
   - **Minimum**: `2.0.0`

7. 在 **"Choose Package Products"** 中确保:
   - ✅ 勾选 **Sparkle** 库
   - ✅ **MacOSAIDiskCleaner** target 被选中

8. 点击 **"Add Package"**

9. Xcode 会自动解析并下载 Sparkle 依赖

10. 验证安装成功:
    ```bash
    grep -i sparkle MacOSAIDiskCleaner.xcodeproj/project.pbxproj
    ```
    应该能看到 Sparkle 相关的引用

**故障排查**:
- 如果遇到解析错误，尝试切换网络或使用 VPN
- 确保 Xcode 版本 ≥ 14.0
- Clean Build Folder (⌘⇧K) 后重新构建

### 步骤 2: 生成 EdDSA 密钥对

**⚠️ 私钥绝对不能提交到 Git 仓库**

#### 2.1 下载 Sparkle 工具

1. 访问 Sparkle Releases 页面:
   https://github.com/sparkle-project/Sparkle/releases

2. 下载最新版本的 `Sparkle-<version>.tar.xz`

3. 解压归档文件:
   ```bash
   tar xf Sparkle-*.tar.xz
   cd Sparkle
   ```

#### 2.2 生成密钥对

```bash
# 使用 Sparkle 提供的工具
./bin/generate_keys -p

# 输出示例:
# ╔══════════════════════════════════════════════════════════════════════╗
# ║  EdDSA signing keys successfully generated                            ║
# ╚══════════════════════════════════════════════════════════════════════╝
#
# Private key: <私钥字符串>
# Public key:  <公钥字符串>
```

**重要**:
- ✅ **妥善保管私钥** - 丢失后无法恢复
- ✅ **备份私钥到安全位置** - 建议使用密码管理器
- ❌ **不要分享私钥** - 仅用于可信的 CI/CD 环境

#### 2.3 存储私钥

**本地开发环境**:
```bash
# 创建密钥存储目录
mkdir -p ~/.sparkle_keys
chmod 700 ~/.sparkle_keys

# 保存私钥到文件
echo "<你的私钥字符串>" > ~/.sparkle_keys/MacOSAIDiskCleaner_private_key.pem
chmod 600 ~/.sparkle_keys/MacOSAIDiskCleaner_private_key.pem

# 验证权限
ls -la ~/.sparkle_keys/
# 应显示: -rw------- (600 权限)
```

**GitHub Actions (生产环境)**:
1. 访问 GitHub 仓库设置:
   https://github.com/DISSIDIA-986/MacOSAIDiskCleaner/settings/secrets/actions

2. 点击 **"New repository secret"**

3. 创建 Secret:
   - **Name**: `SPARKLE_PRIVATE_KEY`
   - **Value**: `<你的私钥字符串>`

4. 点击 **"Add secret"**

**验证 Secret 配置**:
```bash
# 列出仓库的 secrets (需要 admin 权限)
gh secret list
# 应显示: SPARKLE_PRIVATE_KEY  Updated  ...
```

#### 2.4 配置公钥到 Info.plist

公钥需要硬编码到应用的 Info.plist 中（这是 Sparkle 的安全设计）。

1. 打开 `MacOSAIDiskCleaner/Info.plist`

2. 找到 `SUPublicEDKey` 键:
   ```xml
   <key>SUPublicEDKey</key>
   <string>REPLACE_WITH_YOUR_GENERATED_PUBLIC_KEY_HERE</string>
   ```

3. 替换为你生成的公钥:
   ```xml
   <key>SUPublicEDKey</key>
   <string>kW4IzdUU0PCvRa4yQ1qvQZjJ/ZHKqJ/jPfV2PEbZatg=</string>
   ```

4. 保存文件

**验证公钥格式**:
- 公钥应该是 Base64 编码的字符串
- 长度通常为 44 个字符
- 不包含换行符或空格

### 步骤 3: 配置 GitHub Pages

GitHub Pages 用于托管 `appcast.xml` 更新订阅源。

#### 3.1 初始化 gh-pages 分支

```bash
cd /path/to/MacOSAIDiskCleaner

# 创建孤儿分支（无历史记录）
git checkout --orphan gh-pages

# 清空工作目录（但保留 .git）
git rm -rf .

# 创建重定向首页
cat > index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>MacOS AI Disk Cleaner Updates</title>
    <meta http-equiv="refresh" content="0;url=https://github.com/DISSIDIA-986/MacOSAIDiskCleaner/releases">
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background: #f5f5f7;
        }
        p {
            color: #666;
            font-size: 18px;
        }
    </style>
</head>
<body>
    <p>Redirecting to GitHub Releases…</p>
</body>
</html>
EOF

# 提交初始内容
git add .
git commit -m "Initialize GitHub Pages"
git push origin gh-pages

# 切回 main 分支
git checkout main
```

#### 3.2 启用 GitHub Pages

1. 访问仓库设置页面:
   https://github.com/DISSIDIA-986/MacOSAIDiskCleaner/settings/pages

2. 配置 **Source**:
   - **Branch**: `gh-pages`
   - **Folder**: `/ (root)`

3. 点击 **"Save"**

4. 等待 GitHub 部署（通常需要 1-2 分钟）

5. 验证部署:
   - 访问: https://dissidia-986.github.io/MacOSAIDiskCleaner/
   - 应该看到重定向页面

### 步骤 4: 验证 Info.plist 配置

检查 `MacOSAIDiskCleaner/Info.plist` 中的 Sparkle 配置:

```xml
<!-- Sparkle 自动更新配置 -->
<key>SUFeedURL</key>
<string>https://dissidia-986.github.io/MacOSAIDiskCleaner/appcast.xml</string>

<key>SUPublicEDKey</key>
<string>YOUR_ACTUAL_PUBLIC_KEY_HERE</string>

<key>SUScheduledCheckInterval</key>
<integer>86400</integer>  <!-- 每 24 小时检查一次 -->

<key>SUEnableAutomaticChecks</key>
<true/>  <!-- 启用自动检查 -->
```

**配置说明**:
- `SUFeedURL`: appcast.xml 的 HTTPS 地址
- `SUPublicEDKey`: EdDSA 公钥（必须与私钥匹配）
- `SUScheduledCheckInterval`: 自动检查间隔（秒）
- `SUEnableAutomaticChecks`: 是否启用自动更新检查

### 步骤 5: 本地测试

#### 5.1 构建应用

```bash
# Clean Build
xcodebuild clean -project MacOSAIDiskCleaner.xcodeproj -scheme MacOSAIDiskCleaner

# 构建 Release 版本
xcodebuild -project MacOSAIDiskCleaner.xcodeproj \
  -scheme MacOSAIDiskCleaner \
  -configuration Release build

# 验证 Sparkle 已集成
codesign -dvvv build/Release/MacOSAIDiskCleaner.app 2>&1 | grep -i sparkle
# 应该看到 Sparkle.framework 的引用
```

#### 5.2 测试更新检查

1. 运行应用:
   ```bash
   open build/Release/MacOSAIDiskCleaner.app
   ```

2. 点击应用菜单:
   **macOS AI Disk Cleaner → Check for Updates…**

3. 预期行为:
   - ✅ 如果 Sparkle 已集成: 显示更新检查对话框
   - ❌ 如果未集成: 显示 "Sparkle 未集成" 警告

#### 5.3 查看 Sparkle 日志

```bash
# 在 Console.app 中过滤 Sparkle 日志
log stream --predicate 'process == "MacOSAIDiskCleaner"' --level debug
```

或者打开 **Console.app**，搜索:
```
com.Sparkle.Sparkle
```

### 步骤 6: 测试完整发布流程

#### 6.1 创建测试版本

```bash
# 确保在 main 分支
git checkout main
git pull origin main

# 创建测试标签
git tag -a v0.0.1-test -m "Test release for Sparkle integration"

# 推送标签（触发 GitHub Actions）
git push origin v0.0.1-test
```

#### 6.2 监控 Actions 执行

1. 访问 Actions 页面:
   https://github.com/DISSIDIA-986/MacOSAIDiskCleaner/actions

2. 点击 **"Release"** workflow run

3. 查看执行日志:
   - ✅ 所有步骤应该成功完成
   - ✅ DMG 应该被上传到 Release
   - ✅ appcast.xml 应该被部署到 gh-pages

4. 验证输出:
   ```bash
   # 列出 Release
   gh release view v0.0.1-test

   # 验证 DMG 下载链接
   # 应该看到: MacOSAIDiskCleaner-0.0.1-test.dmg
   ```

#### 6.3 验证 appcast.xml

```bash
# 下载并检查 appcast.xml
curl -s https://dissidia-986.github.io/MacOSAIDiskCleaner/appcast.xml | xmllint --format -

# 应该看到结构良好的 XML，包含:
# - <sparkle:version>0.0.1-test</sparkle:version>
# - <enclosure url="..." sparkle:edSignature="..." />
```

#### 6.4 端到端测试

1. **安装旧版本**:
   ```bash
   # 下载测试版本 DMG
   gh release download v0.0.1-test -p "*.dmg"

   # 挂载 DMG
   hdiutil attach MacOSAIDiskCleaner-0.0.1-test.dmg

   # 复制到 Applications
   cp -R /Volumes/MacOS\ AI\ Disk\ Cleaner/MacOSAIDiskCleaner.app /Applications/

   # 卸载 DMG
   hdiutil detach /Volumes/MacOS\ AI\ Disk\ Cleaner/
   ```

2. **运行应用并检查更新**:
   - 打开应用
   - 点击 **Check for Updates…**
   - 应该提示 "No update available" (因为已安装最新版本)

3. **创建新版本并测试**:
   ```bash
   # 修改代码（例如更新版本显示）
   # 提交并创建新标签 v0.0.2-test

   # 在旧版本应用中再次检查更新
   # 应该提示发现新版本 v0.0.2-test
   ```

### 步骤 7: 发布到生产环境

完成测试后，可以发布正式版本:

```bash
# 创建正式版本标签
git tag -a v0.1.0 -m "Release v0.1.0: Initial stable release"

# 推送标签（自动触发发布流程）
git push origin v0.1.0
```

**发布流程**:
1. GitHub Actions 自动构建 DMG
2. 生成签名并创建 appcast.xml
3. 发布到 GitHub Releases
4. 部署 appcast.xml 到 GitHub Pages
5. 用户应用检测到更新并提示下载

## 故障排查

### 问题 1: Sparkle 未导入

**症状**: 运行时显示 "Sparkle 未集成" 警告

**解决方案**:
1. 验证 SPM 依赖已添加:
   ```bash
   grep -i sparkle MacOSAIDiskCleaner.xcodeproj/project.pbxproj
   ```

2. Clean Build Folder (⌘⇧K)

3. 重新构建项目

4. 检查 target membership:
   - 选择 `Sparkle` 框架
   - 在右侧 inspector 中验证 "MacOSAIDiskCleaner" target 被勾选

### 问题 2: appcast.xml 无法访问

**症状**: 更新检查失败，日志显示 appcast.xml 下载失败

**解决方案**:
1. 验证 GitHub Pages 是否启用:
   ```bash
   curl -I https://dissidia-986.github.io/MacOSAIDiskCleaner/appcast.xml
   # 应返回: HTTP/1.1 200 OK
   ```

2. 检查 gh-pages 分支是否存在 appcast.xml:
   ```bash
   git checkout gh-pages
   ls -la appcast.xml
   ```

3. 如果缺少 appcast.xml，手动运行:
   ```bash
   # 回到 main 分支
   git checkout main

   # 重新触发 release workflow
   # 或者手动生成 appcast
   ./scripts/generate_appcast.sh "0.1.0" "build/MacOSAIDiskCleaner-0.1.0.dmg" "~/.sparkle_keys/MacOSAIDiskCleaner_private_key.pem"
   ```

### 问题 3: 签名验证失败

**症状**: 日志显示 "Invalid signature" 或 "Signature verification failed"

**解决方案**:
1. 验证公私钥匹配:
   ```bash
   # 本地测试签名
   ./Sparkle/bin/sign_update test.dmg ~/.sparkle_keys/MacOSAIDiskCleaner_private_key.pem
   ```

2. 检查 Info.plist 中的公钥:
   ```bash
   plutil -p MacOSAIDiskCleaner/Info.plist | grep SUPublicEDKey
   ```

3. 重新生成密钥对并更新:
   ```bash
   # 生成新密钥
   ./Sparkle/bin/generate_keys -p

   # 更新 Info.plist 中的公钥
   # 更新 GitHub Secrets 中的私钥
   # 重新触发 release
   ```

### 问题 4: GitHub Actions 失败

**症状**: Release workflow 执行失败

**解决方案**:
1. 检查 Secrets 是否配置:
   ```bash
   gh secret list
   # 应显示: SPARKLE_PRIVATE_KEY
   ```

2. 验证仓库权限:
   - Settings → Actions → General
   - Workflow permissions: **Read and write permissions**

3. 查看详细的 Actions 日志:
   - 点击失败的 job
   - 展开每个步骤查看错误信息

4. 常见错误:
   - "SPARKLE_PRIVATE_KEY not set": 配置 GitHub Secret
   - "Failed to sign DMG": 验证私钥格式正确
   - "Failed to create release": 检查 token 权限

### 问题 5: DMG 无法安装

**症状**: 下载的 DMG 无法挂载或安装失败

**解决方案**:
1. 验证 DMG 完整性:
   ```bash
   hdiutil attach -readonly -nobrowse test.dmg
   ```

2. 检查代码签名:
   ```bash
   codesign -dvvv MacOSAIDiskCleaner.app
   ```

3. 验证 DMG 中没有符号链接问题:
   ```bash
   hdiutil attach test.dmg -readonly -nobrowse -mountpoint /tmp/test_mount
   ls -la /tmp/test_mount/MacOSAIDiskCleaner.app/Contents/Frameworks
   # Sparkle.framework 应该是符号链接或正常目录
   hdiutil detach /tmp/test_mount
   ```

## 安全性最佳实践

### 密钥管理

✅ **推荐做法**:
- 私钥存储在密码管理器中
- 使用环境变量或 Secrets 管理
- 设置严格的文件权限 (600)
- 定期轮换密钥（如果怀疑泄露）

❌ **避免做法**:
- 将私钥提交到 Git 仓库
- 在明文配置文件中存储私钥
- 在不安全的渠道传输私钥
- 与团队成员共享私钥

### CI/CD 安全

1. **限制 Secret 访问**:
   - 仅必要的 workflow 访问私钥
   - 使用环境特定的 secrets（开发/生产）

2. **审计日志**:
   - 定期检查 GitHub Actions 使用情况
   - 监控异常的 release 活动

3. **最小权限原则**:
   - workflow tokens 仅授予必要权限
   - 避免使用 `permissions: write-all`

### 更新安全

1. **HTTPS 传输**:
   - appcast.xml 必须通过 HTTPS 托管
   - 避免使用 HTTP（会触发安全警告）

2. **签名验证**:
   - 始终验证 EdDSA 签名
   - 拒绝未签名或签名无效的更新包

3. **版本控制**:
   - 使用语义化版本号 (SemVer)
   - 记录每个版本的变更日志

## 维护和更新

### 定期任务

**每月**:
- 检查 Sparkle 框架更新
- 审查 GitHub Actions 日志
- 验证 appcast.xml 可访问性

**每次发布前**:
- 测试完整更新流程
- 验证签名和公钥匹配
- 更新 CHANGELOG.md

**每次发布后**:
- 验证用户可以正常更新
- 监控错误报告
- 备份发布版本

### Sparkle 框架升级

```bash
# 1. 更新 SPM 依赖
# 在 Xcode 中: File → Packages → Update to Latest Package Versions

# 2. 验证兼容性
# 检查 Sparkle CHANGELOG 是否有 breaking changes

# 3. 测试更新
# 构建并测试本地更新流程

# 4. 重新发布
# 创建新版本并验证自动更新仍然工作
```

## 参考资源

- **Sparkle 官方文档**: https://sparkle-project.org/documentation/
- **Sparkle GitHub**: https://github.com/sparkle-project/Sparkle
- **EdDSA 签名**: https://en.wikipedia.org/wiki/EdDSA
- **GitHub Actions 文档**: https://docs.github.com/en/actions

## 附录: 命令速查

```bash
# 查看当前版本
plutil -p MacOSAIDiskCleaner/Info.plist | grep CFBundleShortVersionString

# 查看构建版本
plutil -p MacOSAIDiskCleaner/Info.plist | grep CFBundleVersion

# 生成 EdDSA 密钥
./Sparkle/bin/generate_keys -p

# 签名 DMG
./Sparkle/bin/sign_update app.dmg private_key.pem

# 生成 appcast.xml
./scripts/generate_appcast.sh "0.1.0" "build/app-0.1.0.dmg" "~/.sparkle_keys/key.pem"

# 创建版本标签
git tag -a v0.1.0 -m "Release v0.1.0"
git push origin v0.1.0

# 查看 Release
gh release list
gh release view v0.1.0

# 列出 GitHub Secrets
gh secret list

# 验证 appcast.xml
curl -s https://dissidia-986.github.io/MacOSAIDiskCleaner/appcast.xml | xmllint --format -

# 查看 Sparkle 日志
log stream --predicate 'process == "MacOSAIDiskCleaner"' --level debug | grep -i sparkle
```

---

**需要帮助？**
- GitHub Issues: https://github.com/DISSIDIA-986/MacOSAIDiskCleaner/issues
- Sparkle 讨论组: https://github.com/sparkle-project/Sparkle/discussions
