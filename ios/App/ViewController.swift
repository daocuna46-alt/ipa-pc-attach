import UIKit

class ViewController: UIViewController {
    let hostField = UITextField()
    let portField = UITextField()
    let pidField = UITextField()
    let moduleField = UITextField()
    let link = HostLink()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        for (f, ph) in [(hostField,"host"),(portField,"port"),(pidField,"target pid"),(moduleField,"module path")] {
            f.placeholder = ph
            f.borderStyle = .roundedRect
            stack.addArrangedSubview(f)
        }
        hostField.text = "192.168.1.10"
        portField.text = "9000"
        let connBtn = UIButton(type: .system)
        connBtn.setTitle("connect", for: .normal)
        connBtn.addTarget(self, action: #selector(connect), for: .touchUpInside)
        stack.addArrangedSubview(connBtn)
        let attachBtn = UIButton(type: .system)
        attachBtn.setTitle("attach", for: .normal)
        attachBtn.addTarget(self, action: #selector(attach), for: .touchUpInside)
        stack.addArrangedSubview(attachBtn)
    }
    @objc func connect() {
        link.open(host: hostField.text ?? "", port: UInt16(portField.text ?? "9000") ?? 9000)
    }
    @objc func attach() {
        guard let p = Int32(pidField.text ?? "") else { return }
        let req = AttachReq(cmd: "attach", pid: p, module: moduleField.text ?? "")
        if let f = try? Frame.encode(req) { link.send(f) }
    }
}
