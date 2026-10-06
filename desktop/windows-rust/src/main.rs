//! OneApp Windows 版 —— 传文件模块（复用 LocalSend 官方核心）。
//! 用法: oneapp [文件1 文件2 ...]   用融合的 LocalSend 核心计算文件 SHA-256。
use std::env;
use std::fs;
use std::process;

use localsend::crypto::hash::sha256_hex;

const VERSION: &str = "0.4.0 (fused localsend-core)";

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();

    println!("OneApp Windows 传文件核心工具 v{}", VERSION);
    println!("核心来源: vendored localsend/packages/core (open-source, 学习研究用途, 禁止商用)");
    println!();

    if args.is_empty() {
        println!("自检: sha256(\"OneApp windows self-test\") =");
        let hex = sha256_hex(b"OneApp windows self-test");
        println!("  {}", hex);
        println!();
        println!("用法: oneapp <文件路径...>   计算文件的 SHA-256 校验和（与 LocalSend 传输校验一致）");
        return;
    }

    let mut any_error = false;
    for path in &args {
        match fs::read(path) {
            Ok(data) => {
                let hex = sha256_hex(&data);
                println!("{}  {}", hex, path);
            }
            Err(e) => {
                eprintln!("错误: 无法读取 {}: {}", path, e);
                any_error = true;
            }
        }
    }
    if any_error {
        process::exit(1);
    }
}
