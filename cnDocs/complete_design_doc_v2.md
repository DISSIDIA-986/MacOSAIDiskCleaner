# macOS AI-Powered Disk Cleaner - 完整设计文档 v2.0

## 项目概述

**项目名称**：macOS AI Disk Cleaner（智能磁盘清理工具）

**核心价值**：为 macOS 开发者提供智能化的磁盘清理方案，结合成熟的规则引擎（80%）和高质量 AI 决策（20%）。

**目标用户**：macOS 开发者（Swift、Python、Node.js、Ruby 等多栈开发者）

**核心创新**：
- 规则引擎处理常见场景（Xcode、node_modules、venv 等）
- AI 驱动处理复杂边界情况（需要推理判断的文件）
- **高质量 Prompt 系统** - 针对不同场景动态生成最优提示词

---

## 一、架构设计

### 1.1 整体架构

```
┌───────────────────────────────────────────────────────────┐
│                  macOS SwiftUI 应用                       │
├───────────────────────────────────────────────────────────┤
│                                                            │
│  ┌─────────────────────────────────────────────────────┐ │
│  │         主界面 (UI Layer - Clean-Me)               │ │
│  │  ├─ 磁盘扫描进度                                   │ │
│  │  ├─ 清理建议列表                                   │ │
│  │  ├─ 文件预览 & 详情                                │ │
│  │  └─ 执行控制（预览/删除/撤销）                    │ │
│  └─────────────────────────────────────────────────────┘ │
│                      ↓                                     │
│  ┌─────────────────────────────────────────────────────┐ │
│  │      分析引擎 (Analysis Engine)                     │ │
│  │  ├─ 规则引擎 (Rule Engine)                         │ │
│  │  │  ├─ Mole 规则库（25+ 规则）                    │ │
│  │  │  └─ 本地判断（低风险、高可信度）                │ │
│  │  │                                                   │ │
│  │  └─ AI 决策层 (AI Analysis Layer)                  │ │
│  │     ├─ Prompt 管理系统（关键！）                   │ │
│  │     ├─ 场景识别（文件类型、目录、大小等）          │ │
│  │     ├─ 动态 Prompt 生成                            │ │
│  │     └─ LLM API 调用（边界情况）                    │ │
│  └─────────────────────────────────────────────────────┘ │
│                      ↓                                     │
  │  ┌─────────────────────────────────────────────────────┐ │
│  │      本地配置 (Local Configuration)                │ │
│  │  ├─ Keychain 安全存储 (API Keys)                  │ │
│  │  ├─ 应用偏好设置                                   │ │
│  │  ├─ 用户上下文 (Developer Stack Profile)         │ │
│  │  ├─ 执行历史 & 审计日志                            │ │
│  │  └─ Sparkle 自动更新模块 (App Updates)            │ │
│  └─────────────────────────────────────────────────────┘ ││                      ↓                                     │
│  ┌─────────────────────────────────────────────────────┐ │
│  │      文件操作层 (File Operations)                   │ │
│  │  ├─ Dry Run 模式（预览）                           │ │
│  │  ├─ 软删除（移至废纸篓）                            │ │
│  │  ├─ 压缩操作                                        │ │
│  │  └─ 恢复功能                                        │ │
│  └─────────────────────────────────────────────────────┘ │
│                      ↓                                     │
│           外部 LLM API（用户配置的密钥）                  │
│  ┌─────────────┬─────────────┬─────────────┐            │
│  │ 阿里通义千问  │    GROK      │  ChatGPT    │            │
│  │ (优先)      │  (备选快速)  │  (备选通用) │            │
│  └─────────────┴─────────────┴─────────────┘            │
│                                                            │
└───────────────────────────────────────────────────────────┘
```

### 1.2 关键决策

**为什么不要后端代理？**
- ✅ 用户数据完全本地化
- ✅ 零服务器成本
- ✅ 成本模型透明（用户直接付费）
- ✅ 隐私最大化

