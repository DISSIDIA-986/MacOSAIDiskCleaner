#!/bin/bash

# 一键发布脚本
VERSION="0.1.0"
DIST_DIR="dist"
TOOLS_DIR="sparkle_bin/bin"

echo "🚀 开始构建 Release 版本..."
xcodebuild -scheme MacOSAIDiskCleaner -configuration Release clean build CONFIGURATION_BUILD_DIR=./build/Release

echo "📦 正在打包 DMG..."
mkdir -p $DIST_DIR
rm -f $DIST_DIR/*.dmg
create-dmg \
  --volname "MacOSAIDiskCleaner" \
  --background "dmg_background.png" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "MacOSAIDiskCleaner.app" 100 190 \
  --hide-extension "MacOSAIDiskCleaner.app" \
  --app-drop-link 450 190 \
  "$DIST_DIR/MacOSAIDiskCleaner_$VERSION.dmg" \
  "build/Release/MacOSAIDiskCleaner.app"

echo "📄 正在生成 appcast.xml..."
./$TOOLS_DIR/generate_appcast $DIST_DIR/

echo "✅ 发布准备就绪！请将 $DIST_DIR 目录下的文件上传到您的服务器。"
