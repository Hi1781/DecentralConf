//! OneApp 去中心化会议信令核心（libp2p）。
//! 完全点对点：mDNS 局域网自动发现 + Noise 加密 + gossipsub 房间广播。
//! 不依赖任何中央服务器。
use libp2p::{gossipsub, mdns, swarm::NetworkBehaviour};

pub mod ffi;
pub mod room;

pub use room::run_room;

/// 会议网络行为：房间广播 + 局域网发现。
#[derive(NetworkBehaviour)]
pub struct MeetingBehaviour {
    pub gossipsub: gossipsub::Behaviour,
    pub mdns: mdns::tokio::Behaviour,
}

/// 构建 gossipsub 配置（放大单帧上限以容纳 WebRTC SDP）。
pub fn gossipsub_config() -> gossipsub::Config {
    gossipsub::ConfigBuilder::default()
        .max_transmit_size(65536)
        .validation_mode(gossipsub::ValidationMode::Strict)
        .build()
        .expect("valid gossipsub config")
}

pub const VERSION: &str = "0.5.0";
