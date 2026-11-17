// Anteprima offline: disegna il popover in PNG senza avviare l'app né toccare pmset.
// Uso: swiftc -D PREVIEW Sources/*.swift Preview/main.swift -o preview && ./preview <cartella>
import SwiftUI
import AppKit

MainActor.assumeIsolated {
    let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

    @MainActor func make(settings: Bool = false, _ setup: (Controller) -> Void) -> ContentView {
        let c = Controller()
        c.hasPermission = true
        setup(c)
        return ContentView(c: c, settingsOpen: settings)
    }

    @MainActor func sheet(_ views: [ContentView]) -> some View {
        HStack(alignment: .top, spacing: 28) {
            ForEach(0..<views.count, id: \.self) { i in
                views[i].clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(28)
        .background(Color(white: 0.45))
    }

    @MainActor func save<V: View>(_ view: V, as name: String) {
        let r = ImageRenderer(content: view)
        r.scale = 2
        guard let cg = r.cgImage,
              let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else {
            print("render fallito:", name); return
        }
        try? png.write(to: URL(fileURLWithPath: out + "/" + name + ".png"))
        print("scritto", name, cg.width, "x", cg.height)
    }

    // Altezza del popover per ogni stile e stato: devono coincidere, altrimenti la finestra salta.
    @MainActor func height(_ theme: AppTheme, _ mode: Controller.Mode, permission: Bool = true) -> CGFloat {
        let c = Controller()
        c.theme = theme
        c.hasPermission = permission
        c.mode = mode
        if mode == .timed { c.total = 3600; c.remaining = 3000; c.endDate = Date().addingTimeInterval(3000) }
        return NSHostingView(rootView: ContentView(c: c)).fittingSize.height
    }
    for theme in AppTheme.allCases {
        let off = height(theme, .off), timed = height(theme, .timed), endless = height(theme, .indefinite)
        let first = height(theme, .off, permission: false)
        print(String(format: "ALTEZZA %-7@ spento %.0f | timer %.0f | continuo %.0f | primo avvio %.0f", theme.rawValue as NSString, off, timed, endless, first))
    }

    // Modern (il vecchio stile grigio): da fermo, impostazioni aperte con errore, timer, continuo.
    let modernIdle = make { c in c.theme = .modern; c.duration = 90; c.hasPermission = false }
    let modernSettings = make(settings: true) { c in
        c.theme = .modern; c.duration = 45
        c.error = "Attivazione annullata: serve la password admin. Riprova."
    }
    let modernTimed = make { c in
        c.theme = .modern
        c.mode = .timed; c.total = 5400; c.remaining = 3300; c.endDate = Date().addingTimeInterval(3300)
    }
    save(sheet([modernIdle, modernSettings, modernTimed]), as: "modern-a")

    let modernEndless = make { c in c.theme = .modern; c.mode = .indefinite }
    // Il selettore Stile nei due stili scuri (Quadrante solo in Notte).
    let nightSettings = make(settings: true) { c in c.theme = .night; c.duration = 45 }
    let retroSettings = make(settings: true) { c in c.theme = .retro; c.duration = 90 }
    save(sheet([modernEndless, nightSettings, retroSettings]), as: "modern-b")

    // Notte dopo il ritocco dello switch: da fermo, timer, continuo; poi primo avvio, attesa password, impostazioni.
    let nightIdle = make { c in c.theme = .night; c.duration = 90 }
    let nightTimed = make { c in
        c.theme = .night
        c.mode = .timed; c.total = 5400; c.remaining = 3300; c.endDate = Date().addingTimeInterval(3300)
    }
    let nightEndless = make { c in c.theme = .night; c.mode = .indefinite }
    save(sheet([nightIdle, nightTimed, nightEndless]), as: "night-after")

    let nightFirstRun = make { c in c.theme = .night; c.duration = 90; c.hasPermission = false }
    let nightPending = make { c in c.theme = .night; c.duration = 90; c.pending = .indefinite }
    save(sheet([nightFirstRun, nightPending, nightSettings]), as: "night-after-2")
}
