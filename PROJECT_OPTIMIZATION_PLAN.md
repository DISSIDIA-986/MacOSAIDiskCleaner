# MacOSAIDiskCleaner - 项目结构优化计划

**日期**: 2026-02-05
**目标**: 优化代码组织、提升可维护性、遵循 Swift/macOS 最佳实践

---

## 一、当前项目结构分析

### 现有目录结构
```
MacOSAIDiskCleaner/
├── Core/                    # 核心基础设施
│   ├── Errors/             # 错误定义
│   ├── Logging/            # 日志系统
│   └── Permissions/        # 权限管理
├── Features/               # 功能模块
│   ├── AI/                 # AI 分析
│   ├── Categories/         # 分类管理
│   ├── Rules/              # 规则匹配
│   ├── Scanner/            # 文件扫描
│   ├── Statistics/         # 统计数据
│   ├── Trash/              # 垃圾桶操作
│   └── Updates/            # 更新管理
├── Models/                 # 数据模型
├── ViewModels/             # 视图模型
├── Views/                  # SwiftUI 视图
└── Utils/                  # 工具类
```

### 架构模式
- **MVVM**: SwiftUI + ViewModels
- **Actor-based concurrency**: 使用 Actor 确保线程安全
- **Feature-based structure**: 按功能模块组织

---

## 二、参考的最佳实践和技能

### 1. Swift Concurrency 最佳实践
参考：Apple 官方文档和 Swift Evolution

**当前状态**:
- ✅ 使用 Actor 并发安全
- ✅ async/await 异步操作
- ✅ Sendable 协议

**可优化点**:
- 检查所有 Actor 隔离是否正确
- 确保 @MainActor 使用恰当
- 避免数据竞争

### 2. SwiftUI 性能优化
参考：Apple WWDC sessions on SwiftUI Performance

**当前状态**:
- ✅ 使用 @Published 响应式更新
- ✅ BatchUpdater 批量更新
- ✅ 后台任务分离

**可优化点**:
- 视图懒加载
- 减少重绘次数
- 优化大列表渲染

### 3. macOS 权限和安全
参考：Apple Security Guidelines

**当前状态**:
- ✅ Full Disk Access 检查
- ✅ Keychain 安全存储
- ✅ Path Traversal 防护

**可优化点**:
- 代码签名和公证
- 沙盒配置
- 最小权限原则

### 4. 错误处理和日志
参考：Swift Error Handling Best Practices

**当前状态**:
- ✅ 自定义错误类型
- ✅ os.log 统一日志
- ✅ 分级日志

**可优化点**:
- 错误恢复策略
- 用户友好的错误提示
- 崩溃报告集成

---

## 三、项目结构优化方案

### 3.1 创建 Supporting Files 目录

将辅助文件统一管理：

```
MacOSAIDiskCleaner/
├── Supporting Files/
│   ├── Info.plist
│   ├── Entitlements.plist
│   ├── AppDelegate.swift
│   └── SceneDelegate.swift
```

### 3.2 扩展管理（Extensions）

创建专门的扩展目录：

```
MacOSAIDiskCleaner/
├── Extensions/
│   ├── Foundation/        # Foundation 扩展
│   ├── SwiftUI/          # SwiftUI 扩展
│   └── App/              # 应用特定扩展
```

**示例**：
```swift
// Extensions/Foundation/URLExtensions.swift
extension URL {
    var canonicalPath: String {
        (try? resourceValues(forKeys: [.canonicalPathKey]))?.canonicalPath
        ?? path
    }
}

// Extensions/SwiftUI/ViewExtensions.swift
extension View {
    @ViewBuilder
    func ifCondition<Content: View>(
        _ condition: Bool,
        transform: (Self) -> Content
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
```

### 3.3 资源管理（Resources）

分离资源文件：

```
MacOSAIDiskCleaner/
├── Resources/
│   ├── Assets.xcassets   # 图片资源
│   ├── Color.xcassets    # 颜色资源
│   └── Localizable.strings # 本地化
```

### 3.4 测试结构优化

```
MacOSAIDiskCleanerTests/
├── Core/
│   ├── ErrorTests.swift
│   ├── LoggingTests.swift
│   └── PermissionTests.swift
├── Features/
│   ├── AI/
│   ├── Scanner/
│   └── Trash/
└── Mocks/
    ├── MockFileManager.swift
    └── MockKeychain.swift
```

### 3.5 配置和常量

创建配置目录：

```
MacOSAIDiskCleaner/
├── Configuration/
│   ├── AppConfig.swift      # 应用配置
│   ├── Constants.swift      # 常量定义
│   └── FeatureFlags.swift   # 功能开关
```

**示例**：
```swift
// Configuration/AppConfig.swift
enum AppConfig {
    static let bundleIdentifier = "com.niuyp.MacOSAIDiskCleaner"
    static let appName = "MacOSAIDiskCleaner"
    static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
}

// Configuration/FeatureFlags.swift
enum FeatureFlags {
    static let enableAIAnalysis = true
    static let enableStatistics = true
    static let maxCacheSize = 1000
}
```