**发布策略与权限（关键修正）**
- **发布渠道**：独立分发（非 App Store），通过 Notarization 公证。
- **权限要求**：必须请求 **Full Disk Access (完全磁盘访问权限)**。
  - *原因*：App Store 的沙盒机制（Sandbox）会阻止应用访问 `~/Library`、`node_modules` 等关键清理目标。作为清理工具，必须拥有系统级的文件访问权限才能正常工作。

**纯客户端架构**：所有逻辑在本地执行，仅需要 LLM API 调用

---

## 二、核心模块详设

### 2.1 规则引擎 (Rule Engine)

**来源**：Mole 项目的成熟规则库

```swift
struct CleanupRule {
    let id: String
    let name: String
    let category: Category  // Xcode, NodeJS, Python, System, App
    let patterns: [String]  // 路径模式
    let description: String
    let riskLevel: RiskLevel  // low, medium, high
    let estimatedSpace: Int64
    let recoverability: Recoverability  // canRecover, permanent
    let action: CleanupAction  // delete, compress, archive
    let conditions: [String]  // 执行条件
}

enum Category: String {
    case xcode = "Xcode"
    case nodejs = "Node.js"
    case python = "Python"
    case ruby = "Ruby"
    case homebrew = "Homebrew"
    case browser = "Browser Cache"
    case system = "System"
    case appSupport = "App Support Files"
    case other = "Other"
}

enum RiskLevel: String {
    case low = "low"      // 100% 安全删除
    case medium = "medium"  // 95%+ 安全
    case high = "high"    // 需要用户确认或 AI 验证
}

enum Recoverability: String {
    case canRecover = "可恢复"   // 删除后可重建
    case permanent = "永久"      // 无法恢复
}

// 预定义规则库（核心资产）
let coreRules: [CleanupRule] = [
    // Xcode
    CleanupRule(
        id: "xcode_derived_data",
        name: "Xcode Derived Data",
        category: .xcode,
        patterns: ["~/Library/Developer/Xcode/DerivedData/*"],
        description: "Xcode 编译缓存，重新编译时会自动重建",
        riskLevel: .low,
        estimatedSpace: 50_000_000_000,
        recoverability: .canRecover,
        action: .delete,
        conditions: ["iOS 项目存在"]
    ),
    
    // Node.js
    CleanupRule(
        id: "node_modules",
        name: "node_modules 依赖",
        category: .nodejs,
        patterns: ["**/node_modules"],
        description: "NPM 依赖，可通过 npm install 恢复",
        riskLevel: .low,
        estimatedSpace: 50_000_000_000,
        recoverability: .canRecover,
        action: .delete,
        conditions: ["package.json 存在"]
    ),
    
    // Python
    CleanupRule(
        id: "python_venv",
        name: "Python Virtual Environments",
        category: .python,
        patterns: ["**/.venv", "**/venv", "**/__pycache__"],
        description: "Python 虚拟环境，可重新创建",
        riskLevel: .low,
        estimatedSpace: 5_000_000_000,
        recoverability: .canRecover,
        action: .delete,
        conditions: ["requirements.txt 或 pyproject.toml 存在"]
    ),
    
    // 更多规则...
]
```

**执行流程**：
```
1. 扫描磁盘 (FileManager async)
2. 匹配规则
3. 分类为：确定可删 / 可能可删 / 需要确认
4. 高风险项目转给 AI 分析
```

#### 2.1.1 安全边界 (Safety Guardrails - Critical)

为防止误删和系统异常，必须在文件操作层实施以下强制检查：

1.  **符号链接 (Symlink) 防御**：
    -   **规则**：扫描和删除时**严禁追随 (Follow)** 符号链接。
    -   **处理**：对于 `node_modules` 等目录，若遇到符号链接（如 `pnpm` 结构），仅判断链接本身，绝不递归进入链接指向的源目录。
    -   **目的**：防止误删共享依赖或陷入死循环。

