# macOS AI Disk Cleaner v2.0 - 快速参考指南

## 📌 项目核心（v2.0 更新）

**三大支柱**：
1. **规则引擎**（80%）- Mole 的 25+ 成熟规则
2. **Prompt 管理系统**（新增！关键创新）- 动态生成高质量提示词
3. **纯客户端 BYOK** - 用户自己配置 API 密钥

---

## 🔑 LLM 提供商优先级（已更新）

你的建议，更优的选择：

| 排序 | 提供商 | 价格/1K tokens | 优势 | 何时用 |
|------|--------|--------------|------|-------|
| **#1** | GROK (xAI) | $0.0005 | **最快最便宜** | 首选（推荐） |
| **#2** | 通义千问 | $0.0008 | **中文最强** | 中文用户首选 |
| **#3** | ChatGPT | $0.003 | 生态完整 | 用户已有账户 |

**成本对比**（100 次分析/月）：
```
GROK: $0.015/月
通义: $0.024/月  
ChatGPT: $0.09/月
```

---

## 🎯 核心创新：Prompt 管理系统

**为什么这很关键？**
- 不同文件类型需要不同的分析角度
- 用户背景（Swift/Python/Node.js）影响决策
- 高质量 Prompt = 高质量 AI 决策

**实现方案**：

```swift
// 1. 定义场景-Prompt 映射
enum AnalysisScenario {
    case largeDirectory      // >500MB 的目录
    case cacheFiles          // 缓存文件
    case appSupportFiles     // 应用支持文件
    case nodeDependencies    // node_modules
    case pythonEnv          // Python venv
    case buildArtifacts     // 编译产物
    case unknown
}

// 2. 为每个场景创建优化的 Prompt 模板
protocol PromptTemplate {
    func build(context: AnalysisContext) -> String
}

class LargeDirectoryPromptTemplate: PromptTemplate {
    func build(context: AnalysisContext) -> String {
        """
你是 macOS 磁盘清理专家。分析这个目录：
- 路径: \(context.path)
- 大小: \(context.size)
- 修改时间: \(context.lastModified)
- 用户背景: \(context.userStack)  // "Swift developer"

判断是否可删除？返回 JSON:
{ "can_delete": true|false, "confidence": 0.0-1.0 }
"""
    }
}

// 3. 智能选择最合适的 Prompt
class PromptManager {
    func selectBestPrompt(for item: FileItem) -> String {
        let scenario = identifyScenario(item)
        let template = templates[scenario]
        return template.build(context: buildContext(item))
    }
}
```

**Prompt 模板库**（需要设计）：
- [ ] 大型目录分析
- [ ] 缓存文件分析
- [ ] 应用支持文件分析
- [ ] node_modules 专题
- [ ] Python venv 专题
- [ ] Xcode 产物分析
- [ ] 系统日志分析
- [ ] 浏览器数据分析
- ... 更多

**关键点**：每个模板都要考虑用户的开发栈和磁盘状况。

---

## 🏗️ 架构简图

```
┌──────────────────────────────────┐
│    macOS SwiftUI 应用             │
├──────────────────────────────────┤
│  规则引擎 (Mole 25+ 规则)        │
│  ↓ 低风险 → 自动标记             │
│  ↓ 中等风险 → AI 验证             │
│  ↓ 高风险 → AI 决策              │
├──────────────────────────────────┤
│  Prompt 管理系统（核心！）       │
│  ├─ 场景识别                     │
│  ├─ 选择最优 Prompt 模板        │
│  └─ 动态构建 Prompt              │
├──────────────────────────────────┤
│  LLM 分析器                      │
│  ├─ GROK (首选)                 │
│  ├─ 通义千问 (备选)              │
│  └─ ChatGPT (备选)              │
├──────────────────────────────────┤
│  Keychain + UserDefaults         │
│  (API Key 和配置管理)            │
└──────────────────────────────────┘
```

---

## 📋 开发清单（2-3 周）

### Week 1：基础框架
- [ ] Xcode 项目结构 (Target: macOS, **Non-Sandboxed**)
- [ ] 实现 **Full Disk Access** 权限请求流程
- [ ] 集成 **Sparkle** (自动更新)
- [ ] 文件扫描器（需实现 **Symlink 不追随** & **iCloud 跳过**）
- [ ] 规则引擎（Mole 规则移植）

### Week 2：Prompt + LLM 集成（关键周）
- [ ] **Prompt 管理系统** ⭐
  - [ ] 定义所有场景
  - [ ] 编写 Prompt 模板（最重要）
  - [ ] 场景识别算法
- [ ] Keychain API 集成
- [ ] 3 个 LLM 分析器（GROK、通义、ChatGPT）
- [ ] SettingsView

### Week 3：整合 + 测试
- [ ] 完整流程集成测试
- [ ] Dry Run 模式
- [ ] 审计日志
- [ ] UI 优化

---

## 💡 Prompt 工程的重要性

