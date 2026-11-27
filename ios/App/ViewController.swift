import UIKit
import UniformTypeIdentifiers

class ViewController: UIViewController, UIDocumentPickerDelegate {
    let hostField = UITextField()
    let portField = UITextField()
    let pidField = UITextField()
    let moduleField = UITextField()
    let runPathField = UITextField()
    let statusLabel = UILabel()
    let link = HostLink()
    var pickedURL: URL?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.1, alpha: 1)
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -20),
            stack.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -40)
        ])

        let title = UILabel()
        title.text = "pc link"
        title.font = .systemFont(ofSize: 28, weight: .bold)
        title.textColor = .white
        stack.addArrangedSubview(title)

        func field(_ f: UITextField, _ ph: String) {
            f.placeholder = ph
            f.backgroundColor = UIColor(white: 1, alpha: 0.08)
            f.textColor = .white
            f.layer.cornerRadius = 10
            f.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
            f.leftViewMode = .always
            f.heightAnchor.constraint(equalToConstant: 44).isActive = true
        }
        field(hostField, "host ip")
        field(portField, "port")
        field(pidField, "target pid")
        field(moduleField, "module path on pc")
        field(runPathField, "run path on pc")
        hostField.text = "192.168.1.10"
        portField.text = "9000"

        for f in [hostField, portField, pidField, moduleField, runPathField] { stack.addArrangedSubview(f) }

        stack.addArrangedSubview(makeBtn("connect", #selector(connect)))
        stack.addArrangedSubview(makeBtn("attach module", #selector(attach)))
        stack.addArrangedSubview(makeBtn("pick file", #selector(pickFile)))
        stack.addArrangedSubview(makeBtn("upload file", #selector(upload)))
        stack.addArrangedSubview(makeBtn("run file", #selector(runFile)))

        statusLabel.textColor = .lightGray
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.numberOfLines = 0
        stack.addArrangedSubview(statusLabel)
    }

    func makeBtn(_ t: String, _ a: Selector) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(t, for: .normal)
        b.backgroundColor = UIColor(red: 0.2, green: 0.5, blue: 1, alpha: 1)
        b.setTitleColor(.white, for: .normal)
        b.layer.cornerRadius = 10
        b.heightAnchor.constraint(equalToConstant: 46).isActive = true
        b.addTarget(self, action: a, for: .touchUpInside)
        return b
    }

    @objc func connect() {
        link.open(host: hostField.text ?? "", port: UInt16(portField.text ?? "9000") ?? 9000)
        statusLabel.text = "connecting..."
    }
    @objc func attach() {
        guard let p = Int32(pidField.text ?? "") else { statusLabel.text = "bad pid"; return }
        let req = AttachReq(cmd: "attach", pid: p, module: moduleField.text ?? "")
        if let f = try? Frame.encode(req) { link.send(f); statusLabel.text = "attach sent" }
    }
    @objc func pickFile() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.data], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        pickedURL = urls.first
        statusLabel.text = "picked: \(urls.first?.lastPathComponent ?? "")"
    }
    @objc func upload() {
        guard let url = pickedURL, let data = try? Data(contentsOf: url) else { statusLabel.text = "pick file first"; return }
        link.sendFile(name: url.lastPathComponent, data: data)
        statusLabel.text = "uploading \(url.lastPathComponent) (\(data.count) bytes)"
    }
    @objc func runFile() {
        let req = RunReq(cmd: "run", path: runPathField.text ?? "")
        if let f = try? Frame.encode(req) { link.send(f); statusLabel.text = "run sent" }
    }
}
