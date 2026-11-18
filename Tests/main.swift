// Test di StayAwake: eseguibile semplice, senza root e senza toccare pmset.
// Uso: ./test.sh
import Foundation

nonisolated(unsafe) var failures = 0

/// Stampa OK/FAIL e conta i fallimenti.
func check(_ ok: Bool, _ name: String) {
    print(ok ? "OK   \(name)" : "FAIL \(name)")
    if !ok { failures += 1 }
}

/// Cartella temporanea nuova per un test.
func tempDir(_ name: String) -> String {
    let base = ProcessInfo.processInfo.environment["TMPDIR"] ?? NSTemporaryDirectory()
    let dir = (base as NSString).appendingPathComponent("stayawake-tests/\(name)-\(UUID().uuidString.prefix(8))")
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    return dir
}

/// Esegue un comando e restituisce codice di uscita e output (stdout + stderr).
@discardableResult
func shell(_ path: String, _ args: [String]) -> (status: Int32, output: String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: path)
    p.arguments = args
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = pipe
    do { try p.run() } catch { return (-1, "\(error)") }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return (p.terminationStatus, String(decoding: data, as: UTF8.self))
}

// Modalità figlio del test di crash (vedi SafetyTests): fa da «app», avvia la sentinella
// su questo processo e muore di colpo con SIGKILL, senza nessuna pulizia.
if let i = CommandLine.arguments.firstIndex(of: "--sentinel-child"), CommandLine.arguments.count > i + 1 {
    Sentinel.start(appPID: getpid(), finalCommand: "/bin/echo ripristinato > '\(CommandLine.arguments[i + 1])'")
    Thread.sleep(forTimeInterval: 0.3)
    kill(getpid(), SIGKILL)
}

MainActor.assumeIsolated {
    check(Controller.clamp(7) == 5, "clamp arrotonda a 5")
    let c = Controller()
    c.mode = .timed
    c.total = 3600
    c.remaining = 3600
    c.endDate = Date().addingTimeInterval(3600)
    c.extend(by: TimeInterval(30 * 3600))
    let maxSecs = TimeInterval(Controller.maxMinutes * 60)
    check(c.remaining <= maxSecs + 0.5 && c.total <= maxSecs, "extend non supera le 24 ore")
    c.extend(by: -TimeInterval(30 * 3600))
    check(c.remaining > 60, "extend non scende sotto 1 minuto")
}
permissionTests()
safetyTests()
stringsTests()
timeTextTests()

print(failures == 0 ? "TUTTI OK" : "\(failures) FALLITI")
exit(failures == 0 ? 0 : 1)
