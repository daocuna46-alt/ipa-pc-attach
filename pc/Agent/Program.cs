using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;

class Agent {
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

    static void Main() {
        var listener = new System.Net.Sockets.TcpListener(System.Net.IPAddress.Any, 9000);
        listener.Start();
        Console.WriteLine("agent up");
        while (true) {
            var c = listener.AcceptTcpClient();
            var s = c.GetStream();
            var hdr = new byte[4]; s.Read(hdr, 0, 4);
            var n = BitConverter.ToInt32(hdr, 0);
            var body = new byte[n]; s.Read(body, 0, n);
            var json = Encoding.UTF8.GetString(body);
            if (json.Contains("\"attach\"")) {
                var pid = int.Parse(Regex.Match(json, "\"pid\":(\\d+)").Groups[1].Value);
                var mod = Regex.Match(json, "\"module\":\"([^\"]+)\"").Groups[1].Value;
                Attach(pid, mod);
            }
        }
    }
}
