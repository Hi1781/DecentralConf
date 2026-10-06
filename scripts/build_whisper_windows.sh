#!/bin/bash
# 用 Linux 原生 clang + lld + winlibs sysroot 交叉编译 whisper.cpp 官方 whisper-cli → Windows EXE
set -e
WHISPER=/home/user/Doubao/chats/38445459905317378/vendors/whisper.cpp
SW=/home/user/.doubao/agent_mode/workspace/toolchain/swift-5.8-RELEASE-ubuntu22.04/usr
M=/home/user/Doubao/chats/38445459905317378/mingw/mingw64
OUT=/home/user/Doubao/chats/38445459905317378/oneapp/windows
CXX="$SW/bin/clang++"; CC="$SW/bin/clang"
mkdir -p "$OUT/obj"
BASE=(--target=x86_64-w64-windows-gnu --sysroot="$M" -O2 -Iggml/include -Iinclude -Isrc -Iggml/src -Iggml/src/ggml-cpu -pthread -DWHISPER_VERSION=\""1.9.4\"")
cd "$WHISPER"
echo "== whisper.cpp / aneforge =="
"$CXX" "${BASE[@]}" -c src/whisper.cpp -o "$OUT/obj/whisper.o"
"$CXX" "${BASE[@]}" -c src/aneforge/whisper-aneforge.cpp -o "$OUT/obj/whisper-aneforge.o"
echo "== ggml 核心(C) =="
for f in ggml.c ggml-quants.c ggml-alloc.c; do
  "$CC" "${BASE[@]}" -x c -c "ggml/src/$f" -o "$OUT/obj/${f%.c}.o"
done
echo "== ggml 核心(C++) =="
for f in ggml-backend.cpp ggml-backend-dl.cpp ggml-backend-meta.cpp ggml-backend-reg.cpp ggml-threading.cpp gguf.cpp ggml-opt.cpp; do
  "$CXX" "${BASE[@]}" -c "ggml/src/$f" -o "$OUT/obj/${f%.cpp}.o"
done
echo "== ggml-cpu(C) =="
for f in ggml-cpu.c quants.c; do
  "$CC" "${BASE[@]}" -x c -c "ggml/src/ggml-cpu/$f" -o "$OUT/obj/${f%.c}.o"
done
echo "== ggml-cpu(C++) =="
for f in ggml-cpu.cpp binary-ops.cpp unary-ops.cpp ops.cpp vec.cpp iqp.cpp repack.cpp traits.cpp hbm.cpp; do
  "$CXX" "${BASE[@]}" -c "ggml/src/ggml-cpu/$f" -o "$OUT/obj/${f%.cpp}.o"
done
echo "== 链接 whisper-cli.exe (lld) =="
"$CXX" "${BASE[@]}" -fuse-ld=lld -o "$OUT/whisper-cli.exe" \
  examples/whisper/cli.cpp "$OUT"/obj/*.o \
  -static-libgcc -static-libstdc++ -lwinpthread
echo "✅ 完成"; ls -lh "$OUT/whisper-cli.exe" | awk '{print $5, $NF}'; file "$OUT/whisper-cli.exe"
