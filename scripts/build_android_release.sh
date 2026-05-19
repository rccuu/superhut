#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

VERSION=$(grep "version:" pubspec.yaml | awk '{print $2}' | tr -d '\r')
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_DIR="$PROJECT_ROOT/releases"
BUILD_OUTPUT_DIR="$PROJECT_ROOT/build/app/outputs/flutter-apk"

echo "🚀 开始构建 Android arm64-v8a 安装包..."
echo "📦 版本: $VERSION"

flutter build apk --release --target-platform android-arm64

mkdir -p "$OUTPUT_DIR"

SOURCE_APK="$BUILD_OUTPUT_DIR/app-release.apk"
TARGET_APK="$OUTPUT_DIR/superhut-v${VERSION}-arm64-v8a-release-${TIMESTAMP}.apk"

if [ ! -f "$SOURCE_APK" ]; then
  echo "❌ 缺少构建产物: $SOURCE_APK"
  exit 1
fi

mv "$SOURCE_APK" "$TARGET_APK"
echo "✅ 已输出: releases/$(basename "$TARGET_APK")"

echo "📁 Android 安装包已移动到 releases/"