2.  **云存储保护 (iCloud/OneDrive)**：
    -   **规则**：检测文件属性 `URLResourceKey.isUbiquitousItemKey`。
    -   **处理**：若文件状态为“未下载 (Dataless/Placeholder)”，**直接跳过**扫描和清理。
    -   **目的**：防止触发后台大量下载，消耗用户流量。

3.  **系统完整性保护 (SIP)**：
    -   **规则**：内置白名单，禁止操作 `/System`, `/usr` (local除外), `/bin` 等受保护目录。

---

### 2.2 Prompt 管理系统（核心创新）

这是**最关键**的部分，直接影响 AI 决策质量。

#### 2.2.1 Prompt 模板系统

```swift
protocol PromptTemplate {
    var id: String { get }
    var name: String { get }
    var version: String { get }
    var scenarios: [String] { get }  // 适用场景
    func build(context: AnalysisContext) -> String
}

// 场景 1：不确定的大型目录
struct LargeDirectoryPromptTemplate: PromptTemplate {
    let id = "large_dir_analysis"
    let name = "大型目录分析"
    let version = "1.0"
    let scenarios = ["目录大小>500MB", "文件数>1000"]
    
    func build(context: AnalysisContext) -> String {
        let dirInfo = context.targetDirectory
        let userProfile = context.userProfile
        
        return """
你是一个专业的 macOS 磁盘清理顾问，拥有 10 年的系统优化经验。

【分析目标】
路径: \(dirInfo.path)
大小: \(formatBytes(dirInfo.sizeBytes))
文件数: \(dirInfo.fileCount)
修改时间: \(formatDate(dirInfo.lastModified))

【用户背景】
开发栈: \(userProfile.devStack)
OS 版本: \(userProfile.macOSVersion)
磁盘使用: \(userProfile.diskUsagePercent)%
项目活跃度: \(userProfile.isActivelyDeveloping ? "是" : "否")

【决策标准】
你需要判断这个目录是否可以安全删除。请考虑：
1. 它是否是临时文件或缓存（可以删除）
2. 它是否包含有价值的代码或数据（不能删除）
3. 删除后是否能自动恢复（如 node_modules）
4. 是否在最近 30 天内被使用过

【输出格式】
必须返回以下 JSON（无其他文本）：
{
  "can_delete": true|false,
  "confidence": 0.0-1.0,
  "reason": "简洁的中文解释，最多 30 字",
  "risk_level": "low|medium|high",
  "recovery_method": "如何恢复（如果删除的话）"
}
"""
    }
}

// 场景 2：应用支持文件
struct AppSupportFilesPromptTemplate: PromptTemplate {
    let id = "app_support_analysis"
    let name = "应用支持文件分析"
    let version = "1.0"
    let scenarios = ["~/Library/Application Support/*"]
    
    func build(context: AnalysisContext) -> String {
        let appName = context.targetDirectory.name
        let size = context.targetDirectory.sizeBytes
        
        return """
【分析应用支持文件】
应用: \(appName)
大小: \(formatBytes(size))

这个应用现在安装吗？
如果已卸载，这些文件可以删除。
如果安装了，需要确保不会破坏应用功能。

请判断并返回 JSON：
{
  "can_delete": true|false,
  "confidence": 0.0-1.0,
  "reason": "原因",
  "risk_level": "low|medium|high"
}
"""
    }
}

// 场景 3：缓存文件
struct CacheFilesPromptTemplate: PromptTemplate {
    let id = "cache_analysis"
    let name = "缓存文件分析"
    let version = "1.0"
    let scenarios = ["Cache", "~/.cache", "临时文件"]
    
    func build(context: AnalysisContext) -> String {
        return """
【分析缓存】
类型: \(context.targetDirectory.name)
大小: \(formatBytes(context.targetDirectory.sizeBytes))
年龄: \(calculateAge(context.targetDirectory.lastModified))

缓存文件通常可以安全删除，应用会重新生成。
但某些缓存（如浏览器 cookies）可能包含用户数据。

请判断：
{
  "can_delete": true|false,
  "confidence": 0.95,
  "reason": "缓存文件可以安全删除"
}
"""
    }
}
```

