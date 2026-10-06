#!/bin/bash
# ============================================================================
# OneApp 第一版 —— Ubuntu/Linux 交叉编译，产出「未签名裸 raw.ipa」
# ----------------------------------------------------------------------------
# 打包链蓝本：ClipboardHistory-deploy/build_linux.sh（本机已验证的 iOS 交叉输出链）
# host=linux  target=arm64-apple-ios16.0
#   swiftc + ld64.lld 交叉编译 -> arm64 Mach-O（adhoc 签名槽 + ldid 嵌入授权）
#   手动搭建 Payload/OneApp.app（Info.plist / PkgInfo / 图标 / PlugIns）
#   规范化 zip -> raw ipa；设备端由 SideStore / AltStore 完成签名安装。
# ============================================================================
set -euo pipefail

APP_NAME="OneApp"
BUNDLE_ID="org.oneapp.OneApp"
MARK_VER="0.5.0"; CUR_VER="5"
DEPLOY="16.0"; SDK_VER="16.4"
TARGET="arm64-apple-ios${DEPLOY}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="${ROOT}/build-linux"
APP="${BUILD}/Payload/${APP_NAME}.app"
OUT_IPA="${BUILD}/${APP_NAME}-${MARK_VER}-raw-unsigned.ipa"

# ---- 工具链探测（持久目录）----
SWIFT_TOOLCHAIN="${SWIFT_TOOLCHAIN:-}"
IOS_SDK="${IOS_SDK:-}"
for c in "$SWIFT_TOOLCHAIN" /home/user/.doubao/agent_mode/workspace/toolchain/swift-5.8-RELEASE-ubuntu22.04/usr; do
    [[ -z "$c" ]] && continue
    [[ -x "$c/bin/swiftc" ]] && { SWIFT_TOOLCHAIN="$c"; break; }
done
for s in "$IOS_SDK" /home/user/.doubao/agent_mode/workspace/toolchain/iPhoneOS16.4.sdk; do
    [[ -z "$s" ]] && continue
    [[ -d "$s/usr/include" ]] && { IOS_SDK="$s"; break; }
done
[[ -x "${SWIFT_TOOLCHAIN}/bin/swiftc" ]] || { echo "❌ 未找到 swiftc"; exit 1; }
[[ -d "${IOS_SDK}" ]] || { echo "❌ 未找到 iOS SDK"; exit 1; }
SWIFTC="${SWIFT_TOOLCHAIN}/bin/swiftc"
echo "swiftc: ${SWIFTC}"
echo "SDK:    ${IOS_SDK}"

# ---- ldid：嵌入 entitlements（ad-hoc）----
LDID="${LDID:-}"
for c in "$LDID" /home/user/.doubao/agent_mode/workspace/toolchain/bin/ldid "$(command -v ldid)"; do
    [[ -z "$c" ]] && continue
    [[ -x "$c" ]] && { LDID="$c"; break; }
done
[[ -n "$LDID" ]] || { echo "❌ 未找到 ldid"; exit 1; }
echo "ldid:   ${LDID}"

# ---- ld 包装：转调 ld64.lld ----
LINKBIN="${BUILD}/linkbin"; mkdir -p "$LINKBIN"
cat > "$LINKBIN/ld" <<EOF
#!/bin/bash
exec "${SWIFT_TOOLCHAIN}/bin/ld64.lld" "\$@"
EOF
chmod +x "$LINKBIN/ld"
export PATH="${LINKBIN}:${SWIFT_TOOLCHAIN}/bin:$PATH"

