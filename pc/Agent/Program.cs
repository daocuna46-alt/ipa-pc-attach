using System;
using System.Diagnostics;
using System.IO;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using QRCoder;

class Agent {
    static string GetLocalIP() {
        foreach (var ni in System.Net.NetworkInformation.NetworkInterface.GetAllNetworkInterfaces()) {
            if (ni.OperationalStatus != System.Net.NetworkInformation.OperationalStatus.Up) continue;
            foreach (var addr in ni.GetIPProperties().UnicastAddresses) {
                if (addr.Address.AddressFamily == System.Net.Sockets.AddressFamily.InterNetwork) {
                    var ip = addr.Address.ToString();
                    if (!ip.StartsWith("127.")) return ip;
                }
            }
        }
        return "127.0.0.1";
    }
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern IntPtr VirtualAllocEx(IntPtr h, IntPtr addr, uint size, uint type, uint protect);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool WriteProcessMemory(IntPtr h, IntPtr addr, byte[] buf, uint size, out uint written);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern IntPtr CreateRemoteThread(IntPtr h, IntPtr attr, uint stack, IntPtr start, IntPtr param, uint flags, out uint tid);
    [DllImport("kernel32.dll", CharSet = CharSet.Ansi)]
    static extern IntPtr GetProcAddress(IntPtr mod, string name);
    [DllImport("kernel32.dll", CharSet = CharSet.Auto)]
    static extern IntPtr GetModuleHandle(string name);

    const uint ALL = 0x001FFFFF;
    const uint COMMIT_RESERVE = 0x3000;
    const uint RWX = 0x40;

    static void Attach(int pid, string modulePath) {
        var h = OpenProcess(ALL, false, pid);
        if (h == IntPtr.Zero) { Console.WriteLine("open failed"); return; }
        var bytes = Encoding.ASCII.GetBytes(modulePath + "\0");
        var mem = VirtualAllocEx(h, IntPtr.Zero, (uint)bytes.Length, COMMIT_RESERVE, RWX);
        WriteProcessMemory(h, mem, bytes, (uint)bytes.Length, out _);
        var loadLib = GetProcAddress(GetModuleHandle("kernel32.dll"), "LoadLibraryA");
        CreateRemoteThread(h, IntPtr.Zero, 0, loadLib, mem, 0, out _);
        Console.WriteLine("attached");
    }

    static byte[] ReadExact(NetworkStream s, int n) {
        var buf = new byte[n];
        int off = 0;
        while (off < n) {
            int r = s.Read(buf, off, n - off);
            if (r <= 0) throw new IOException("stream closed");
            off += r;
        }
        return buf;
    }

    static int ReadInt32BE(NetworkStream s) {
        var hdr = ReadExact(s, 4);
        return (hdr[0] << 24) | (hdr[1] << 16) | (hdr[2] << 8) | hdr[3];
    }

    static void Main() {
        var uploadDir = Path.Combine(AppContext.BaseDirectory, "uploads");
        Directory.CreateDirectory(uploadDir);
        var hostIp = GetLocalIP();
        var payload = hostIp + ":9000";
        try {
            var gen = new QRCodeGenerator();
            var data = gen.CreateQrCode(payload, QRCodeGenerator.ECCLevel.Q);
            var code = new PngByteQRCode(data);
            var png = code.GetGraphic(20);
            File.WriteAllBytes(Path.Combine(AppContext.BaseDirectory, "connect_qr.png"), png);
            Console.WriteLine("QR saved: connect_qr.png");
        } catch (Exception e) { Console.WriteLine("qr err: " + e.Message); }
        Console.WriteLine("payload: " + payload);
        try {
            var q = new QRCodeGenerator();
            var qd = q.CreateQrCode(payload, QRCodeGenerator.ECCLevel.Q);
            foreach (var row in qd.ModuleMatrix) {
                foreach (var cell in row) Console.Write(cell ? "██" : "  ");
                Console.WriteLine();
            }
        } catch (Exception e) { Console.WriteLine("qr console err: " + e.Message); }
        var listener = new TcpListener(System.Net.IPAddress.Any, 9000);
        listener.Start();
        Console.WriteLine("agent up");
        while (true) {
            var c = listener.AcceptTcpClient();
            var s = c.GetStream();
            try {
                while (c.Connected) {
                    int n = ReadInt32BE(s);
                    var body = ReadExact(s, n);
                    var json = Encoding.UTF8.GetString(body);
                    if (json.Contains("\"attach\"")) {
                        var pid = int.Parse(Regex.Match(json, "\"pid\":(\\d+)").Groups[1].Value);
                        var mod = Regex.Match(json, "\"module\":\"([^\"]+)\"").Groups[1].Value;
                        Attach(pid, mod);
                    } else if (json.Contains("\"upload\"")) {
                        var name = Regex.Match(json, "\"name\":\"([^\"]+)\"").Groups[1].Value;
                        var size = int.Parse(Regex.Match(json, "\"size\":(\\d+)").Groups[1].Value);
                        var data = ReadExact(s, size);
                        var safe = Path.GetFileName(name);
                        var dest = Path.Combine(uploadDir, safe);
                        File.WriteAllBytes(dest, data);
                        Console.WriteLine("uploaded " + dest);
                    } else if (json.Contains("\"run\"")) {
                        var path = Regex.Match(json, "\"path\":\"([^\"]+)\"").Groups[1].Value;
                        Process.Start(new ProcessStartInfo(path) { UseShellExecute = true });
                        Console.WriteLine("ran " + path);
                    }
                }
            } catch (Exception e) {
                Console.WriteLine("client err: " + e.Message);
            }
            c.Close();
        }
    }
}
