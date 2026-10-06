//! 会议室运行循环（bin 与 iOS FFI 共用）。
use std::error::Error;
use std::time::Duration;

use futures::StreamExt;
use libp2p::swarm::SwarmEvent;
use libp2p::{gossipsub, mdns, noise, tcp, yamux, SwarmBuilder};

use crate::{gossipsub_config, MeetingBehaviour, MeetingBehaviourEvent};

/// 加入一个去中心化会议室：mDNS 自动发现、Noise 加密连接、gossipsub 广播/接收信令。
/// 全程无中央服务器。事件通过 `on_event(line)` 回传。
pub async fn run_room<F>(
    room: String,
    nick: String,
    mut on_event: F,
) -> Result<(), Box<dyn Error + Send + Sync>>
where
    F: FnMut(&str),
{
    let topic = gossipsub::IdentTopic::new(room.clone());

    let mut swarm = SwarmBuilder::with_new_identity()
        .with_tokio()
        .with_tcp(tcp::Config::default(), noise::Config::new, yamux::Config::default)?
        .with_behaviour(|key| {
            let mut gossipsub = gossipsub::Behaviour::new(
                gossipsub::MessageAuthenticity::Signed(key.clone()),
                gossipsub_config(),
            )?;
            gossipsub.subscribe(&topic)?;
            let mdns = mdns::tokio::Behaviour::new(
                mdns::Config::default(),
                key.public().to_peer_id(),
            )?;
            Ok(MeetingBehaviour { gossipsub, mdns })
        })?
        .with_swarm_config(|c| c.with_idle_connection_timeout(Duration::from_secs(60)))
        .build();

    swarm.listen_on("/ip4/0.0.0.0/tcp/0".parse()?)?;

    on_event(&format!(
        "房间[{}] 昵称[{}] 已加入，本机 PeerId = {}",
        room, nick,
        swarm.local_peer_id()
    ));

    let presence = serde_json::json!({ "type": "presence", "nick": nick });
    let mut tick = tokio::time::interval(Duration::from_secs(5));
    tick.tick().await;

    loop {
        tokio::select! {
            event = swarm.select_next_some() => match event {
                SwarmEvent::Behaviour(MeetingBehaviourEvent::Mdns(mdns::Event::Discovered(list))) => {
                    for (peer, addr) in list {
                        on_event(&format!("发现节点: {} @ {}", peer, addr));
                        swarm.add_peer_address(peer, addr.clone());
                        let _ = swarm.dial(addr);
                    }
                }
                SwarmEvent::Behaviour(MeetingBehaviourEvent::Mdns(mdns::Event::Expired(_))) => {}
                SwarmEvent::Behaviour(MeetingBehaviourEvent::Gossipsub(gossipsub::Event::Message {
                    message, ..
                })) => {
                    if let Ok(text) = String::from_utf8(message.data) {
                        on_event(&format!("收到信令: {}", text));
                    }
                }
                SwarmEvent::ConnectionEstablished { peer_id, .. } => {
                    on_event(&format!("加密连接已建立: {}", peer_id));
                }
                _ => {}
            },
            _ = tick.tick() => {
                let _ = swarm
                    .behaviour_mut()
                    .gossipsub
                    .publish(topic.clone(), presence.to_string().as_bytes());
            }
        }
    }
}
