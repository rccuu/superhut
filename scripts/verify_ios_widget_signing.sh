#!/bin/bash

set -euo pipefail

MODE="auto"
EXPECTED_APP_GROUP="${EXPECTED_APP_GROUP:-}"
WIDGET_APPEX_NAME="${WIDGET_APPEX_NAME:-CourseWidget.appex}"

usage() {
  echo "Usage: $0 [--mode auto|profile|trollstore] [--app-group group.id] path/to/app.ipa|path/to/app.tipa|path/to/Superhut.app"
  echo
  echo "Checks whether the main app and widget extension share a usable App Group."
  echo "  auto       Uses profile mode if any embedded profile exists, otherwise TrollStore mode."
  echo "  profile    Requires matching signed entitlements and embedded.mobileprovision App Groups."
  echo "  trollstore Requires matching signed entitlements only."
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    --app-group)
      EXPECTED_APP_GROUP="${2:-}"
      shift 2
      ;;
    *)
      INPUT_PATH="$1"
      shift
      ;;
  esac
done

INPUT_PATH="${INPUT_PATH:-}"
if [ -z "$INPUT_PATH" ]; then
  usage
  exit 2
fi

case "$MODE" in
  auto|profile|trollstore) ;;
  *)
    echo "ERROR: unknown mode: $MODE" >&2
    usage
    exit 2
    ;;
esac

if [ ! -e "$INPUT_PATH" ]; then
  echo "ERROR: input does not exist: $INPUT_PATH" >&2
  exit 2
fi

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: required tool not found: $1" >&2
    exit 2
  fi
}

require_tool codesign
require_tool plutil
require_tool security
require_tool unzip

TMP_DIR=""
cleanup() {
  if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT

ensure_tmp_dir() {
  if [ -z "$TMP_DIR" ]; then
    TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/superhut-ios-signing.XXXXXX")"
  fi
}

APP_PATH=""
case "$INPUT_PATH" in
  *.ipa|*.tipa)
    ensure_tmp_dir
    unzip -q "$INPUT_PATH" -d "$TMP_DIR"
    APP_PATH="$(find "$TMP_DIR/Payload" -maxdepth 1 -type d -name "*.app" | head -n 1)"
    ;;
  *.app)
    APP_PATH="$INPUT_PATH"
    ;;
  *)
    echo "ERROR: input must be a .ipa, .tipa, or .app bundle" >&2
    exit 2
    ;;
esac

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
  echo "ERROR: could not locate app bundle in input" >&2
  exit 2
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

bundle_id() {
  plist_get "$1/Info.plist" "CFBundleIdentifier"
}

bundle_executable_path() {
  local bundle="$1"
  local executable
  executable="$(plist_get "$bundle/Info.plist" "CFBundleExecutable")"
  if [ -z "$executable" ]; then
    return 1
  fi
  echo "$bundle/$executable"
}

print_array_values() {
  local plist="$1"
  local key_path="$2"
  { /usr/libexec/PlistBuddy -c "Print :$key_path" "$plist" 2>/dev/null || true; } \
    | sed -n 's/^[[:space:]]*//p' \
    | sed '/^Array {$/d;/^}$/d'
}

dump_entitlements() {
  local bundle="$1"
  local output="$2"
  local executable_path
  executable_path="$(bundle_executable_path "$bundle")" || return 1

  if codesign -d --entitlements :- "$executable_path" > "$output" 2>/dev/null; then
    if plutil -lint "$output" >/dev/null 2>&1; then
      return 0
    fi
  fi

  if command -v ldid >/dev/null 2>&1 && ldid -e "$executable_path" > "$output" 2>/dev/null; then
    if [ -s "$output" ] && plutil -lint "$output" >/dev/null 2>&1; then
      return 0
    fi
  fi

  return 1
}

decode_profile() {
  local bundle="$1"
  local output="$2"
  local profile="$bundle/embedded.mobileprovision"
  if [ ! -f "$profile" ]; then
    return 1
  fi
  security cms -D -i "$profile" > "$output" 2>/dev/null
}

write_group_file() {
  local plist="$1"
  local key_path="$2"
  local output="$3"
  print_array_values "$plist" "$key_path" | sort -u > "$output"
}

print_group_file() {
  local label="$1"
  local file="$2"
  echo "$label"
  if [ -s "$file" ]; then
    sed 's/^/  - /' "$file"
  else
    echo "  - <none>"
  fi
}

contains_group() {
  local file="$1"
  local group="$2"
  grep -Fxq "$group" "$file"
}

pick_common_group() {
  local main_ent_groups="$1"
  local widget_ent_groups="$2"
  local main_profile_groups="$3"
  local widget_profile_groups="$4"
  local require_profiles="$5"

  if [ -n "$EXPECTED_APP_GROUP" ]; then
    if ! contains_group "$main_ent_groups" "$EXPECTED_APP_GROUP"; then return 1; fi
    if ! contains_group "$widget_ent_groups" "$EXPECTED_APP_GROUP"; then return 1; fi
    if [ "$require_profiles" = "yes" ]; then
      if ! contains_group "$main_profile_groups" "$EXPECTED_APP_GROUP"; then return 1; fi
      if ! contains_group "$widget_profile_groups" "$EXPECTED_APP_GROUP"; then return 1; fi
    fi
    echo "$EXPECTED_APP_GROUP"
    return 0
  fi

  while IFS= read -r group; do
    if [ -z "$group" ]; then
      continue
    fi
    if ! contains_group "$widget_ent_groups" "$group"; then
      continue
    fi
    if [ "$require_profiles" = "yes" ]; then
      if ! contains_group "$main_profile_groups" "$group"; then
        continue
      fi
      if ! contains_group "$widget_profile_groups" "$group"; then
        continue
      fi
    fi
    echo "$group"
    return 0
  done < "$main_ent_groups"

  return 1
}

