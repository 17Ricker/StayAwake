// Snapshot della vista reale (con la vera ScrollView della rotella) tramite NSHostingView.
// Uso: swiftc -D PREVIEW -D LIVEWHEEL Sources/*.swift Preview/Live/main.swift -o build/live && build/live <cartella>
import SwiftUI
import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

MainActor.assumeIsolated {
    let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

    @MainActor func snap(_ name: String, _ setup: (Controller) -> Void) {
        let c = Controller()
        c.hasPermission = true
        setup(c)
        let host = NSHostingView(rootView: ContentView(c: c))
        let size = host.fittingSize
        host.frame = NSRect(origin: .zero, size: size)
        let win = NSWindow(contentRect: NSRect(x: -6000, y: 200, width: size.width, height: size.height),
                           styleMask: [.borderless], backing: .buffered, defer: false)
        win.contentView = host
        win.orderFrontRegardless()
        RunLoop.current.run(until: Date().addingTimeInterval(1.2))
        host.layoutSubtreeIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { print("rep nil"); return }
        host.cacheDisplay(in: host.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { print("png nil"); return }
        try? png.write(to: URL(fileURLWithPath: out + "/" + name + ".png"))
        print("scritto", name, rep.pixelsWide, "x", rep.pixelsHigh)
        win.orderOut(nil)
    }

    snap("live-modern") { c in c.theme = .modern; c.duration = 75 }
}
