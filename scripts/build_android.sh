#!/bin/bash
# 手工构建 OneApp Android APK（不依赖 Gradle/Maven）：aapt2 → javac → d8 → aapt add → zipalign → apksigner
set -e
ROOT=/home/user/Doubao/chats/38445459905317378/oneapp
SDK="/home/user/Doubao/chats/38445459905317378/android-sdk"
BT="$SDK/build-tools/34.0.0"
PLAT="$SDK/platforms/android-34/android.jar"
AND="$ROOT/android"
OUT="$ROOT/build-android"
JAVA_HOME="/home/user/Doubao/chats/38445459905317378/jdk17"
export PATH="$JAVA_HOME/bin:$PATH"

rm -rf "$OUT"; mkdir -p "$OUT/gen" "$OUT/obj"

echo "==> [1/6] aapt2 编译资源"
"$BT/aapt2" compile --dir "$AND/res" -o "$OUT/res.zip"

echo "==> [2/6] aapt2 链接（Manifest+资源 → base APK + R.java）"
"$BT/aapt2" link -o "$OUT/OneApp-base.apk" -I "$PLAT" \
  --manifest "$AND/AndroidManifest.xml" \
  --java "$OUT/gen" -R "$OUT/res.zip" --auto-add-overlay

echo "==> [3/6] javac 编译 Java 源码"
javac -source 8 -target 8 -classpath "$PLAT" -d "$OUT/obj" \
  $(find "$AND/src" "$OUT/gen" -name '*.java')

echo "==> [4/6] d8 → classes.dex"
"$BT/d8" --release --lib "$PLAT" --output "$OUT" $(find "$OUT/obj" -name '*.class')

echo "==> [5/6] 注入 classes.dex + zipalign"
( cd "$OUT" && "$BT/aapt" add "OneApp-base.apk" classes.dex )
"$BT/zipalign" -f 4 "$OUT/OneApp-base.apk" "$OUT/OneApp-aligned.apk"

echo "==> [6/6] 生成密钥并签名"
KS="$OUT/oneapp.keystore"
[ -f "$KS" ] || "$JAVA_HOME/bin/keytool" -genkeypair -keystore "$KS" -alias oneapp \
  -keyalg RSA -keysize 2048 -validity 10000 -storepass oneapp123 -keypass oneapp123 \
  -dname "CN=OneApp, OU=Dev, O=OneApp, L=HZ, C=CN" >/dev/null 2>&1
"$BT/apksigner" sign --ks "$KS" --ks-pass pass:oneapp123 --key-pass pass:oneapp123 \
  --out "$OUT/OneApp.apk" "$OUT/OneApp-aligned.apk"

echo "==> 签名校验"
"$BT/apksigner" verify --print-certs "$OUT/OneApp.apk"
echo "✅ APK: $OUT/OneApp.apk ($(du -h "$OUT/OneApp.apk" | cut -f1))"