#### 2.2.2 Prompt 管理器

```swift
class PromptManager {
    private let templates: [PromptTemplate] = [
        LargeDirectoryPromptTemplate(),
        AppSupportFilesPromptTemplate(),
        CacheFilesPromptTemplate(),
        // 更多模板...
    ]
    
    // 核心函数：根据上下文选择最优 Prompt
    func buildOptimalPrompt(for context: AnalysisContext) -> String {
        let matchedTemplates = templates.filter { template in
            template.scenarios.contains { scenario in
                matchesScenario(context: context, scenario: scenario)
            }
        }
        
        // 选择最相关的模板
        guard let bestTemplate = matchedTemplates.first else {
            return buildDefaultPrompt(context: context)
        }
        
        return bestTemplate.build(context: context)
    }
    
    private func matchesScenario(context: AnalysisContext, scenario: String) -> Bool {
        let path = context.targetDirectory.path.lowercased()
        let size = context.targetDirectory.sizeBytes
        
        switch scenario {
        case let s where s.contains("目录大小>500MB"):
            return size > 500_000_000
        case let s where s.contains("Cache"):
            return path.contains("cache") || path.contains("caches")
        case let s where s.contains("node_modules"):
            return path.contains("node_modules")
        case let s where s.contains("~/.cache"):
            return path.contains("/.cache")
        // ... 更多匹配规则
        default:
            return false
        }
    }
    
    private func buildDefaultPrompt(context: AnalysisContext) -> String {
        return """
请分析这个文件/目录是否可以安全删除：
路径: \(context.targetDirectory.path)
大小: \(formatBytes(context.targetDirectory.sizeBytes))
修改时间: \(formatDate(context.targetDirectory.lastModified))

用户背景: \(context.userProfile.devStack)

返回 JSON:
{
  "can_delete": true|false,
  "confidence": 0.0-1.0,
  "reason": "原因"
}
"""
    }
}

// 分析上下文（Prompt 输入）
struct AnalysisContext {
    let targetDirectory: FileMetadata
    let userProfile: UserProfile
    let systemInfo: SystemInfo
    let recentActivity: RecentActivity
}

struct UserProfile {
    let devStack: [String]  // ["Swift", "Python", "Node.js"]
    let activeProjects: Int
    let diskUsagePercent: Double
    let isActivelyDeveloping: Bool
    let macOSVersion: String
}

struct SystemInfo {
    let totalDiskSpace: Int64
    let availableDiskSpace: Int64
    let usedDiskSpace: Int64
}

struct RecentActivity {
    let lastAccessDate: Date?
    let lastModifiedDate: Date
    let accessCount: Int
}
```

---

### 2.3 AI 决策层 (AI Analysis Layer)

#### 2.3.1 LLM 提供商配置（用户优先级）

你的建议：**阿里通义千问 > GROK > ChatGPT**

