import UIKit

// 融合去中心化会议信令核心（oneapp/meeting-core → liboneapp_meeting_core.a）的 C ABI 桥接
@_silgen_name("oneapp_meeting_start")
private func oneapp_meeting_start(
    _ room: UnsafePointer<CChar>,
    _ nick: UnsafePointer<CChar>,
    _ cb: @convention(c) (UnsafePointer<CChar>) -> Void
) -> Int32

@_silgen_name("oneapp_meeting_version")
private func oneapp_meeting_version() -> UnsafeMutablePointer<CChar>

@_silgen_name("oneapp_meeting_str_free")
private func oneapp_meeting_str_free(_ ptr: UnsafeMutablePointer<CChar>)

/// C 回调入口：把核心事件转发到共享日志（@_cdecl 生成 C 可调用符号）。
@_cdecl("oneapp_meeting_log_cb")
private func oneapp_meeting_log_cb(_ ptr: UnsafePointer<CChar>) {
    let line = String(cString: ptr)
    DispatchQueue.main.async { MeetingLog.shared.append(line) }
}

/// 会议日志（线程安全的单例）。
final class MeetingLog {
    static let shared = MeetingLog()
    private(set) var text = ""
    var onAppend: ((String) -> Void)?

    func append(_ line: String) {
        text += line + "\n"
        onAppend?(line)
    }
    func reset() {
        text = ""
    }
}

/// 去中心化会议：无中央服务器，mDNS 自动发现 + Noise 加密 + gossipsub 信令。
final class P2PMeetingViewController: UIViewController, UITextFieldDelegate {

    private let roomField = UITextField()
    private let nickField = UITextField()
    private let startButton = UIButton(type: .system)
    private let logView = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "去中心化会议"
        setupUI()

        let vPtr = oneapp_meeting_version()
        let version = String(cString: vPtr)
        oneapp_meeting_str_free(vPtr)
        logView.text = "OneApp 去中心化会议信令 v\(version)\n无中央服务器 · 局域网零配置 · 端到端加密\n\n"
        MeetingLog.shared.reset()
        MeetingLog.shared.onAppend = { [weak self] line in
            self?.logView.text += line + "\n"
            self?.scrollToBottom()
        }
    }

    private func setupUI() {
        roomField.placeholder = "房间名"
        roomField.text = "oneapp"
        roomField.borderStyle = .roundedRect
        roomField.delegate = self
        nickField.placeholder = "昵称"
        nickField.text = "guest"
        nickField.borderStyle = .roundedRect
        nickField.delegate = self
        startButton.setTitle("加入会议室（无服务器）", for: .normal)
        startButton.addTarget(self, action: #selector(start), for: .touchUpInside)
        logView.isEditable = false
        logView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        logView.backgroundColor = UIColor(white: 0.96, alpha: 1)

        for v in [roomField, nickField, startButton, logView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
        }
        NSLayoutConstraint.activate([
            roomField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            roomField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            roomField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            nickField.topAnchor.constraint(equalTo: roomField.bottomAnchor, constant: 10),
            nickField.leadingAnchor.constraint(equalTo: roomField.leadingAnchor),
            nickField.trailingAnchor.constraint(equalTo: roomField.trailingAnchor),
            startButton.topAnchor.constraint(equalTo: nickField.bottomAnchor, constant: 16),
            startButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logView.topAnchor.constraint(equalTo: startButton.bottomAnchor, constant: 16),
            logView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            logView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            logView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])
    }

    @objc private func start() {
        view.endEditing(true)
        let room = roomField.text ?? "oneapp"
        let nick = nickField.text ?? "guest"
        room.withCString { r in
            nick.withCString { n in
                let rc = oneapp_meeting_start(r, n, oneapp_meeting_log_cb)
                if rc != 0 {
                    logView.text += "启动失败（\(rc)）\n"
                }
            }
        }
    }

    private func scrollToBottom() {
        let end = NSRange(location: logView.text.count, length: 0)
        logView.scrollRangeToVisible(end)
    }
}
