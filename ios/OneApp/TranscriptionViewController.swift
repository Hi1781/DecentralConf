import UIKit

// 融合 whisper.cpp 官方 C API（vendors/whisper.cpp → libwhisper.a）
@_silgen_name("whisper_print_system_info")
private func whisper_print_system_info() -> UnsafePointer<CChar>

/// AI 转写模块：调用已融合的 whisper.cpp 真实构建信息（模型推理需加载模型文件，此处展示核心自检）。
final class TranscriptionViewController: UIViewController {

    private let infoLabel = UILabel()
    private let statusLabel = UILabel()
    private let button = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "AI 转写"
        setupUI()
        refresh()
    }

    private func setupUI() {
        infoLabel.numberOfLines = 0
        infoLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        statusLabel.numberOfLines = 0
        button.setTitle("重新读取核心信息", for: .normal)
        button.addTarget(self, action: #selector(refresh), for: .touchUpInside)
        for v in [infoLabel, statusLabel, button] {
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
        }
        NSLayoutConstraint.activate([
            infoLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            infoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            infoLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            statusLabel.topAnchor.constraint(equalTo: infoLabel.bottomAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            button.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 28),
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    @objc private func refresh() {
        // 真实调用 whisper.cpp 的 whisper_print_system_info()
        let s = String(cString: whisper_print_system_info())
        infoLabel.text = s
        statusLabel.text = "已融合 whisper.cpp 核心。完整转写需在 App 内加载 ggml 模型文件后调用 whisper_full()。"
    }
}
