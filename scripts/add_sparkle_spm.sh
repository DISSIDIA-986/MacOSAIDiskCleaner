#!/bin/bash
#
# Helper script to add Sparkle SPM dependency using Xcode CLI
# This script attempts to automate SPM dependency addition as much as possible
#

set -e

PROJECT_PATH="MacOSAIDiskCleaner.xcodeproj"
SCHEME_NAME="MacOSAIDiskCleaner"
SPARKLE_URL="https://github.com/sparkle-project/Sparkle"

echo "═══════════════════════════════════════════════════════════"
echo "  Sparkle SPM 依赖添加助手"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "此脚本将尝试通过命令行为您添加 Sparkle SPM 依赖。"
echo "如果命令行方法失败，会提供详细的 GUI 操作指南。"
echo ""

# 检查 Xcode 是否安装
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ 错误: 未找到 xcodebuild"
    echo "请确保已安装 Xcode"
    exit 1
fi

echo "✅ 找到 Xcode: $(xcodebuild -version | head -1)"
echo ""

# 尝试打开 Xcode 并自动导航到 Package Dependencies
echo "📱 方法 1: 使用 Xcode CLI (如果支持)"
echo "─────────────────────────────────────────────────────────"

# 检查项目是否存在
if [ ! -d "$PROJECT_PATH" ]; then
    echo "❌ 错误: 找不到项目文件 $PROJECT_PATH"
    exit 1
fi

echo "✅ 找到项目: $PROJECT_PATH"
echo ""

# 尝试使用 xcodebuild 解析包依赖（但这需要先在 project.pbxproj 中配置）
# 所以这个方法可能不会工作

echo "⚠️  命令行方法无法直接添加新的 SPM 依赖（Xcode 限制）"
echo ""
echo "📱 方法 2: 使用 Xcode GUI（推荐）"
echo "─────────────────────────────────────────────────────────"
echo ""
echo "由于 Xcode 的项目文件格式复杂，添加 SPM 依赖需要使用 GUI。"
echo "下面是详细的步骤说明："
echo ""

cat << 'EOF'
╔════════════════════════════════════════════════════════════════╗
║  详细操作步骤（带有屏幕位置提示）                              ║
╔════════════════════════════════════════════════════════════════╗

📍 第 1 步: 打开项目
  → 在终端运行: open MacOSAIDiskCleaner.xcodeproj
  → 或者: 在 Xcode 中选择 File → Open → 选择项目文件

📍 第 2 步: 选择项目导航器
  → 确保左侧项目导航器可见 (⌘ + 1)
  → 点击最顶部的蓝色项目图标
  → 在编辑器区域中间会显示项目和大纲

📍 第 3 步: 进入 Package Dependencies 标签
  → 在编辑器区域中间，选择 "MacOSAIDiskCleaner" 项目（蓝色图标）
  → 在右侧标签栏中选择 "Package Dependencies" 标签
  → （如果在 Tabs 区域看不到，向下滚动）

📍 第 4 步: 添加 Sparkle 依赖
  → 点击 Package Dependencies 区域底部的 "+" 按钮
  → 在弹出的对话框中，输入或粘贴 URL:
    https://github.com/sparkle-project/Sparkle

📍 第 5 步: 配置依赖规则
  → Dependency Rule 选择 "Up to Next Major Version"
  → Minimum Version 输入: 2.0.0
  → 点击 "Add Package" 按钮

📍 第 6 步: 确认 Target 选择
  → 在 "Choose Package Products" 对话框中
  → 确保勾选了 "Sparkle" 库
  → 确保 "MacOSAIDiskCleaner" target 被选中
  → 点击 "Add Package"

📍 第 7 步: 等待解析
  → Xcode 会自动下载并解析 Sparkle 依赖
  → 左侧会显示下载进度
  → 完成后会看到 "Sparkle" 出现在 Package Dependencies 列表中

📍 第 8 步: 验证和构建
  → Clean Build Folder: ⌘ + Shift + K
  → 构建项目: ⌘ + B
  → 确保没有错误

╚════════════════════════════════════════════════════════════════╝

EOF

echo "⚡ 快捷键提示:"
echo "  ⌘ + 1  : 显示/隐藏项目导航器"
echo "  ⌘ + Shift + K : Clean Build Folder"
echo "  ⌘ + B  : 构建项目"
echo ""

# 提供验证命令
echo "🔍 完成后验证:"
echo "─────────────────────────────────────────────────────────"
echo ""
echo "运行以下命令验证 Sparkle 已成功添加:"
echo ""
echo "  grep -i sparkle MacOSAIDiskCleaner.xcodeproj/project.pbxproj"
echo ""
echo "如果看到 Sparkle 相关的引用，说明添加成功！"
echo ""

# 询问是否现在打开 Xcode
read -p "❓ 是否现在打开 Xcode 项目? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 正在打开 Xcode..."
    open "$PROJECT_PATH"
    echo ""
    echo "✅ Xcode 已打开，请按照上述步骤操作"
else
    echo ""
    echo "💡 提示: 您可以随时运行以下命令打开 Xcode:"
    echo "  open MacOSAIDiskCleaner.xcodeproj"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  需要帮助? 查看 docs/SPARKLE_SETUP.md 获取详细指南"
echo "═══════════════════════════════════════════════════════════"