---

## 四、代码质量改进

### 4.1 文档注释规范

为所有公共 API 添加文档注释：

```swift
/// 分析文件并返回清理建议
///
/// 此方法使用 AI 模型分析文件内容，基于文件路径、大小和上下文
/// 决定是否建议清理。
///
/// - Parameters:
///   - context: 分析上下文，包含文件路径、大小等信息
///   - config: AI 配置，包括 API 端点和模型
///   - category: 扫描分类，用于选择合适的提示模板
///   - developerProfile: 开发者配置，影响分析策略
///
/// - Returns: AI 分析结果，包含建议操作和风险等级
///
/// - Throws:
///   - `DiskCleanerError.permissionDenied` 如果 API Key 未设置
///   - `DiskCleanerError.aiRequestFailed` 如果 AI 请求失败
///
/// - Important: 此方法会调用外部 AI API，可能产生费用
///
/// - Version: 1.0
///
/// # Example
/// ```swift
/// let analysis = try await analyzer.analyze(
///     context: context,
///     config: config,
///     category: .caches
/// )
/// ```
func analyze(
    context: AnalysisContext,
    config: AIConfiguration,
    category: ScanCategory? = nil,
    developerProfile: DeveloperProfile? = nil
) async throws -> AIAnalysis
```

### 4.2 MARK 注释规范

统一使用 MARK 分组代码：

```swift
// MARK: - Public API

// MARK: - Private Helpers

// MARK: - Constants

// MARK: - Nested Types

// MARK: - Initialization
```

### 4.3 命名规范

遵循 Swift API 设计准则：

```swift
// ✅ Good
func scanTopLevelAggregates(
    root: URL,
    options: ScanOptions = .init(),
    onProgress: @Sendable (ScanProgress) -> Void,
    onUpdate: @Sendable (ScannedItem) -> Void
) throws

// ❌ Bad
func scan(
    r: URL,
    o: ScanOptions = .init(),
    p: @Sendable (ScanProgress) -> Void,
    u: @Sendable (ScannedItem) -> Void
) throws
```

### 4.4 错误处理改进

```swift
// 创建专门的错误类型
enum DiskCleanerError: LocalizedError {
    case permissionDenied(String)
    case scanCancelled
    case aiRequestFailed(Error)
    case fileSystemError(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied(let message):
            return "Permission denied: \(message)"
        case .scanCancelled:
            return "Scan was cancelled"
        case .aiRequestFailed(let error):
            return "AI request failed: \(error.localizedDescription)"
        case .fileSystemError(let message):
            return "File system error: \(message)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Please grant Full Disk Access in System Settings"
        case .aiRequestFailed:
            return "Check your API key and network connection"
        default:
            return nil
        }
    }
}
```

---

## 五、性能优化建议

### 5.1 内存管理

```swift
// 使用弱引用避免循环引用
class DiskCleanerViewModel: ObservableObject {
    private weak var scanner: FileScanner?
    private [weak self] in
}

// 及时释放大对象
func processLargeData() {
    let data = loadLargeData()
    defer {
        // 确保数据被释放
        largeDataBuffer = nil
    }
    // 处理数据
}
```

### 5.2 并发优化

```swift
// 使用 TaskGroup 并行处理
await withTaskGroup(of: Result<AIAnalysis, Error>.self) { group in
    for item in items {
        group.addTask {
            try await self.analyzer.analyze(item: item)
        }
    }

    for await result in group {
        // 处理结果
    }
}
```

### 5.3 缓存策略

```swift
// 使用 NSCache 自动管理内存
actor AnalysisCache {
    private let cache = NSCache<NSString, CachedAnalysis>()

    func get(key: String) -> CachedAnalysis? {
        cache.object(forKey: key as NSString)
    }

    func set(key: String, value: CachedAnalysis) {
        cache.setObject(value, forKey: key as NSString)
    }
}
```

---

## 六、测试策略

### 6.1 单元测试

```swift
import XCTest
@testable import MacOSAIDiskCleaner

class FileScannerTests: XCTestCase {
    var scanner: FileScanner!

    override func setUp() {
        super.setUp()
        scanner = FileScanner()
    }

    func testProtectedPathDetection() {
        XCTAssertTrue(FileScanner.isProtectedSystemPath("/System"))
        XCTAssertTrue(FileScanner.isProtectedSystemPath("/usr/bin"))
        XCTAssertFalse(FileScanner.isProtectedSystemPath("/Users/test"))
    }

    func testSymlinkProtection() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let evilLink = tempDir.appendingPathComponent("evil")
        try FileManager.default.createSymbolicLink(
            at: evilLink,
            withDestinationURL: URL(fileURLWithPath: "/System")
        )

