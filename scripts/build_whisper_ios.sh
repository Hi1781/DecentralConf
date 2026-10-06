#!/bin/bash
# 交叉编译 whisper.cpp(官方) → iOS 静态库 libwhisper.a
set -e
WHISPER=/home/user/Doubao/chats/38445459905317378/vendors/whisper.cpp
SW=/home/user/.doubao/agent_mode/workspace/toolchain/swift-5.8-RELEASE-ubuntu22.04/usr
SDK=/home/user/.doubao/agent_mode/workspace/toolchain/iPhoneOS16.4.sdk
OUT=/home/user/Doubao/chats/38445459905317378/oneapp/whisper-ios
CXX="$SW/bin/clang++"; CC="$SW/bin/clang"
mkdir -p "$OUT/obj"
FL_C=(-target arm64-apple-ios16.0 -isysroot "$SDK" -O2 -Iggml/include -Iinclude -Isrc -Iggml/src -Iggml/src/ggml-cpu)
FL_XX=("${FL_C[@]}" -std=c++17 -DWHISPER_VERSION=\""1.9.4\"")
cd "$WHISPER"
echo "== whisper.cpp =="
"$CXX" "${FL_XX[@]}" -c src/whisper.cpp -o "$OUT/obj/whisper.o"
echo "== ggml 核心 =="
for f in ggml.c ggml-quants.c ggml-alloc.c; do
  "$CC" "${FL_C[@]}" -c "ggml/src/$f" -o "$OUT/obj/${f%.c}.o" 2>&1 | head -5
done
for f in ggml-backend.cpp ggml-backend-dl.cpp ggml-backend-meta.cpp ggml-backend-reg.cpp ggml-threading.cpp gguf.cpp ggml-opt.cpp; do
  "$CXX" "${FL_XX[@]}" -c "ggml/src/$f" -o "$OUT/obj/${f%.cpp}.o" 2>&1 | head -5
done
echo "== aneforge(ANE 编码器后端，运行时 dlopen) =="
"$CXX" "${FL_XX[@]}" -c src/aneforge/whisper-aneforge.cpp -o "$OUT/obj/whisper-aneforge.o" 2>&1 | head -5
echo "== ggml-cpu 后端 =="
"$CC" "${FL_C[@]}" -c ggml/src/ggml-cpu/ggml-cpu.c   -o "$OUT/obj/ggml-cpu.o"
for f in ggml-cpu.cpp binary-ops.cpp unary-ops.cpp ops.cpp quants.c vec.cpp iqp.cpp repack.cpp traits.cpp hbm.cpp; do
  case "$f" in *.cpp) "$CXX" "${FL_XX[@]}" -c "ggml/src/ggml-cpu/$f" -o "$OUT/obj/${f%.cpp}.o";; *.c) "$CC" "${FL_C[@]}" -c "ggml/src/ggml-cpu/$f" -o "$OUT/obj/${f%.c}.o";; esac
done
echo "== 归档 =="
LLVM_AR="${CXX%/clang++}/llvm-ar"; "$LLVM_AR" rcs "$OUT/libwhisper.a" "$OUT"/obj/*.o
echo "✓ libwhisper.a $(du -h "$OUT/libwhisper.a"|cut -f1) ($(ls "$OUT"/obj/*.o | wc -l) 对象)"