```swift
enum LLMProvider: String, CaseIterable {
    case qianwen = "qianwen"
    case grok = "grok"
    case chatgpt = "chatgpt"
    
    var displayName: String {
        switch self {
        case .qianwen: return "通义千问 (Aliyun)"
        case .grok: return "GROK (xAI)"
        case .chatgpt: return "ChatGPT (OpenAI)"
        }
    }
    
    var website: String {
        switch self {
        case .qianwen: return "https://dashscope.aliyun.com"
        case .grok: return "https://console.groq.com"
        case .chatgpt: return "https://platform.openai.com"
        }
    }
    
    var documentation: String {
        switch self {
        case .qianwen: return "https://help.aliyun.com/zh/dashscope"
        case .grok: return "https://console.groq.com/docs"
        case .chatgpt: return "https://platform.openai.com/docs"
        }
    }
    
    // 价格参考（每 1K tokens）
    var estimatedCostPer1KTokens: Double {
        switch self {
        case .qianwen: return 0.0008  // 最便宜
        case .grok: return 0.0005     // 更便宜
        case .chatgpt: return 0.003   // 相对贵
        }
    }
    
    // 推理能力评分
    var reasoningCapability: Double {
        switch self {
        case .qianwen: return 0.85
        case .grok: return 0.8
        case .chatgpt: return 0.9
        }
    }
}

#### 2.3.4 并发控制 (Rate Limiting)

为避免触发 LLM API 的 `429 Too Many Requests` 错误，需实现令牌桶机制：

```swift
actor AIRequestQueue {
    private var activeRequests = 0
    private let maxConcurrent = 3  // 限制最大并发数
    
    func enqueue<T>(operation: () async throws -> T) async throws -> T {
        while activeRequests >= maxConcurrent {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 等待 1s
        }
        
        activeRequests += 1
        defer { activeRequests -= 1 }
        
        return try await operation()
    }
}
```

// 推荐优先级：
// 1. GROK - 最便宜 + 足够聪明（0.0005/1K tokens）
// 2. 通义千问 - 中文最强 + 很便宜（0.0008/1K tokens）
// 3. ChatGPT - 备选（相对较贵）

#### 2.3.3 隐私安全策略 (Data Privacy)

在调用 LLM API 之前，必须对数据进行脱敏处理：

1.  **路径匿名化**：将用户主目录替换为 `~`，隐藏具体用户名。
    -   原文：`/Users/steve/Projects/SecretApp/node_modules`
    -   发送：`~/Projects/SecretApp/node_modules`
2.  **敏感词过滤**：允许用户设置"敏感项目关键词"，匹配路径时不发送给 AI，直接采用本地规则或跳过。
3.  **最小化上下文**：仅发送元数据（大小、类型、时间），避免发送文件内容。
```

#### 2.3.2 LLM 分析器实现

```swift
protocol LLMAnalyzer {
    func analyze(
        context: AnalysisContext,
        prompt: String
    ) async throws -> AnalysisResult
}

// GROK 实现（最优先）
class GrokAnalyzer: LLMAnalyzer {
    let apiKey: String
    let endpoint = "https://api.groq.com/openai/v1/chat/completions"
    let model = "mixtral-8x7b-32768"  // Groq 的快速模型
    
    func analyze(
        context: AnalysisContext,
        prompt: String
    ) async throws -> AnalysisResult {
        let request = OpenAICompatibleRequest(
            model: model,
            messages: [
                Message(role: "system", content: "你是磁盘清理专家"),
                Message(role: "user", content: prompt)
            ],
            temperature: 0.3,
            max_tokens: 300
        )
        
        var urlRequest = URLRequest(url: URL(string: endpoint)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw LLMError.apiError("Groq API returned error")
        }
        
        let groqResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        return parseAnalysisResult(from: groqResponse)
    }
}

// 通义千问实现
class QianwenAnalyzer: LLMAnalyzer {
    let apiKey: String
    let endpoint = "https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation"
    
    func analyze(
        context: AnalysisContext,
        prompt: String
    ) async throws -> AnalysisResult {
        let request = QianwenRequest(
            model: "qwen-max",  // 最强模型
            messages: [
                Message(role: "system", content: "你是磁盘清理专家"),
                Message(role: "user", content: prompt)
            ],
            temperature: 0.3,
            top_p: 0.9
        )
        
        var urlRequest = URLRequest(url: URL(string: endpoint)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw LLMError.apiError("Qianwen API returned error")
        }
        
        let qianwenResponse = try JSONDecoder().decode(QianwenResponse.self, from: data)
        return parseAnalysisResult(from: qianwenResponse)
    }
}

// ChatGPT 实现（备选）
class ChatGPTAnalyzer: LLMAnalyzer {
    let apiKey: String
    let endpoint = "https://api.openai.com/v1/chat/completions"
    
    func analyze(
        context: AnalysisContext,
        prompt: String
    ) async throws -> AnalysisResult {
        let request = OpenAICompatibleRequest(
            model: "gpt-4o-mini",
            messages: [
                Message(role: "system", content: "你是磁盘清理专家"),
                Message(role: "user", content: prompt)
            ],
            temperature: 0.3
        )
        
        var urlRequest = URLRequest(url: URL(string: endpoint)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw LLMError.apiError("OpenAI API returned error")
        }
        
        let openaiResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        return parseAnalysisResult(from: openaiResponse)
    }
}

struct AnalysisResult {
    let canDelete: Bool
    let confidence: Double  // 0.0-1.0
    let reason: String
    let riskLevel: RiskLevel
    let recoveryMethod: String?
    let estimatedSpaceFreed: Int64
}
```

