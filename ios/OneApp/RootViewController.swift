import UIKit

/// 第一版 MVP：四个入口模块（Messaging / Meeting / FileTransfer / Cast 预留）
final class Modules {
    static let all: [Module] = [
        Module(title: "去中心化会议", subtitle: "P2P 无服务器 · Noise 加密 · 已融合 libp2p", symbol: "point.3.connected.trianglepath.dotted"),
        Module(title: "私密通讯", subtitle: "Session 基座（后续并入真代码）", symbol: "message.fill"),
        Module(title: "视频会议", subtitle: "已融合 Jitsi 会议客户端（需服务器，过渡方案）", symbol: "video.fill"),
        Module(title: "局域网传文件", subtitle: "已融合 LocalSend Rust 核心", symbol: "arrow.up.arrow.down"),
        Module(title: "AI 转写", subtitle: "已融合 whisper.cpp 核心", symbol: "waveform"),
        Module(title: "投屏（预留）", subtitle: "ReplayKit + 开源投屏协议", symbol: "display"),
    ]
}

struct Module {
    let title: String
    let subtitle: String
    let symbol: String
}

final class RootViewController: UITableViewController {

    private let modules: [Module]

    init(modules: [Module]) {
        self.modules = modules
        super.init(style: .insetGrouped)
        title = "OneApp 第一版"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        modules.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let m = modules[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.textLabel?.text = m.title
        cell.detailTextLabel?.text = m.subtitle
        cell.imageView?.image = UIImage(systemName: m.symbol)
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let t = modules[indexPath.row].title
        switch t {
        case "去中心化会议":
            navigationController?.pushViewController(P2PMeetingViewController(), animated: true)
        case "局域网传文件":
            navigationController?.pushViewController(FileTransferViewController(), animated: true)
        case "AI 转写":
            navigationController?.pushViewController(TranscriptionViewController(), animated: true)
        case "视频会议":
            navigationController?.pushViewController(MeetingViewController(), animated: true)
        default:
            break
        }
    }
}