        // 应该被识别为系统路径
        let canonicalPath = (try? evilLink.resourceValues(forKeys: [.canonicalPathKey]))?.canonicalPath
        XCTAssertEqual(canonicalPath, "/System")
    }
}
```

### 6.2 集成测试

```swift
class IntegrationTests: XCTestCase {
    func testFullScanWorkflow() async throws {
        let viewModel = DiskCleanerViewModel()
        viewModel.startScan()

        // 等待扫描完成
        try await Task.sleep(nanoseconds: 5_000_000_000)

        XCTAssertEqual(viewModel.scanState, .finished)
        XCTAssertFalse(viewModel.items.isEmpty)
    }
}
```

### 6.3 性能测试

```swift
class PerformanceTests: XCTestCase {
    func testLargeDirectoryScan() {
        let scanner = FileScanner()
        let root = URL(fileURLWithPath: "/Users/test/LargeFolder")

        measure {
            // 测量扫描时间
            try? scanner.scanTopLevelAggregates(
                root: root,
                onProgress: { _ in },
                onUpdate: { _ in }
            )
        }
    }
}
```

---

## 七、持续集成优化

### 7.1 GitHub Actions 工作流

```yaml
# .github/workflows/ci.yml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest

    steps:
      - uses: actions/checkout@v3

      - name: Build
        run: xcodebuild build -scheme MacOSAIDiskCleaner

      - name: Test
        run: xcodebuild test -scheme MacOSAIDiskCleaner

      - name: Lint
        run: swiftlint lint --strict

      - name: Security Scan
        run: |
          # 检查硬编码的密钥
          git grep -i "api_key\|secret\|password" && exit 1 || true
```

### 7.2 代码质量工具

```bash
# 安装 SwiftLint
brew install swiftlint

# 配置 .swiftlint.yml
disabled_rules:
  - trailing_whitespace

opt_in_rules:
  - explicit_init
  - explicit_type_interface
  - fatal_error_message

included:
  - MacOSAIDiskCleaner

excluded:
  - MacOSAIDiskCleanerTests
```

---

## 八、文档改进

### 8.1 README 结构

```markdown
# MacOSAIDiskCleaner

## 功能特性
- AI 智能分析
- 多种扫描分类
- 统计仪表板
- 安全清理

## 系统要求
- macOS 12.0+
- Full Disk Access 权限

## 安装
1. 下载 .dmg 文件
2. 拖拽到 Applications
3. 授予 Full Disk Access

## 使用指南
...

## 开发者文档
[链接到 DEVELOPER.md]

## 贡献指南
[链接到 CONTRIBUTING.md]
```

### 8.2 开发者文档

创建 `DEVELOPER.md`：

```markdown
# 开发者指南

## 环境设置
- Xcode 14.3+
- Swift 5.9+

## 架构概览
...

## 添加新功能
...

## 测试
...

## 发布流程
...
```

---

## 九、实施优先级

### P0 - 立即执行
1. ✅ 修复所有 P0 安全漏洞
2. ✅ 编译通过
3. 🔄 创建扩展目录
4. 🔄 添加基础文档注释

### P1 - 本周完成
1. 📋 统一 MARK 注释
2. 📋 改进错误处理
3. 📋 添加单元测试
4. 📋 配置 SwiftLint

### P2 - 下周完成
1. 📋 性能优化
2. 📋 集成测试
3. 📋 CI/CD 改进
4. 📋 文档完善

---

## 十、可参考的 Agent 技能

基于 OpenClaw 技能生态，以下技能可用于提升开发效率：

### 1. coding-agent
- **用途**: 自动化代码重构、测试生成
- **应用场景**:
  - 批量添加文档注释
  - 自动生成单元测试
  - 代码风格统一

### 2. github
- **用途**: PR 管理、CI 监控
- **应用场景**:
  - 自动检查 CI 状态
  - 批量 PR 审查
  - Issue 跟踪

### 3. skill-creator
- **用途**: 创建项目特定技能
- **应用场景**:
  - 封装项目常用命令
  - 自动化重复任务

### 4. tmux
- **用途**: 多任务并行开发
- **应用场景**:
  - 同时运行测试和构建
  - 监控多个日志流

---

## 十一、下一步行动

### 立即开始
1. **创建扩展目录结构**
2. **添加 SwiftLint 配置**
3. **编写开发者文档**

### 本周目标
1. 完成所有公共 API 的文档注释
2. 添加核心功能的单元测试
3. 配置 CI/CD 流程

### 持续改进
1. 定期代码审查
2. 性能监控
3. 用户反馈整合

---

## 总结

通过遵循 Swift/macOS 最佳实践和 OpenClaw 技能生态，我们可以：

✅ **提升代码质量**: 文档完善、测试覆盖
✅ **提高开发效率**: 自动化工具、代码生成
✅ **增强可维护性**: 清晰结构、统一规范
✅ **保障安全性**: 权限管理、错误处理

项目已经完成了所有 P0 安全修复，现在可以专注于结构优化和长期维护。
