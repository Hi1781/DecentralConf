#!/usr/bin/env bash
# ============================================================
# OneApp 打包脚本 —— 对齐参考 App 的标准打包链
# 链：xcodegen 生成工程 → xcodebuild 编译 → codesign 签名 → 组装 IPA
# 注意：iOS 编译必须在本机为 macOS 且已装 Xcode + XcodeGen 的环境运行。
#       (brew install xcodegen) 在 Linux 上无法编译 iOS，勿在此运行。
# ============================================================
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIGURATION="${CONFIGURATION:-Release}"
SCHEME="OneApp"
OUT="${1:-build}"
mkdir -p "$OUT"
rm -rf "$OUT/Payload" "$OUT/OneApp.ipa"

echo "[1/4] 生成 Xcode 工程 (xcodegen)"
xcodegen generate

echo "[2/4] 编译 ($CONFIGURATION)"
xcodebuild \
  -project OneApp.xcodeproj \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'generic/platform=iOS' \
  -archivePath "$OUT/OneApp.xcarchive" \
  -allowProvisioningUpdates \
  archive

echo "[3/4] 组装 Payload/OneApp.app"
APP_ARCHIVE="$OUT/OneApp.xcarchive/Products/Applications/OneApp.app"
[ -d "$APP_ARCHIVE" ] || { echo "未找到编译产物: $APP_ARCHIVE"; exit 1; }
mkdir -p "$OUT/Payload"
# 复制并做最终重签名（主程序 + 每个 framework + 每个 extension，写 _CodeSignature）
cp -R "$APP_ARCHIVE" "$OUT/Payload/"
codesign --force --deep --sign - --entitlements OneApp/OneApp.entitlements \
  "$OUT/Payload/OneApp.app" 2>/dev/null \
  || echo "（跳过重签名：如需侧载/发布请配置描述文件）"

echo "[4/4] 打包 OneApp.ipa（zip, Payload 为根）"
cd "$OUT"
zip -qr OneApp.ipa Payload
cd ..
echo "完成：$OUT/OneApp.ipa"
