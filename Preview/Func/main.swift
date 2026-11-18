// Prova funzionale: ospita la vera ContentView in una finestra, preme i pulsanti (accessibilità e click del mouse)
// e controlla stato dell'app e `pmset`. Usa il vero permesso sudo: ripristina sempre lo sleep alla fine.
// Uso: swiftc -D FUNCTEST Sources/*.swift Preview/Func/main.swift -o build/functest && build/functest
import SwiftUI
import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

func sleepDisabled() -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
    p.arguments = ["-g"]
    let pipe = Pipe()
    p.standardOutput = pipe
    try? p.run(); p.waitUntilExit()
    let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    return out.split(separator: "\n").first { $0.contains("SleepDisabled") }.map { String($0).trimmingCharacters(in: .whitespaces) } ?? "?"
}

@MainActor
func axChildren(_ o: Any) -> [Any] {
    guard let p = o as? NSAccessibilityProtocol else { return [] }
    return p.accessibilityChildren() ?? []
}

@MainActor
func axDump(_ o: Any, depth: Int = 0, into lines: inout [String]) {
    guard let p = o as? NSAccessibilityProtocol else { return }
    let label = p.accessibilityLabel() ?? ""
    let role = p.accessibilityRole()?.rawValue ?? ""
    if !label.isEmpty || role.contains("Button") {
        lines.append(String(repeating: " ", count: depth) + "[\(role)] \(label)")
    }
    for c in axChildren(o) { axDump(c, depth: depth + 1, into: &lines) }
}

@MainActor
func axFind(_ o: Any, label: String) -> NSAccessibilityProtocol? {
    if let p = o as? NSAccessibilityProtocol, p.accessibilityLabel() == label { return p }
    for c in axChildren(o) { if let r = axFind(c, label: label) { return r } }
    return nil
}

@MainActor
func runTest() async {
    let ctl = Controller()
    func report(_ what: String) {
    let a = Process(); a.executableURL = URL(fileURLWithPath: "/usr/bin/pmset"); a.arguments = ["-g", "assertions"]
        let ap = Pipe(); a.standardOutput = ap; try? a.run(); a.waitUntilExit()
        let ao = String(data: ap.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let held = ao.components(separatedBy: "\n").filter { $0.contains("\"StayAwake\"") }.count
        print(String(format: "%-34@ mode=%@ errore=%@ | %@ | asserzioni StayAwake: %d", what as NSString, "\(ctl.mode)", ctl.error ?? "-", sleepDisabled(), held))
    fflush(stdout)
}

    let host = NSHostingView(rootView: ContentView(c: ctl))
    let size = host.fittingSize
    host.frame = NSRect(origin: .zero, size: size)
    let win = NSWindow(contentRect: NSRect(x: -6000, y: 200, width: size.width, height: size.height),
                       styleMask: [.borderless], backing: .buffered, defer: false)
    win.contentView = host
    win.orderFrontRegardless()
    func pause(_ s: Double) async { try? await Task.sleep(nanoseconds: UInt64(s * 1_000_000_000)) }
    await pause(1.0)

    let h = size.height
    print("finestra \(Int(size.width))x\(Int(h))")
    report("iniziale")

    /// Clic con il mouse in un punto (y misurata dall'alto, come nel disegno).
    func click(_ name: String, x: CGFloat, yTop: CGFloat) async {
        let p = NSPoint(x: x, y: h - yTop)
        let hit = host.hitTest(host.convert(p, from: nil))
        print("  clic «\(name)» su (\(Int(x)), \(Int(yTop))) -> riceve: \(hit.map { String(describing: type(of: $0)) } ?? "nessuno")")
        func ev(_ t: NSEvent.EventType) -> NSEvent {
            NSEvent.mouseEvent(with: t, location: p, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                               windowNumber: win.windowNumber, context: nil, eventNumber: 0, clickCount: 1,
                               pressure: t == .leftMouseDown ? 1 : 0)!
        }
        win.sendEvent(ev(.leftMouseDown)); await pause(0.08); win.sendEvent(ev(.leftMouseUp))
        await pause(1.5)
    }

    print("\n=== da spento")
    await click("Avvia timer", x: 160, yTop: 363); report("dopo «Avvia timer»")
    await click("Stop", x: 259, yTop: 287); report("dopo «Stop»")
    await click("Continuo", x: 160, yTop: 420); report("dopo «Continuo» (acceso)")
    await click("Continuo", x: 160, yTop: 420); report("dopo «Continuo» (spento)")
    ctl.stop()
    report("fine (ripristinato)")
    exit(0)
}

Task { @MainActor in await runTest() }
RunLoop.main.run()
