import Darwin
import Foundation

/// Liest Prozess-Infos direkt aus dem Kernel, ganz ohne Shell-Integration.
enum ProcInfo {
    /// Aktuelles Arbeitsverzeichnis eines Prozesses.
    static func cwd(of pid: pid_t) -> String? {
        guard pid > 0 else { return nil }
        var info = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        let r = proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, size)
        guard r == size else { return nil }
        let path = withUnsafeBytes(of: &info.pvi_cdir.vip_path) { raw -> String in
            let buf = raw.bindMemory(to: CChar.self)
            return String(cString: buf.baseAddress!)
        }
        return path.isEmpty ? nil : path
    }

    /// Prozessgruppe, die gerade im Vordergrund des PTY läuft.
    static func foregroundGroup(fd: Int32) -> pid_t? {
        guard fd >= 0 else { return nil }
        let p = tcgetpgrp(fd)
        return p > 0 ? p : nil
    }

    static func name(of pid: pid_t) -> String {
        var buf = [CChar](repeating: 0, count: 256)
        let n = proc_name(pid, &buf, UInt32(buf.count))
        guard n > 0 else { return "" }
        return String(cString: buf)
    }

    static var userShell: String {
        if let pw = getpwuid(getuid()), let sh = pw.pointee.pw_shell {
            let s = String(cString: sh)
            if !s.isEmpty { return s }
        }
        return "/bin/zsh"
    }
}
