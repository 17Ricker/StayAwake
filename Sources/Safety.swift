import Foundation
import IOKit.ps

// MARK: - Batteria

enum Battery {
    static let threshold = 20

    /// Percentuale di carica. `Current Capacity` è in percentuale solo se `Max Capacity` vale 100:
    /// su alcuni Mac sono mAh, quindi si divide sempre.
    static func percent(current: Int, max: Int) -> Int {
        guard max > 0 else { return current }
        return Int((Double(current) / Double(max) * 100).rounded())
    }

    /// Vero solo se il Mac è alimentato a batteria e la carica è sotto soglia.
    static func isLow() -> Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return false }
        if let type = IOPSGetProvidingPowerSourceType(info)?.takeRetainedValue() as String?, type == "AC Power" {
            return false
        }
        for source in list {
            guard let d = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  let current = d["Current Capacity"] as? Int else { continue }
            let max = d["Max Capacity"] as? Int ?? 100
            if percent(current: current, max: max) < threshold { return true }
        }
        return false
    }
}

// MARK: - Temperatura

enum Thermal {
    /// Si ferma solo a «critico»: «serio» capita anche con carichi normali (una compilazione lunga),
    /// proprio quando StayAwake serve.
    static func shouldStop(_ state: ProcessInfo.ThermalState) -> Bool { state == .critical }
}

// MARK: - Sentinella

/// Un piccolo processo staccato che aspetta la fine dell'app e poi riporta lo sleep alla normalità.
/// Copre ciò che l'app da sola non può: crash, uscita forzata, `kill`.
enum Sentinel {
    /// Nome del processo (`$0` della shell): serve a riconoscere le sentinelle prima di fermarle.
    static let marker = "stayawake-sentinel"
    static let resetCommand = "/usr/bin/sudo -n /usr/bin/pmset -a disablesleep 0"

    static func script(appPID: Int32, finalCommand: String) -> String {
        "while /bin/kill -0 \(appPID) 2>/dev/null; do /bin/sleep 2; done; \(finalCommand)"
    }

    @discardableResult
    static func start(appPID: Int32, finalCommand: String = resetCommand) -> Process? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", script(appPID: appPID, finalCommand: finalCommand), marker]
        p.standardInput = FileHandle.nullDevice
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return nil }
        return p
    }

    /// Ferma (SIGTERM) le sentinelle di questo utente, e solo quelle.
    static func stopAll() {
        let ps = Process()
        ps.executableURL = URL(fileURLWithPath: "/bin/ps")
        ps.arguments = ["-axo", "pid=,uid=,args="]
        let pipe = Pipe()
        ps.standardOutput = pipe
        ps.standardError = FileHandle.nullDevice
        do { try ps.run() } catch { return }
        let out = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        ps.waitUntilExit()
        let me = getuid()
        for line in out.split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard parts.count == 3, let pid = Int32(parts[0]), let uid = UInt32(parts[1]), uid == me,
                  pid != getpid(),
                  parts[2].hasPrefix("/bin/sh -c "), parts[2].hasSuffix(" " + marker) else { continue }
            kill(pid, SIGTERM)
        }
    }
}
