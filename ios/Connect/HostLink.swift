import Foundation
import Network

final class HostLink {
    private var conn: NWConnection?
    var onMessage: ((Data) -> Void)?
    func open(host: String, port: UInt16) {
        let ep = NWEndpoint.hostPort(host: .name(host, nil), port: .init(rawValue: port)!)
        conn = NWConnection(to: ep, using: .tcp)
        conn?.stateUpdateHandler = { [weak self] s in
            if case .ready = s { self?.recv() }
        }
        conn?.start(queue: .global())
    }
    func send(_ d: Data) { conn?.send(content: d, completion: .contentProcessed { _ in }) }
    private func recv() {
        conn?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, _ in
            if let data { self?.onMessage?(data) }
            self?.recv()
        }
    }
}