ensure_tmp_dir

MAIN_ENTITLEMENTS="$TMP_DIR/main.entitlements.plist"
WIDGET_ENTITLEMENTS="$TMP_DIR/widget.entitlements.plist"
MAIN_ENT_GROUPS="$TMP_DIR/main.entitlements.groups"
WIDGET_ENT_GROUPS="$TMP_DIR/widget.entitlements.groups"
MAIN_PROFILE="$TMP_DIR/main.mobileprovision.plist"
WIDGET_PROFILE="$TMP_DIR/widget.mobileprovision.plist"
MAIN_PROFILE_GROUPS="$TMP_DIR/main.profile.groups"
WIDGET_PROFILE_GROUPS="$TMP_DIR/widget.profile.groups"

echo "Input: $INPUT_PATH"
echo "Main app: $APP_PATH"
echo "Main bundle ID: $(bundle_id "$APP_PATH")"
echo "Widget extension: $WIDGET_PATH"
echo "Widget bundle ID: $(bundle_id "$WIDGET_PATH")"

if [ -n "$EXPECTED_APP_GROUP" ]; then
  echo "Expected app group: $EXPECTED_APP_GROUP"
else
  echo "Expected app group: <any common group>"
fi

if ! dump_entitlements "$APP_PATH" "$MAIN_ENTITLEMENTS"; then
  echo "FAIL: could not read signed entitlements from main app executable." >&2
  exit 1
fi
if ! dump_entitlements "$WIDGET_PATH" "$WIDGET_ENTITLEMENTS"; then
  echo "FAIL: could not read signed entitlements from widget executable." >&2
  exit 1
fi

write_group_file "$MAIN_ENTITLEMENTS" "com.apple.security.application-groups" "$MAIN_ENT_GROUPS"
write_group_file "$WIDGET_ENTITLEMENTS" "com.apple.security.application-groups" "$WIDGET_ENT_GROUPS"

main_profile_ok=no
widget_profile_ok=no
if decode_profile "$APP_PATH" "$MAIN_PROFILE"; then
  main_profile_ok=yes
  write_group_file "$MAIN_PROFILE" "Entitlements:com.apple.security.application-groups" "$MAIN_PROFILE_GROUPS"
else
  : > "$MAIN_PROFILE_GROUPS"
fi

if decode_profile "$WIDGET_PATH" "$WIDGET_PROFILE"; then
  widget_profile_ok=yes
  write_group_file "$WIDGET_PROFILE" "Entitlements:com.apple.security.application-groups" "$WIDGET_PROFILE_GROUPS"
else
  : > "$WIDGET_PROFILE_GROUPS"
fi

effective_mode="$MODE"
if [ "$effective_mode" = "auto" ]; then
  if [ "$main_profile_ok" = "yes" ] || [ "$widget_profile_ok" = "yes" ]; then
    effective_mode="profile"
  else
    effective_mode="trollstore"
  fi
fi

echo "Mode: $effective_mode"
print_group_file "Main signed app groups:" "$MAIN_ENT_GROUPS"
print_group_file "Widget signed app groups:" "$WIDGET_ENT_GROUPS"

require_profiles=no
if [ "$effective_mode" = "profile" ]; then
  require_profiles=yes
  if [ "$main_profile_ok" != "yes" ]; then
    echo "FAIL: main app embedded.mobileprovision is missing or unreadable." >&2
    exit 1
  fi
  if [ "$widget_profile_ok" != "yes" ]; then
    echo "FAIL: widget embedded.mobileprovision is missing or unreadable." >&2
    exit 1
  fi
  echo "Main profile application-identifier: $(plist_get "$MAIN_PROFILE" "Entitlements:application-identifier")"
  echo "Widget profile application-identifier: $(plist_get "$WIDGET_PROFILE" "Entitlements:application-identifier")"
  print_group_file "Main profile app groups:" "$MAIN_PROFILE_GROUPS"
  print_group_file "Widget profile app groups:" "$WIDGET_PROFILE_GROUPS"
fi

if common_group="$(pick_common_group "$MAIN_ENT_GROUPS" "$WIDGET_ENT_GROUPS" "$MAIN_PROFILE_GROUPS" "$WIDGET_PROFILE_GROUPS" "$require_profiles")"; then
  echo
  echo "PASS: shared App Group is available in required signing metadata: $common_group"
else
  echo
  echo "FAIL: no shared App Group was found across the required signing metadata." >&2
  if [ "$effective_mode" = "profile" ]; then
    echo "For personal/developer signing, both signed entitlements and both provisioning profiles must contain the same App Group." >&2
  else
    echo "For TrollStore, fakesign both the main app executable and widget executable with the same App Group entitlement." >&2
  fi
  exit 1
fi
