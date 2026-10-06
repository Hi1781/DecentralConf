//! OneApp 去中心化会议信令（命令行版）。
//! 用法: oneapp-meeting [房间名] [昵称]
use oneapp_meeting_core::run_room;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = std::env::args().collect();
    let room = args.get(1).cloned().unwrap_or_else(|| "oneapp".to_string());
    let nick = args.get(2).cloned().unwrap_or_else(|| "guest".to_string());

    println!("OneApp 去中心化会议信令 v{}", oneapp_meeting_core::VERSION);
    println!("局域网零配置 · 无中央服务器 · 等待同房间节点...");

    if let Err(e) = run_room(room, nick, |line| println!("{}", line)).await {
        eprintln!("错误: {}", e);
        std::process::exit(1);
    }
    Ok(())
}
