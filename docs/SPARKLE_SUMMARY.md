# Sparkle 自动更新实现总结

## 实现状态

✅ **已完成** (代码层面):
- UpdateManager 完整实现（SPUUpdaterDelegate + 状态管理）
- Info.plist 配置更新（SUFeedURL + SUPublicEDKey）
- appcast.xml 生成脚本
- GitHub Actions 自动发布工作流
- Logger.appupdates 日志类别
- 完整配置文档

⚠️ **需要手动操作** (用户必须完成):
1. 添加 Sparkle SPM 依赖（Xcode GUI 操作）
2. 生成 EdDSA 密钥对
3. 配置 GitHub Secrets
4. 初始化 GitHub Pages

## 架构概览

```
┌─────────────────────────────────────────────────────────────┐
│                     用户应用                                 │
│  ┌──────────────┐         ┌──────────────────┐             │
│  │ UpdateManager│────────▶│ Sparkle Framework│             │
│  └──────────────┘         └──────────────────┘             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   GitHub Pages                              │
│              (appcast.xml 托管)                             │
│   https://dissidia-986.github.io/MacOSAIDiskCleaner/      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  GitHub Releases                            │
│               (DMG 文件存储)                                │
│   https://github.com/DISSIDIA-986/MacOSAIDiskCleaner/...  │
└─────────────────────────────────────────────────────────────┘
```

## 安全机制

### EdDSA 签名验证流程

```
1. 开发者使用私钥签名 DMG
   ↓
2. 签名信息写入 appcast.xml
   ↓
3. 应用下载 DMG + appcast.xml
   ↓
4. 使用内置公钥验证签名
   ↓
5. 验证通过 → 安装更新
   验证失败 → 拒绝更新
```

### 密钥存储

**私钥** (EdDSA Private Key):
- 存储位置: GitHub Secrets (`SPARKLE_PRIVATE_KEY`)
- 访问权限: GitHub Actions workflow
- 本地备份: `~/.sparkle_keys/MacOSAIDiskCleaner_private_key.pem`
- 文件权限: `600` (仅所有者可读写)

**公钥** (EdDSA Public Key):
- 存储位置: `Info.plist` (`SUPublicEDKey`)
- 访问权限: 应用运行时读取
- 用途: 验证更新包签名

## 核心文件说明

### 1. UpdateManager.swift

**功能**:
- 管理 Sparkle updater 生命周期
- 提供手动更新检查接口
- 实现 SPUUpdaterDelegate 回调
- 发布状态变更 (@Published 属性)

**关键实现**:
```swift
@MainActor
final class UpdateManager: ObservableObject {
    @Published var canCheckForUpdates = false
    @Published var automaticallyChecksForUpdates = false

    func checkForUpdates() { /* 触发更新检查 */ }

    func getCurrentVersion() -> String { /* 获取当前版本 */ }
}

extension UpdateManager: SPUUpdaterDelegate {
    func updater(_:didFindValidUpdate:) { /* 找到更新 */ }
    func updaterDidNotFindUpdate(_:error:) { /* 已是最新 */ }
}
```

**线程安全**:
- 使用 `@MainActor` 确保在主线程执行
- 所有 UI 更新自动线程安全

### 2. Info.plist

**必需配置**:
```xml
<!-- 更新订阅源 URL -->
<key>SUFeedURL</key>
<string>https://dissidia-986.github.io/MacOSAIDiskCleaner/appcast.xml</string>

<!-- EdDSA 公钥 -->
<key>SUPublicEDKey</key>
<string>YOUR_PUBLIC_KEY_HERE</string>

<!-- 自动检查间隔 (24 小时) -->
<key>SUScheduledCheckInterval</key>
<integer>86400</integer>

<!-- 启用自动检查 -->
<key>SUEnableAutomaticChecks</key>
<true/>
```

### 3. generate_appcast.sh

**功能**:
- 使用私钥对 DMG 进行 EdDSA 签名
- 生成符合 Sparkle 2.x 规范的 appcast.xml
- 验证 XML 格式正确性
- 提供详细的日志输出

