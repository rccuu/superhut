#!/bin/bash

set -euo pipefail

EXPECTED_APP_GROUP="${EXPECTED_APP_GROUP:-group.com.tune.superhut.coursewidget}"
APP_BUNDLE_NAME="${APP_BUNDLE_NAME:-Superhut.app}"
WIDGET_APPEX_NAME="${WIDGET_APPEX_NAME:-CourseWidget.appex}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
RUNNER_ENTITLEMENTS="$SCRIPT_DIR/trollstore/Runner.entitlements.plist"
WIDGET_ENTITLEMENTS="$SCRIPT_DIR/trollstore/CourseWidget.entitlements.plist"

usage() {
  echo "Usage: $0 [path/to/unsigned.ipa]"
  echo
  echo "Builds a TrollStore fakesigned IPA. If no IPA is provided, it first builds"
  echo "the regular unsigned IPA with scripts/build_ios_quick.sh."
  echo
  echo "Set LDID=/path/to/ldid if ldid is not in PATH."
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

LDID_BIN="${LDID:-}"
if [ -z "$LDID_BIN" ]; then
  LDID_BIN="$(command -v ldid || true)"
fi
if [ -z "$LDID_BIN" ] || [ ! -x "$LDID_BIN" ]; then
  echo "ERROR: ldid is required for TrollStore fakesign. Install ldid or set LDID=/path/to/ldid." >&2
  exit 2
fi

if [ ! -f "$RUNNER_ENTITLEMENTS" ] || [ ! -f "$WIDGET_ENTITLEMENTS" ]; then
  echo "ERROR: missing TrollStore entitlement plist files under scripts/trollstore." >&2
  exit 2
fi

cd "$PROJECT_ROOT"

INPUT_IPA="${1:-}"
if [ -z "$INPUT_IPA" ]; then
  bash scripts/build_ios_quick.sh
  INPUT_IPA="$(ls -t releases/*-unsigned-*.ipa | head -n 1)"
fi

if [ ! -f "$INPUT_IPA" ]; then
  echo "ERROR: unsigned IPA not found: $INPUT_IPA" >&2
  exit 2
fi

VERSION="$(grep "version:" pubspec.yaml | awk '{print $2}' | tr -d '\r')"
TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
OUTPUT_IPA="releases/superhut-v${VERSION}-trollstore-${TIMESTAMP}.ipa"
WORK_DIR="build/ios/trollstore"

echo "🚀 开始构建 SuperHUT TrollStore IPA..."
echo "📦 输入 IPA: $INPUT_IPA"
echo "🔏 ldid: $LDID_BIN"

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
unzip -q "$INPUT_IPA" -d "$WORK_DIR"

APP_PATH="$WORK_DIR/Payload/$APP_BUNDLE_NAME"
if [ ! -d "$APP_PATH" ]; then
  APP_PATH="$(find "$WORK_DIR/Payload" -maxdepth 1 -type d -name "*.app" | head -n 1)"
fi
if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
  echo "ERROR: app bundle not found in IPA." >&2
  exit 1
fi

WIDGET_PATH="$APP_PATH/PlugIns/$WIDGET_APPEX_NAME"
if [ ! -d "$WIDGET_PATH" ]; then
  echo "ERROR: widget extension not found: $WIDGET_PATH" >&2
  exit 1
fi

plist_get() {
  local plist="$1"
  local key_path="$2"
  /usr/libexec/PlistBuddy -c "Print :$key_path" "$plist" 2>/dev/null || true
}

app_executable="$(plist_get "$APP_PATH/Info.plist" "CFBundleExecutable")"
widget_executable="$(plist_get "$WIDGET_PATH/Info.plist" "CFBundleExecutable")"
if [ -z "$app_executable" ] || [ -z "$widget_executable" ]; then
  echo "ERROR: could not resolve app or widget executable name." >&2
  exit 1
fi

APP_EXECUTABLE_PATH="$APP_PATH/$app_executable"
WIDGET_EXECUTABLE_PATH="$WIDGET_PATH/$widget_executable"
if [ ! -f "$APP_EXECUTABLE_PATH" ] || [ ! -f "$WIDGET_EXECUTABLE_PATH" ]; then
  echo "ERROR: app or widget executable is missing." >&2
  exit 1
fi

find "$APP_PATH" -name "_CodeSignature" -type d -prune -exec rm -rf {} +
find "$APP_PATH" -name "embedded.mobileprovision" -type f -delete

echo "🔏 fakesign main app executable..."
"$LDID_BIN" "-S$RUNNER_ENTITLEMENTS" "$APP_EXECUTABLE_PATH"

echo "🔏 fakesign widget executable..."
"$LDID_BIN" "-S$WIDGET_ENTITLEMENTS" "$WIDGET_EXECUTABLE_PATH"

mkdir -p releases
rm -f "$OUTPUT_IPA"
(
  cd "$WORK_DIR"
  zip -r "$PROJECT_ROOT/$OUTPUT_IPA" Payload > /dev/null
)

echo "✅ TrollStore IPA 构建完成！"
echo "📦 文件位置: $OUTPUT_IPA"
echo "📏 文件大小: $(ls -lh "$OUTPUT_IPA" | awk '{print $5}')"

bash scripts/verify_ios_widget_signing.sh --mode trollstore --app-group "$EXPECTED_APP_GROUP" "$OUTPUT_IPA"