---

## 三、用户界面设计

### 3.1 主界面（基于 Clean-Me）

```swift
struct MainView: View {
    @StateObject var viewModel = DiskCleanerViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部：磁盘使用情况
            DiskUsageHeaderView(stats: viewModel.diskStats)
            
            // 中间：扫描结果列表
            if viewModel.isScanning {
                ProgressView("扫描中...")
                    .padding()
            } else {
                List {
                    ForEach(viewModel.cleanupItems) { item in
                        CleanupItemRow(
                            item: item,
                            onTap: { viewModel.selectItem(item) }
                        )
                    }
                }
            }
            
            // 底部：操作按钮
            BottomActionBar(
                canExecute: viewModel.hasSelectedItems,
                onDryRun: { viewModel.executeDryRun() },
                onExecute: { viewModel.executeCleanup() }
            )
        }
        .onAppear {
            viewModel.startScanning()
        }
    }
}

struct CleanupItemRow: View {
    let item: CleanupItem
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: riskIcon)
                    .foregroundColor(riskColor)
                
                VStack(alignment: .leading) {
                    Text(item.name)
                        .font(.headline)
                    Text("\(formatBytes(item.size)) • \(item.category)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("\(Int(item.confidence * 100))%")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(item.source)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            // 建议理由
            Text(item.reason)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 8)
        .onTapGesture(perform: onTap)
    }
    
    private var riskIcon: String {
        switch item.riskLevel {
        case .low: return "checkmark.circle.fill"
        case .medium: return "exclamationmark.circle.fill"
        case .high: return "xmark.circle.fill"
        }
    }
    
    private var riskColor: Color {
        switch item.riskLevel {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
}
```

### 3.2 设置界面

