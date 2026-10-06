import UIKit

// 融合 LocalSend 官方 Rust 核心（oneapp/rust-core → liboneapp_core.a）的 C ABI 桥接
@_silgen_name("oneapp_core_version")
private func oneapp_core_version() -> UnsafeMutablePointer<CChar>

@_silgen_name("oneapp_sha256_hex")
private func oneapp_sha256_hex(_ ptr: UnsafePointer<UInt8>, _ len: Int) -> UnsafeMutablePointer<CChar>

@_silgen_name("oneapp_str_free")
private func oneapp_str_free(_ ptr: UnsafeMutablePointer<CChar>)

/// 局域网传文件模块：展示已融合的 LocalSend 核心，并调用其真实 sha256 能力自检。
final class FileTransferViewController: UIViewController {

    private let coreVersionLabel = UILabel()
    private let hashLabel = UILabel()
    private let sendButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "局域网传文件"
        setupUI()
        runSelfTest()
    }

    private func setupUI() {
        coreVersionLabel.numberOfLines = 0
        hashLabel.numberOfLines = 0
        hashLabel.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        sendButton.setTitle("调用核心 · SHA256 自检", for: .normal)
        sendButton.addTarget(self, action: #selector(runSelfTest), for: .touchUpInside)
        for v in [coreVersionLabel, hashLabel, sendButton] {
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
        }
        NSLayoutConstraint.activate([
            coreVersionLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            coreVersionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            coreVersionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            hashLabel.topAnchor.constraint(equalTo: coreVersionLabel.bottomAnchor, constant: 20),
            hashLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            hashLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            sendButton.topAnchor.constraint(equalTo: hashLabel.bottomAnchor, constant: 28),
            sendButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    @objc private func runSelfTest() {
        // 1) 版本（来自被融合的 LocalSend 核心）
        let verPtr = oneapp_core_version()
        let version = String(cString: verPtr)
        oneapp_str_free(verPtr)

        // 2) sha256（调用核心真实 crypto::hash::sha256_hex）
        let input = "OneApp fusion self-test: LocalSend core"
        let bytes = Array(input.utf8)
        let hashPtr = bytes.withUnsafeBufferPointer { buf in
            oneapp_sha256_hex(buf.baseAddress!, buf.count)
        }
        let hex = String(cString: hashPtr)
        oneapp_str_free(hashPtr)

        coreVersionLabel.text = "已融合核心：\(version)"
        hashLabel.text = "sha256(\"\(input)\")\n= \(hex)"
    }
}
