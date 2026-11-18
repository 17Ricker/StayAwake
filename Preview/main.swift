// Anteprima offline: disegna il popover in PNG senza avviare l'app né toccare pmset.
// Uso: swiftc -D PREVIEW Sources/*.swift Preview/main.swift -o build/preview && build/preview <cartella> [--lang it|en|es] [--orari | --promo]
import SwiftUI
import AppKit

MainActor.assumeIsolated {
    let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
    let args = CommandLine.arguments
    func arg(_ flag: String) -> String? {
        args.firstIndex(of: flag).flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil }
    }
    let lang = AppLanguage(rawValue: arg("--lang") ?? "it") ?? .it

    @MainActor func make(settings: Bool = false, _ setup: (Controller) -> Void) -> ContentView {
        let c = Controller()
        c.language = lang
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
        c.language = lang
        c.theme = theme
        c.hasPermission = permission
        c.mode = mode
        if mode == .timed { c.total = 3600; c.remaining = 3000; c.endDate = Date().addingTimeInterval(3000) }
        return NSHostingView(rootView: ContentView(c: c)).fittingSize.height
    }
    // `--promo`: un PNG per ogni stato dell'app (sfondo trasparente, scala 2) per la promo e i README.
    // Orario fisso (oggi alle 21:30, 24 h): le immagini sono uguali a ogni esecuzione.
    if args.contains("--promo") {
        let base = Calendar.current.date(bySettingHour: 21, minute: 30, second: 0, of: Date())!
        Clock.fixedNow = base
        TimeText.forced12h = false
        @MainActor func card(_ v: ContentView) -> some View {
            v.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        for m in [30, 60, 90, 120] {
            save(card(make { c in c.theme = .night; c.duration = m }), as: "night-idle-\(m)")
        }
        // Timer da 2 h con 1:18:00 rimasti (35%): la pillola della barra si rende dallo stesso stato.
        @MainActor func timed(_ c: Controller, _ r: Int) {
            c.theme = .night; c.mode = .timed; c.total = 7200; c.remaining = TimeInterval(r)
            c.endDate = base.addingTimeInterval(TimeInterval(r))
        }
        for (i, r) in [4680, 4679, 4678, 4677].enumerated() {
            save(card(make { c in timed(c, r) }), as: "night-timed-\(i + 1)")
        }
        save(card(make { c in c.theme = .night; c.mode = .indefinite }), as: "night-continuous")
        save(card(make { c in c.theme = .retro; c.duration = 90 }), as: "retro-idle")
        save(card(make { c in c.theme = .modern; c.duration = 90 }), as: "modern-idle")
        save(card(make(settings: true) { c in c.theme = .night; c.duration = 90 }), as: "settings")

        // Icona della barra dei menu su trasparente, a 4×: a riposo in bianco, attiva con i suoi colori
        @MainActor func savePNG(_ image: NSImage, _ name: String, white: Bool) {
            let scale: CGFloat = 4, size = image.size
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                                       bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                       colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            rep.size = size
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            let rect = NSRect(origin: .zero, size: size)
            image.draw(in: rect)
            if white { NSColor.white.set(); rect.fill(using: .sourceAtop) }
            NSGraphicsContext.restoreGraphicsState()
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: out + "/" + name + ".png"))
            print("scritto", name)
        }
        let t = Strings.for(lang)
        savePNG(MenuBarArt.idle(t.summaryOff), "menubar-idle", white: true)
        let pillState = Controller()
        pillState.language = lang
        timed(pillState, 4680)
        savePNG(MenuBarArt.image(for: pillState), "menubar-timed", white: false)
        return
    }

    // `--orari`: per i casi più larghi (12:58 e 22:58 a 12 h, 23:58 a 24 h) una riga con Notte, Retro e
    // Modern da fermi (primo avvio) e con il timer. L'orario «fino alle» deve vedersi intero ovunque.
    if args.contains("--orari") {
        let cases: [(h: Int, m: Int, h12: Bool)] = [(12, 58, true), (22, 58, true), (23, 58, false)]
        var rows: [CGImage] = []
        for k in cases {
            let target = Calendar.current.date(bySettingHour: k.h, minute: k.m, second: 0, of: Date())!
            Clock.fixedNow = target.addingTimeInterval(-300)
            TimeText.forced12h = k.h12
            var cards: [ContentView] = []
            for theme in AppTheme.allCases {
                cards.append(make { c in c.theme = theme; c.duration = 5; c.hasPermission = false })
            }
            for theme in AppTheme.allCases {
                cards.append(make { c in
                    c.theme = theme; c.mode = .timed; c.total = 3600; c.remaining = 300; c.endDate = target
                })
            }
            let r = ImageRenderer(content: sheet(cards))
            r.scale = 1
            if let cg = r.cgImage { rows.append(cg) }
        }
        let w = rows.map(\.width).max() ?? 1, h = rows.map(\.height).reduce(0, +)
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        var y = h
        for img in rows { y -= img.height; ctx.draw(img, in: CGRect(x: 0, y: y, width: img.width, height: img.height)) }
        if let cg = ctx.makeImage(), let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: out + "/orari.png"))
            print("scritto orari", w, "x", h)
        }
        return
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
        c.error = c.t.activationCancelled
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
