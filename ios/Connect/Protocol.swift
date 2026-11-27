import Foundation

struct AttachReq: Codable { let cmd: String; let pid: Int32; let module: String }

struct Frame {
    static func encode<T: Encodable>(_ v: T) throws -> Data {
        let body = try JSONEncoder().encode(v)
        var len = UInt32(body.count).bigEndian
        return Data(bytes: &len, count: 4) + body
    }
    static func decode(_ d: Data) -> (Data, Int)? {
        guard d.count >= 4 else { return nil }
        let n = d.prefix(4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        guard d.count >= 4 + Int(n) else { return nil }
        return (d.subdata(in: 4..<(4+Int(n))), Int(n)+4)
    }
}