**AI 决策质量 = Prompt 质量 + LLM 能力**

你的洞察很对：**不同场景需要不同 Prompt**

### 示例 1：大型目录

❌ **通用 Prompt**：
```
这个目录可以删除吗？
```

✅ **优化 Prompt**：
```
这是一个 45GB 的 Xcode 编译缓存目录。
用户是 Swift 开发者，最近 7 天没有打开 Xcode。
磁盘使用率 96%，急需释放空间。

可以安全删除吗？重编译时会自动重建。
返回 JSON: { "can_delete": true|false, "confidence": 0.0-1.0 }
```

### 示例 2：应用支持文件

❌ **通用 Prompt**：
```
~/Library/Application Support/SomeApp 可以删除吗？
```

✅ **优化 Prompt**：
```
应用: SomeApp (2.3GB)
状态: 已卸载（用户最近卸载了）
文件类型: 应用支持文件（缓存、配置、数据）
风险: 永久删除（无法恢复）

这是一个已卸载应用的支持文件。
可以安全删除吗？返回 JSON...
```

**差异**：优化版本有更多上下文，AI 能做出更准确的决策。

---

## 🎯 关键指标

### 成功标准
- **准确率** ≥ 95%（错误删除率 < 5%）
- **响应时间** < 2 秒/项（GROK 很快）
- **用户满意度** ≥ 4.5/5

### 优化目标
- 随着时间改进 Prompt（用户反馈循环）
- 增加更多细化场景
- 根据用户反馈调整 Prompt

---

## 🚀 快速启动指令

```bash
# 1. 准备工作
git clone https://github.com/tw93/Mole.git
git clone https://github.com/Kevin-De-Koninck/Clean-Me.git

# 2. 创建项目
xcode-select --install
# 创建新 Xcode 项目（macOS App）

# 3. Week 1 目标
# - 复制 Clean-Me 的 SwiftUI UI
# - 移植 Mole 的规则到 Swift
# - 实现基础文件扫描

# 4. Week 2 目标（关键）
# - 设计和实现 Prompt 管理系统
# - 集成 GROK API
# - 集成 Keychain

# 5. Week 3 目标
# - 完整集成测试
# - 性能优化
# - 用户测试
```

---

## 📊 成本分析（已验证）

### 你的成本
```
开发投入: 2-3 周
服务器: $0
维护: ~0（仅需维护 macOS 应用）
```

### 用户成本
```
使用成本：极低（$0.01-0.1/月）
隐私成本：无（API Key 本地存储）
```

### ROI
```
投入: 2-3 周开发
产出: 完整的 macOS 应用 + 无限用户数
回报: 非常高
```

---

## ⚠️ 最常见的陷阱

❌ **陷阱 1**：编写通用 Prompt
✅ **避免**：为每个场景编写优化 Prompt

❌ **陷阱 2**：选错 LLM 提供商
✅ **避免**：用 GROK（最快最便宜）

❌ **陷阱 3**：过度设计后端
✅ **避免**：纯客户端 BYOK 足够

❌ **陷阱 4**：忽视 Keychain 安全
✅ **避免**：使用 Keychain 存储 API Key

❌ **陷阱 5**：没有 Dry Run 模式
✅ **避免**：实现预览模式让用户确认

---

## 🎁 额外资源

### 必读文档
1. `complete_design_doc_v2.md` - 完整技术设计
2. `pure_client_architecture.md` - BYOK 实现细节
3. `architecture_decision_summary.md` - 架构对比分析

### 参考项目
- **Mole** - https://github.com/tw93/Mole （规则库）
- **Clean-Me** - https://github.com/Kevin-De-Koninck/Clean-Me （UI 框架）

### API 文档
- **GROK** - https://console.groq.com/docs
- **阿里通义** - https://help.aliyun.com/zh/dashscope
- **OpenAI** - https://platform.openai.com/docs

---

## ✅ 最终确认

### 你的方案（v2.0）
- ✅ **纯客户端** - 无后端复杂度
- ✅ **BYOK** - 用户自己配置密钥
- ✅ **Prompt 管理** - 高质量 AI 决策的基础
- ✅ **GROK > 通义 > ChatGPT** - 最优 LLM 选择
- ✅ **2-3 周可上线** - 快速迭代

### 核心成功因素
1. **Prompt 管理系统是关键** - 投入最多精力在这里
2. **场景识别很重要** - 准确识别文件类型和用户背景
3. **用户反馈循环** - 上线后持续改进 Prompt
4. **GROK 是最优选择** - 快、便宜、足够聪明

---

## 🎯 下一步（今天就开始）

1. 📖 仔细阅读 `complete_design_doc_v2.md`
2. 💭 设计你的 Prompt 模板库（关键！）
3. 🔧 创建 Xcode 项目框架
4. 📝 列出所有需要的 Prompt 场景
5. 💻 Week 1 开始编码

**预计 3 周内完成 MVP，然后持续优化 Prompt。**

**祝你开发顺利！** 🚀