# ---- resource-dir（绝对路径，剔除冲突模块）----
RES="$(mkdir -p "${BUILD}/resource-dir" && cd "${BUILD}/resource-dir" && pwd)"
if [[ ! -f "${RES}/.prepared" ]]; then
  rm -rf "${RES:?}"/*
  cp -R "${SWIFT_TOOLCHAIN}/lib/swift/"*.swift "${RES}/" 2>/dev/null || true
  cp -R "${SWIFT_TOOLCHAIN}/lib/swift/linux" "${RES}/" 2>/dev/null || true
  rm -rf "${RES}/dispatch" "${RES}/os" "${RES}/CoreFoundation" "${RES}/Block" "${RES}/linux" 2>/dev/null || true
  CLANG_VER="$(ls "${SWIFT_TOOLCHAIN}/lib/clang" | head -1)"
  mkdir -p "${RES}/clang"
  cp -R "${SWIFT_TOOLCHAIN}/lib/clang/${CLANG_VER}/include" "${RES}/clang/" 2>/dev/null || true
  mkdir -p "${RES}/apinotes"
  for ap in Dispatch.apinotes os.apinotes; do
    for cand in /home/user/.doubao/agent_mode/workspace/toolchain/swift-apinotes/apinotes/$ap; do
      [[ -f "$cand" ]] && cp "$cand" "${RES}/apinotes/" && break
    done
  done
  touch "${RES}/.prepared"
fi

COMMON=(-target "$TARGET" -sdk "$IOS_SDK" -resource-dir "$RES" -O -parse-as-library
        -Xcc -fmodules-cache-path="${BUILD}/mcapp")
LINKV=(-Xlinker -adhoc_codesign \
       -Xlinker -platform_version -Xlinker ios -Xlinker "${DEPLOY}.0" -Xlinker "$SDK_VER")

mkdir -p "${APP}/PlugIns/ShareExtension.appex" "${APP}/PlugIns/NotificationServiceExtension.appex"

subst(){ sed -e "s/\\\$(EXECUTABLE_NAME)/$1/g" -e "s/\\\$(PRODUCT_MODULE_NAME)/$1/g" \
    -e "s/\\\$(PRODUCT_NAME)/$1/g" -e "s/\\\$(PRODUCT_BUNDLE_IDENTIFIER)/$2/g" \
    -e "s/\\\$(MARKETING_VERSION)/${MARK_VER}/g" -e "s/\\\$(CURRENT_PROJECT_VERSION)/${CUR_VER}/g" "$3"; }

echo "==> [1/4] 主 App"
mapfile -t APPSRC < <(find "${ROOT}/OneApp" -name '*.swift' | sort)

# ---- 融合的 Rust 核心（LocalSend）----
export PATH="/home/user/.cargo/bin:$PATH"
echo "==> [0/4] 交叉编译 Rust 核心 → iOS 静态库"
SDKROOT="$IOS_SDK" IPHONEOS_DEPLOYMENT_TARGET="$DEPLOY" \
  CC_aarch64_apple_ios="${ROOT}/rust-core/cross/cc-ios" \
  CARGO_TARGET_DIR="${ROOT}/rust-core/target" \
  cargo build --manifest-path "${ROOT}/rust-core/Cargo.toml" \
  --release --target aarch64-apple-ios 2>&1 | tail -2
CORE_LIB="${ROOT}/rust-core/target/aarch64-apple-ios/release/liboneapp_core.a"
[ -f "$CORE_LIB" ] || { echo "❌ Rust 核心未产出: $CORE_LIB"; exit 1; }
echo "  ✓ liboneapp_core.a ($(du -h "$CORE_LIB" | cut -f1))"

# ---- 融合的 C++ 核心（whisper.cpp，AI 转写）----
echo "==> [0.5/4] 交叉编译 whisper.cpp → iOS 静态库"
WHISPER_LIB="${ROOT}/whisper-ios/libwhisper.a"
[ -f "$WHISPER_LIB" ] || bash "${ROOT}/scripts/build_whisper_ios.sh" 2>&1 | tail -3
[ -f "$WHISPER_LIB" ] || { echo "❌ whisper 核心未产出"; exit 1; }
echo "  ✓ libwhisper.a ($(du -h "$WHISPER_LIB" | cut -f1))"

# ---- 融合的去中心化会议信令核心（libp2p，无服务器）----
echo "==> [0.6/4] 交叉编译去中心化会议信令 → iOS 静态库"
MEETING_LIB="${ROOT}/meeting-core/target/aarch64-apple-ios/release/liboneapp_meeting_core.a"
if [ ! -f "$MEETING_LIB" ]; then
  SDKROOT="$IOS_SDK" IPHONEOS_DEPLOYMENT_TARGET="$DEPLOY" \
    CC_aarch64_apple_ios="${ROOT}/meeting-core/cross/cc-ios" \
    CXX_aarch64_apple_ios="${ROOT}/meeting-core/cross/cc-ios" \
    cargo build --manifest-path "${ROOT}/meeting-core/Cargo.toml" \
    --release --target aarch64-apple-ios --lib 2>&1 | tail -3
fi
[ -f "$MEETING_LIB" ] || { echo "❌ 会议信令核心未产出"; exit 1; }
echo "  ✓ liboneapp_meeting_core.a ($(du -h "$MEETING_LIB" | cut -f1))"

# Rust/C++ 静态库链接所需系统库：蓝本同款 + libc++/pthread（C++ 运行时）
# libp2p 会议信令额外需要 SystemConfiguration / Security 框架
RUSTLIBS=(-Xlinker -framework -Xlinker CoreFoundation -Xlinker -framework -Xlinker WebKit \
          -Xlinker -framework -Xlinker SystemConfiguration -Xlinker -framework -Xlinker Security \
          -lz -lm -liconv -lc++ -lpthread)
"$SWIFTC" "${COMMON[@]}" -module-name OneApp -emit-executable \
  "${LINKV[@]}" "${RUSTLIBS[@]}" \
  -o "${APP}/OneApp" "${CORE_LIB}" "$WHISPER_LIB" "$MEETING_LIB" "${APPSRC[@]}"

echo "==> [2/4] 分享扩展（MH_EXECUTE + NSExtensionMain）"
"$SWIFTC" "${COMMON[@]}" -module-name ShareExtension -emit-executable \
  -Xlinker -e -Xlinker _NSExtensionMain -Xlinker -rpath -Xlinker @executable_path/../../Frameworks "${LINKV[@]}" \
  -o "${APP}/PlugIns/ShareExtension.appex/ShareExtension" "${ROOT}"/Extensions/ShareExtension/*.swift

echo "==> [3/4] 通知服务扩展（MH_EXECUTE + NSExtensionMain）"
"$SWIFTC" "${COMMON[@]}" -module-name NotificationServiceExtension -emit-executable \
  -Xlinker -e -Xlinker _NSExtensionMain -Xlinker -rpath -Xlinker @executable_path/../../Frameworks "${LINKV[@]}" \
  -o "${APP}/PlugIns/NotificationServiceExtension.appex/NotificationServiceExtension" "${ROOT}"/Extensions/NotificationService/*.swift

echo "==> ldid 嵌入 entitlements（App Group 共享）"
ENT="${BUILD}/entitlements"
cat > "${ENT}.main" <<'ENT'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
	<key>get-task-allow</key><true/>
	<key>com.apple.security.application-groups</key><array><string>group.org.oneapp</string></array>
	<key>com.apple.developer.networking.multicast</key><true/>
	<key>com.apple.developer.networking.networkextension</key>
	<array><string>app-proxy-provider</string><string>content-filter-provider</string></array>
</dict></plist>
ENT
cp "${ENT}.main" "${ENT}.ext"
"$LDID" -S"${ENT}.main" "${APP}/OneApp"
"$LDID" -S"${ENT}.ext"  "${APP}/PlugIns/ShareExtension.appex/ShareExtension"
"$LDID" -S"${ENT}.ext"  "${APP}/PlugIns/NotificationServiceExtension.appex/NotificationServiceExtension"
echo "  ✓ 3 个可执行文件已写入授权"

echo "==> [4/4] 组装 Bundle"
subst OneApp "${BUNDLE_ID}" "${ROOT}/OneApp/Info.plist" > "${APP}/Info.plist"
subst ShareExtension org.oneapp.OneApp.ShareExtension "${ROOT}/Extensions/ShareExtension/Info.plist" > "${APP}/PlugIns/ShareExtension.appex/Info.plist"
subst NotificationServiceExtension org.oneapp.OneApp.NotificationServiceExtension "${ROOT}/Extensions/NotificationService/Info.plist" > "${APP}/PlugIns/NotificationServiceExtension.appex/Info.plist"
printf 'APPL????' > "${APP}/PkgInfo"

# 补齐 installd 校验所需标准键
python3 - "${DEPLOY}" "${SDK_VER}" "${APP}/Info.plist" "${APP}/PlugIns/ShareExtension.appex/Info.plist" "${APP}/PlugIns/NotificationServiceExtension.appex/Info.plist" <<'PY'
import sys, plistlib
minos, sdkver = sys.argv[1], sys.argv[2]
std = {
    "MinimumOSVersion": minos,
    "CFBundleSupportedPlatforms": ["iPhoneOS"],
    "DTPlatformName": "iphoneos",
    "DTPlatformVersion": sdkver,
    "DTSDKName": f"iphoneos{sdkver}",
    "DTCompiler": "com.apple.compilers.llvm.clang.1_0",
}
for path in sys.argv[3:]:
    with open(path, "rb") as f: pl = plistlib.load(f)
    for k, v in std.items(): pl.setdefault(k, v)
    with open(path, "wb") as f: plistlib.dump(pl, f, fmt=plistlib.FMT_XML)
print("  ✓ 补齐标准键")
PY

# 生成散件图标
python3 - "${APP}" <<'PY'
import sys
from PIL import Image, ImageDraw
app = sys.argv[1]
S = 1024
top, bot = (16, 26, 60), (64, 160, 255)
im = Image.new("RGB", (S, S), "#0B1026")
d = ImageDraw.Draw(im)
for y in range(S):
    t = y / S
    r = int(top[0]+(bot[0]-top[0])*t); g = int(top[1]+(bot[1]-top[1])*t); b = int(top[2]+(bot[2]-top[2])*t)
    d.line([(0, y), (S, y)], fill=(r, g, b))
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, S, S], radius=224, fill=255)
d.ellipse([236, 236, 788, 788], outline=(255, 255, 255), width=72)
d.ellipse([360, 360, 664, 664], outline=(16, 26, 60), width=44)
out = Image.new("RGBA", (S, S), (0, 0, 0, 0)); out.paste(im, (0, 0), mask); out = out.convert("RGB")
specs = [("Icon-20","@2x",40),("Icon-29","@2x",58),("Icon-29","@3x",87),("Icon-40","@2x",80),
("Icon-40","@3x",120),("Icon-60","@2x",120),("Icon-60","@3x",180),("Icon-76~ipad","",76),
("Icon-76@2x~ipad","",152),("Icon-83.5@2x~ipad","",167),("Icon-1024","",1024)]
for base, suf, size in specs:
    out.resize((size, size), Image.LANCZOS).save(f"{app}/{base}{suf}.png", "PNG", optimize=True)
print("  ✓ 图标生成")
PY

# Mach-O 校验
python3 - "${APP}" <<'PY'
import struct, sys, os
app = sys.argv[1]
for exe in ["OneApp", "ShareExtension", "NotificationServiceExtension"]:
    p = os.path.join(app, "PlugIns/" + exe + ".appex/" + exe) if exe != "OneApp" else os.path.join(app, exe)
    d = open(p, "rb").read()
    magic, cput, sub, ft, n = struct.unpack('<IiiII', d[:20])
    assert magic == 0xfeedfacf and cput == 0x0100000c, f"{exe} 非 arm64"
    assert ft == 2, f"{exe} filetype={ft}，期望 MH_EXECUTE(2)"
    off = 32; plat = None; sig = None
    for _ in range(n):
        cmd, cs = struct.unpack('<II', d[off:off+8])
        if cmd == 0x32: plat = struct.unpack('<I', d[off+8:off+12])[0]
        if cmd == 0x1d: sig = struct.unpack('<II', d[off+8:off+16])
        off += cs
    assert plat == 2, f"{exe} 平台非 iOS"
    assert sig and sig[1] > 0, f"{exe} 缺少 LC_CODE_SIGNATURE"
    print(f"  ✓ {exe} arm64/iOS/MH_EXECUTE + 签名槽({sig[1]}B)")
PY

# 规范化打包裸 IPA
echo "==> 规范化打包 IPA"
rm -f "$OUT_IPA"
python3 - "$BUILD" "$OUT_IPA" <<'PY'
import sys, os, zipfile
build, out = sys.argv[1], sys.argv[2]
root = os.path.join(build, "Payload")
exec_names = {"OneApp", "ShareExtension", "NotificationServiceExtension"}
fixed = (2024, 1, 1, 0, 0, 0)
def add_dir(zf, arc):
    zi = zipfile.ZipInfo(arc + "/", fixed); zi.create_system = 3
    zi.external_attr = (0o40755 << 16) | 0o040000
    zi.compress_type = zipfile.ZIP_STORED; zf.writestr(zi, b"")
entries = []
for dirpath, dirnames, filenames in os.walk(root):
    dirnames.sort(); filenames.sort()
    rel = os.path.relpath(dirpath, build)
    if rel != ".": entries.append(("dir", rel, None))
    for fn in filenames:
        full = os.path.join(dirpath, fn)
        entries.append(("file", os.path.relpath(full, build), full))
entries.sort(key=lambda e: (e[1].count("/"), e[1]))
with zipfile.ZipFile(out, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9, allowZip64=False) as zf:
    seen = set()
    for kind, arc, full in entries:
        parts = arc.split("/")[:-1]
        for i in range(len(parts)):
            d = "/".join(parts[:i+1])
            if d not in seen: add_dir(zf, d); seen.add(d)
        if kind == "dir":
            if arc not in seen: add_dir(zf, arc); seen.add(arc)
            continue
        zi = zipfile.ZipInfo(arc, fixed); zi.create_system = 3
        base = os.path.basename(arc)
        mode = 0o755 if base in exec_names else 0o644
        zi.external_attr = (mode << 16) | 0o100000
        zi.compress_type = zipfile.ZIP_DEFLATED
        with open(full, "rb") as f: zf.writestr(zi, f.read(), compress_type=zipfile.ZIP_DEFLATED)
with zipfile.ZipFile(out) as z:
    bad = z.testzip(); assert bad is None, f"坏条目 {bad}"
    n = len(z.namelist())
raw = open(out, "rb").read()
assert raw.rfind(b"PK\x05\x06") == len(raw) - 22, "EOCD 不在末尾"
assert b"PK\x06\x06" not in raw, "不应含 zip64"
print(f"  规范化 zip：{n} 条目，EOCD 末尾，无 zip64")
PY
echo "✅ 完成: ${OUT_IPA}"
ls -lh "$OUT_IPA"
shasum -a 256 "$OUT_IPA" | awk '{print "SHA256:",$1}'