**使用示例**:
```bash
./scripts/generate_appcast.sh "0.1.0" \
  "build/MacOSAIDiskCleaner-0.1.0.dmg" \
  "~/.sparkle_keys/MacOSAIDiskCleaner_private_key.pem"
```

**输出**:
- appcast.xml (更新订阅源)
- 签名信息 (sparkle:edSignature)
- 文件大小 (length)

### 4. .github/workflows/release.yml

**触发条件**: 推送 `v*.*.*` 格式标签

**工作流步骤**:
```
1. Checkout 代码
2. 提取版本号 (从 Git tag)
3. 更新 Info.plist 版本号
4. 构建 Release 版本
5. 安装 Sparkle 签名工具
6. 创建 DMG (APFS 格式)
7. 生成 appcast.xml (使用私钥签名)
8. 创建 GitHub Release
9. 部署 appcast.xml 到 gh-pages 分支
```

**关键环境变量**:
- `SPARKLE_PRIVATE_KEY`: EdDSA 私钥 (来自 GitHub Secrets)
- `GITHUB_TOKEN`: 自动提供的 GitHub API token

**自动化程度**: 100% (推送标签后自动完成所有步骤)

## 发布流程详解

### 准备阶段

1. **开发完成**:
   - 所有功能已实现并测试
   - 代码已提交到 main 分支
   - 更新 CHANGELOG.md (可选)

2. **版本规划**:
   - 确定版本号 (遵循语义化版本 SemVer)
   - 例如: `v0.1.0` (主版本.次版本.修订版本)

### 执行阶段

1. **创建版本标签**:
   ```bash
   git tag -a v0.1.0 -m "Release v0.1.0: Stable release with Sparkle"
   git push origin v0.1.0
   ```

2. **GitHub Actions 自动执行**:
   - 触发 release workflow
   - 约 5-10 分钟完成全部步骤
   - 可在 Actions 页面查看实时日志

3. **验证输出**:
   - Release 创建成功
   - DMG 文件已上传
   - appcast.xml 已部署

### 验证阶段

1. **下载测试**:
   ```bash
   gh release download v0.1.0 -p "*.dmg"
   hdiutil attach MacOSAIDiskCleaner-0.1.0.dmg
   ```

2. **更新测试**:
   - 安装旧版本应用
   - 点击 "Check for Updates…"
   - 验证发现新版本提示
   - 测试下载和安装流程

3. **appcast.xml 验证**:
   ```bash
   curl -s https://dissidia-986.github.io/MacOSAIDiskCleaner/appcast.xml
   ```

## 更新检查行为

### 用户触发

**触发方式**:
- 应用菜单 → "Check for Updates…"
- 快捷键 (如果配置)

**行为**:
1. 立即请求 appcast.xml
2. 对比版本号
3. 显示更新对话框 (如果有新版本)
4. 下载并安装 (用户确认后)

### 自动检查

**检查间隔**: 24 小时 (可配置)

**检查时机**:
- 应用启动时 (距离上次检查超过间隔)
- 系统唤醒时 (可选)

**行为**:
- 静默检查，不打扰用户
- 发现更新后显示通知
- 支持静默自动安装 (可选)

### 更新下载流程

```
1. 用户点击 "Install Update"
   ↓
2. Sparkle 下载 DMG 到临时目录
   ↓
3. 验证 EdDSA 签名
   ↓
4. 验证通过 → 安装
   验证失败 → 显示错误
   ↓
5. 提示用户重启应用
   ↓
6. 替换旧版本
   ↓
7. 启动新版本
```

## 配置灵活性

### 可配置参数

**Info.plist 选项**:
```xml
<!-- 检查间隔 (秒) -->
<key>SUScheduledCheckInterval</key>
<integer>86400</integer>  <!-- 24 小时 -->

<!-- 自动下载更新 (下载后提示安装) -->
<key>SUAutomaticallyUpdate</key>
<true/>

<!-- 仅在系统空闲时检查 -->
<key>SUAllowsAutomaticUpdates</key>
<true/>

<!-- 发送匿名系统信息 (可选) -->
<key>SUSendProfileInfo</key>
<false/>
```

