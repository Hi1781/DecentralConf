import UIKit
import WebKit

/// 视频会议模块：把开源的 Jitsi Meet 官方客户端（vendors/jitsi-meet，由 Jitsi 服务端提供）嵌入 WKWebView。
/// 会议逻辑全部复用 Jitsi 现成代码（HD 音视频/屏幕共享/聊天/白板/录制），本控制器只做宿主外壳，不自写协议。
final class MeetingViewController: UIViewController, UITextFieldDelegate, WKNavigationDelegate {

    private let serverField = UITextField()
    private let roomField = UITextField()
    private let joinButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private var webView: WKWebView?

    private let defaultServer = "https://meet.jit.si"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "视频会议"
        setupUI()
        roomField.text = "OneApp-\(Int(Date().timeIntervalSince1970))"
    }

    private func setupUI() {
        serverField.placeholder = "Jitsi 服务器地址（默认官方）"
        serverField.text = defaultServer
        serverField.keyboardType = .URL
        serverField.autocorrectionType = .no
        serverField.borderStyle = .roundedRect

        roomField.placeholder = "会议室名称"
        roomField.autocorrectionType = .no
        roomField.borderStyle = .roundedRect

        joinButton.setTitle("加入会议（Jitsi）", for: .normal)
        joinButton.addTarget(self, action: #selector(joinTapped), for: .touchUpInside)

        statusLabel.numberOfLines = 0
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabel
        statusLabel.text = "会议逻辑复用 Jitsi 官方客户端。默认官方服务器；自建服务器请在地址栏填写（如 https://meet.example.com）。HD 音视频、屏幕共享、聊天、白板、录制均由 Jitsi 提供。"

        for v in [serverField, roomField, joinButton, statusLabel] {
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
        }
        NSLayoutConstraint.activate([
            serverField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            serverField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            serverField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            roomField.topAnchor.constraint(equalTo: serverField.bottomAnchor, constant: 10),
            roomField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            roomField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            joinButton.topAnchor.constraint(equalTo: roomField.bottomAnchor, constant: 14),
            joinButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: joinButton.bottomAnchor, constant: 10),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])
    }

    @objc private func joinTapped() {
        view.endEditing(true)
        let server = (serverField.text ?? "").trimmingCharacters(in: .whitespaces)
        let room = (roomField.text ?? "").trimmingCharacters(in: .whitespaces)
        guard !room.isEmpty else { statusLabel.text = "请填写会议室名称。"; return }
        let base = server.isEmpty ? defaultServer : server
        guard let url = URL(string: "\(base)/\(room)") else { statusLabel.text = "服务器地址无效。"; return }
        statusLabel.text = "正在加入：\(url.absoluteString)（Jitsi 官方客户端加载中…）"
        loadJitsi(url)
    }

    private func loadJitsi(_ url: URL) {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let wv = WKWebView(frame: view.bounds, configuration: config)
        wv.translatesAutoresizingMaskIntoConstraints = false
        wv.navigationDelegate = self
        view.addSubview(wv)
        NSLayoutConstraint.activate([
            wv.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0),
            wv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            wv.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        webView = wv
        wv.load(URLRequest(url: url))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        statusLabel.text = "Jitsi 客户端已加载（会议进行中）。"
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        statusLabel.text = "加载失败：\(error.localizedDescription)。请检查网络或服务器地址。"
    }
}