```swift
struct SettingsView: View {
    @AppStorage("selectedLLMProvider") var selectedProvider: String = "grok"
    @State private var testingConnection = false
    @State private var connectionStatus: String?
    @State private var showAPIKeyInput = false
    
    var body: some View {
        Form {
            Section("LLM 配置") {
                Picker("优先 API", selection: $selectedProvider) {
                    ForEach(LLMProvider.allCases, id: \.rawValue) { provider in
                        Text(provider.displayName).tag(provider.rawValue)
                    }
                }
                .onChange(of: selectedProvider) { _ in
                    connectionStatus = nil
                }
            }
            
            Section("API 密钥") {
                HStack {
                    Text("状态")
                    Spacer()
                    if hasAPIKey(for: selectedProvider) {
                        Label("已配置", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Label("未配置", systemImage: "exclamationmark.circle")
                            .foregroundColor(.orange)
                    }
                }
                
                HStack(spacing: 12) {
                    Button(action: { showAPIKeyInput = true }) {
                        Label(
                            hasAPIKey(for: selectedProvider) ? "更新密钥" : "配置密钥",
                            systemImage: "key.fill"
                        )
                    }
                    
                    if hasAPIKey(for: selectedProvider) {
                        Button(role: .destructive, action: {
                            deleteAPIKey(for: selectedProvider)
                        }) {
                            Label("删除", systemImage: "trash")
                        }
                    }
                    
                    Button(action: testConnection) {
                        if testingConnection {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("测试中...")
                            }
                        } else {
                            Label("测试", systemImage: "bolt.circle")
                        }
                    }
                    .disabled(!hasAPIKey(for: selectedProvider) || testingConnection)
                }
                
                if let status = connectionStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundColor(status.contains("✅") ? .green : .red)
                }
            }
            
            Section("Prompt 管理") {
                NavigationLink("Prompt 模板管理", destination: PromptTemplateEditor())
                Toggle("启用 Prompt 优化", isOn: .constant(true))
            }
            
            Section("开发者信息") {
                Toggle("Swift 开发", isOn: $isDeveloping(.swift))
                Toggle("Python 开发", isOn: $isDeveloping(.python))
                Toggle("Node.js 开发", isOn: $isDeveloping(.nodejs))
                Toggle("Ruby 开发", isOn: $isDeveloping(.ruby))
            }
        }
        .navigationTitle("设置")
        .sheet(isPresented: $showAPIKeyInput) {
            APIKeyInputSheet(provider: selectedProvider) { key in
                saveAPIKey(key, for: selectedProvider)
                showAPIKeyInput = false
            }
        }
    }
    
    private func testConnection() {
        testingConnection = true
        Task {
            do {
                let provider = LLMProvider(rawValue: selectedProvider)!
                guard let apiKey = getAPIKey(for: provider.rawValue) else {
                    connectionStatus = "❌ 未配置 API 密钥"
                    testingConnection = false
                    return
                }
                
                let analyzer = createAnalyzer(provider: provider, apiKey: apiKey)
                
                // 测试 Prompt
                let testContext = AnalysisContext(
                    targetDirectory: FileMetadata(path: "test", sizeBytes: 1000),
                    userProfile: buildUserProfile(),
                    systemInfo: getSystemInfo(),
                    recentActivity: RecentActivity(lastAccessDate: nil, lastModifiedDate: Date(), accessCount: 0)
                )
                
                let testPrompt = PromptManager().buildOptimalPrompt(for: testContext)
                let _ = try await analyzer.analyze(context: testContext, prompt: testPrompt)
                
                connectionStatus = "✅ 连接成功"
            } catch {
                connectionStatus = "❌ \(error.localizedDescription)"
            }
            testingConnection = false
        }
    }
}
```

---

## 四、核心工作流程

### 4.1 完整分析流程

```
1. 用户启动扫描
   ↓
2. 磁盘递归扫描 (FileManager async)
   ↓
3. 规则引擎匹配 (Mole 规则库)
   │
   ├─ 低风险 → 自动标记为"可删"
   ├─ 中等风险 → 需要 AI 验证
   └─ 高风险 → 必须经过 AI 决策
   ↓
4. 对于需要 AI 验证的项目：
   │
   ├─ 收集上下文信息
   │  ├─ 文件元数据（大小、修改时间等）
   │  ├─ 用户开发栈信息
   │  └─ 系统信息
   │
   ├─ Prompt 管理器选择最优 Prompt 模板
   │
   ├─ 构建最终 Prompt
   │
   ├─ 调用 LLM API（GROK → 通义 → ChatGPT）
   │
   └─ 解析并验证响应
   ↓
5. 合并规则引擎结果和 AI 决策
   ↓
6. 按风险等级和置信度排序
   ↓
7. 展示给用户（可选 Dry Run）
   ↓
8. 用户确认后执行
   ├─ 记录审计日志
   ├─ 软删除（移至废纸篓）
   └─ 记录恢复信息
```

### 4.2 Prompt 优化流程

```
分析每个清理项目时：

1. 识别项目特征
   - 路径模式
   - 大小范围
   - 文件数量
   - 修改时间
   
2. 匹配适用的 Prompt 模板
   - 大型目录
   - 应用支持文件
   - 缓存文件
   - 开发相关目录
   - ...
   
3. 动态生成 Prompt
   - 插入具体的文件信息
   - 加入用户背景信息
   - 添加系统信息
   
4. 发送到 LLM
   - 解析响应
   - 验证 JSON 格式
   - 提取决策结果
```

