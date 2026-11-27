import SwiftUI

struct AttachView: View {
    @State private var host = "192.168.1.10"
    @State private var port = "9000"
    @State private var pid = ""
    @State private var module = ""
    private let link = HostLink()
    var body: some View {
        Form {
            TextField("host", text: $host)
            TextField("port", text: $port)
            TextField("target pid", text: $pid)
            TextField("module path", text: $module)
            Button("connect") { link.open(host: host, port: UInt16(port) ?? 9000) }
            Button("attach") {
                guard let p = Int32(pid) else { return }
                let req = AttachReq(cmd: "attach", pid: p, module: module)
                if let f = try? Frame.encode(req) { link.send(f) }
            }
        }
    }
}
