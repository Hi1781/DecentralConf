# DecentralConf

> 去中心化、端到端加密的高速会议与私密通讯系统。界面与功能参考 Microsoft Teams，但**无强制中央服务器**：点对点 Mesh（libp2p / WebRTC）+ 端到端加密，构建于 Session 与 libp2p 之上。

## 项目组成

| 目录 | 平台 | 技术栈 | 说明 |
| --- | --- | --- | --- |
| `android/` | Android | Kotlin + Jetpack Compose + Gradle | 在官方 **session-android** 工程内直接改造（重命名、新图标、个人签名），保留 Session 全部私密通讯能力 |
| `ios/` | iOS | Swift + 自研 Rust 核心 | 会议/传文件/转写界面与 P2P 会议入口（受限于 Linux 无 Xcode，官方 session-ios 需在 macOS 构建） |
| `meeting-core/` | 跨平台 Rust 核心 | libp2p 0.54（Noise + Yamux + gossipsub + mDNS） | 去中心化信令控制面：自动发现、加密连接、无服务器，已在本机双实例验证 |
| `desktop/` | Windows | Rust + 交叉工具链 | 会议信令 / 本地文件传输核心的 Windows 构建 |
| `scripts/` | 构建脚本 | Bash | 三平台构建脚本 |

## 功能矩阵

- 端到端加密的私密文字/语音/群组（继承 Session，洋葱路由 + 去中心化节点网络）
- 去中心化 P2P 会议信令：mDNS 局域网发现、Noise 加密、gossipsub 房间广播、无需服务器
- 本地高速文件传输（LocalSend 协议核心）
- 本地语音转写（whisper.cpp，离线）
- 屏幕共享 / 白板 / 美颜等能力以开源组件方式接入（见文档与第三方组件）
- 个人签名：使用项目自带 keystore 对发布包进行签名（**非**官方 Session 签名）

## 第三方开源依赖（均为各自作者的开源项目，仅做集成，不主张所有权）

- Session（session-android / session-desktop / session-ios）— GPL-3.0
- libp2p-rust — MIT
- LocalSend — Apache-2.0
- whisper.cpp — MIT
- Jitsi Meet、Excalidraw、gpupixel 等 — 见各自 LICENSE

## 构建

详见各目录与 [DISCLAIMER.md](DISCLAIMER.md)。

```bash
# Android（在源码内构建，需 JDK17 + Android SDK compileSdk37）
cd android && ./gradlew assemblePlayRelease

# Rust 会议核心（跨平台）
cd meeting-core && cargo build --release
```

## 免责声明

见 [DISCLAIMER.md](DISCLAIMER.md)。本项目**仅用于学习研究、全面开源、不用于任何商业用途**。