---

## 五、技术栈选择

### 5.1 前端
- **SwiftUI** - 原生 macOS UI（参考 Clean-Me）
- **Async/Await** - 并发操作
- **Combine** - 状态管理

### 5.2 后端数据层
- **Keychain API** - 安全存储 API 密钥
- **UserDefaults** - 应用设置
- **FileManager** - 文件系统操作

### 5.3 第三方 API
- **GROK API**（首选）- 最便宜，足够快
- **Aliyun DashScope**（备选）- 中文最强，便宜
- **OpenAI API**（备选）- 通用选择

### 5.4 开源库
- **Mole 规则库**（Shell 脚本或移植到 Swift）
- **Clean-Me UI 框架**（SwiftUI 参考实现）

---

## 六、开发时间表

### Week 1：基础框架（5-6 天）
- [ ] 创建 Xcode 项目结构
- [ ] 集成 Clean-Me UI 框架
- [ ] 实现文件扫描服务（FileManager async）
- [ ] 构建规则引擎（Mole 规则迁移到 Swift）
- [ ] 完成基础 UI 布局

### Week 2：AI 集成（5-6 天）
- [ ] Keychain API 集成
- [ ] 3 个 LLM 分析器实现（GROK、通义、ChatGPT）
- [ ] **Prompt 管理系统实现**（关键！）
- [ ] SettingsView 实现
- [ ] 分析上下文收集

### Week 3：优化和测试（4-5 天）
- [ ] 完整流程集成测试
- [ ] Dry Run 模式
- [ ] 审计日志
- [ ] 错误处理和边界情况
- [ ] UI 打磨和优化

**总时间：2-3 周内 MVP 可上线**

---

## 七、成本估算

### 用户每月成本（按 100 次分析）
```
GROK: 100 次 × 300 tokens × $0.0005/1K = $0.015/月
通义: 100 次 × 300 tokens × $0.0008/1K = $0.024/月
ChatGPT: 100 次 × 300 tokens × $0.003/1K = $0.09/月
```

**用户成本：极低（微乎其微）**

### 你的成本
```
开发: 2-3 周工程师时间
服务器: $0
维护: 几乎无
```

**最优成本模型**

---

## 八、关键特性清单

### MVP 必须实现
- [ ] 基础磁盘扫描
- [ ] 规则引擎（25+ 规则）
- [ ] Prompt 管理系统（最关键）
- [ ] 3 个 LLM 支持（GROK、通义、ChatGPT）
- [ ] Keychain API Key 管理
- [ ] Dry Run 模式
- [ ] 软删除功能

### v1.1 可选增强
- [ ] 定时自动清理
- [ ] 更多 Prompt 模板
- [ ] 清理建议学习（用户反馈改进）
- [ ] 磁盘可视化（DiskUsage 图表）
- [ ] 详细统计和报告

---

## 九、最终建议

### 核心洞察总结

1. **Prompt 管理是决定成败的关键**
   - 不同场景需要不同的 Prompt
   - 高质量 Prompt = 高质量决策
   - 必须投入精力在 Prompt 工程上

2. **LLM 提供商选择（你的建议优于原方案）**
   - GROK 最快最便宜
   - 通义千问中文最强
   - ChatGPT 作为备选

3. **纯客户端 BYOK 架构完全正确**
   - 零服务器负担
   - 最大化隐私
   - 成本透明

4. **快速迭代最重要**
   - 2-3 周上线 MVP
   - 基于用户反馈改进 Prompt
   - 不断优化 AI 决策质量

### 立即行动
1. 读取 Mole 和 Clean-Me 源码
2. 设计 Prompt 模板库（核心优势）
3. 创建 Xcode 项目框架
4. Week 1 完成基础 UI + 文件扫描
5. Week 2 完成 LLM + Prompt 集成

**你已经有了最优的架构和技术方向。现在就开始编码！**