### UpdateManager 扩展点

**可添加功能**:
- 自定义更新 UI
- 更新前后回调
- 版本回滚机制
- 测试环境切换

**实现方式**:
```swift
extension UpdateManager: SPUUpdaterDelegate {
    // 自定义行为
    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        // 安装前的自定义逻辑
    }
}
```

## 监控和日志

### 日志查看

**Console.app 过滤**:
```
process == "MacOSAIDiskCleaner"
category == "appupdates"
```

**命令行查看**:
```bash
log stream --predicate 'process == "MacOSAIDiskCleaner"' --level debug
```

### 关键日志事件

- **检查更新**: `[Sparkle] Checking for updates...`
- **找到更新**: `[Sparkle] Found update: {version}`
- **下载进度**: `[Sparkle] Downloading update... {progress}%`
- **安装成功**: `[Sparkle] Update successful: {version}`
- **安装失败**: `[Sparkle] Update failed: {error}`

### 发布监控

**GitHub Actions 状态**:
- 查看最近的 release workflow 运行
- 检查是否有失败步骤
- 查看详细的构建日志

**GitHub Release 统计**:
- DMG 下载次数
- Release 访问量

## 故障排查速查表

| 问题 | 可能原因 | 快速检查 |
|------|---------|---------|
| Sparkle 未集成 | SPM 依赖未添加 | `grep sparkle project.pbxproj` |
| 更新检查失败 | appcast.xml 无法访问 | `curl -I appcast.xml URL` |
| 签名验证失败 | 公私钥不匹配 | 重新生成密钥对 |
| Actions 失败 | Secrets 未配置 | `gh secret list` |
| DMG 无法安装 | 签名问题 | `codesign -dvvv app.dmg` |

详细故障排查: `docs/SPARKLE_SETUP.md`

## 安全最佳实践

### 密钥轮换

**建议频率**: 每年或怀疑泄露时

**步骤**:
```bash
# 1. 生成新密钥对
./Sparkle/bin/generate_keys -p

# 2. 更新 Info.plist (公钥)

# 3. 更新 GitHub Secrets (私钥)

# 4. 重新发布应用 (包含新公钥)

# 5. 测试更新流程
```

### Secrets 管理

**原则**:
- 最小权限 (仅 workflow 可访问)
- 审计日志 (记录访问历史)
- 定期轮换 (增强安全性)

**验证**:
```bash
# 列出所有 secrets
gh secret list

# 检查过期时间 (GitHub UI)
```

### HTTPS 强制

**appcast.xml 必须使用 HTTPS**:
- Sparkle 拒绝 HTTP 订阅源
- GitHub Pages 自动提供 HTTPS
- 验证: `https://` 而非 `http://`

## 未来增强方向

### 可选功能

1. **渐进式发布**:
   - 先发布到测试用户
   - 收集反馈后全面推广

2. **回滚机制**:
   - 保留旧版本下载链接
   - 支持用户降级

3. **自定义 UI**:
   - 自定义更新对话框样式
   - 添加发布说明预览

4. **测试环境**:
   - 使用不同的 appcast URL
   - 开发/生产环境分离

### 集成增强

1. **Analytics 集成**:
   - 追踪更新转化率
   - 监控更新失败原因

2. **A/B 测试**:
   - 测试不同更新提示文案
   - 优化用户更新体验

3. **灰度发布**:
   - 按百分比推送更新
   - 监控崩溃率和反馈

## 相关文档

- [完整配置指南](SPARKLE_SETUP.md)
- [快速开始](SPARKLE_QUICKSTART.md)
- [Sparkle 官方文档](https://sparkle-project.org/documentation/)

## 技术支持

**问题报告**: https://github.com/DISSIDIA-986/MacOSAIDiskCleaner/issues

**Sparkle 支持**: https://github.com/sparkle-project/Sparkle/discussions

---

**实现日期**: 2025-01-23
**Sparkle 版本**: 2.x
**最低系统要求**: macOS 12.0+
**开发工具**: Xcode 14+
