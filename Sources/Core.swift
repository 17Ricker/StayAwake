import SwiftUI
import AppKit
import ServiceManagement
import IOKit.pwr_mgt

// MARK: - Preferenze di aspetto

/// Gli stili dell'app: “Notte” è quello predefinito, “Retro” e “Modern” si scelgono da Impostazioni.
enum AppTheme: String, CaseIterable, Identifiable {
    case night, retro, modern
    var id: String { rawValue }
}

enum DialStyle: String, CaseIterable, Identifiable {
    case classic, circle
    var id: String { rawValue }
}

// MARK: - Model

@MainActor
final class Controller: ObservableObject {
    enum Mode { case off, timed, indefinite }

    static let minMinutes = 5
    static let maxMinutes = 24 * 60
    static let stepMinutes = 5
    private static let defaults = UserDefaults.standard

    /// Porta una durata in minuti al multiplo di 5 più vicino, dentro i limiti.
    static func clamp(_ minutes: Int) -> Int {
        let snapped = Int((Double(minutes) / Double(stepMinutes)).rounded()) * stepMinutes
        return min(maxMinutes, max(minMinutes, snapped))
    }

    @Published var duration: Int { didSet { Self.defaults.set(duration, forKey: "duration"); error = nil } }
    /// Lingua dell'interfaccia (`system` segue macOS). Il cambio è immediato.
    @Published var language: AppLanguage { didSet { Self.defaults.set(language.rawValue, forKey: "language") } }
    @Published var theme: AppTheme { didSet { Self.defaults.set(theme.rawValue, forKey: "theme") } }
    @Published var dialStyle: DialStyle { didSet { Self.defaults.set(dialStyle.rawValue, forKey: "dialStyle") } }
    @Published var stopOnLowBattery: Bool { didSet { Self.defaults.set(stopOnLowBattery, forKey: "stopOnLowBattery") } }
    /// Si ferma se il Mac diventa troppo caldo (stato termico «critico»), per esempio chiuso in uno zaino.
    @Published var stopOnHeat: Bool { didSet { Self.defaults.set(stopOnHeat, forKey: "stopOnHeat") } }
    /// Tiene acceso anche lo schermo: `disablesleep` ferma lo sleep del Mac, non lo spegnimento per inattività.
    @Published var keepDisplayOn: Bool {
        didSet {
            Self.defaults.set(keepDisplayOn, forKey: "keepDisplayOn")
            if isActive { holdAssertions() }
        }
    }
    @Published var mode: Mode = .off
    @Published var pending: Mode?
    @Published private(set) var removingPermission = false
    @Published private(set) var restoringSleep = false
    @Published var remaining: TimeInterval = 0
    @Published var total: TimeInterval = 0
    @Published var endDate: Date?
    @Published var error: String?
    @Published var notice: String?
    @Published var needsManualRestore = false
    @Published var hasPermission = false
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled

    private var ticker: Timer?
    private var tickCount = 0
    private var assertions: [IOPMAssertionID] = []

    /// Testi nella lingua scelta.
    var t: Strings { Strings.for(language) }
    /// Locale della lingua scelta (simboli AM/PM).
    var locale: Locale { language.locale }

    var isActive: Bool { mode != .off }
    var busy: Bool { pending != nil || removingPermission || restoringSleep }

    /// Quota di timer già trascorsa, da 0 a 1.
    var progress: Double {
        guard mode == .timed, total > 0 else { return 0 }
        return min(1, max(0, 1 - remaining / total))
    }

    /// Nella barra dei menu solo i minuti: `59m`, oppure `1h 59m` da un'ora in su.
    var menuTitle: String {
        switch mode {
        case .off, .indefinite: return ""
        case .timed:
            let m = Int((max(0, remaining) / 60).rounded(.up))
            return m >= 60 ? "\(m / 60)h \(String(format: "%02d", m % 60))m" : "\(m)m"
        }
    }

    var summary: String {
        switch mode {
        case .off: return t.summaryOff
        case .timed: return t.summaryTimed(menuTitle)
        case .indefinite: return t.summaryContinuous
        }
    }

    static func format(_ t: TimeInterval) -> String {
        let s = Int(max(0, t.rounded(.up)))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }

    init() {
        let d = Self.defaults
        if let saved = d.object(forKey: "duration") as? Int {
            duration = Self.clamp(saved)
        } else {
            // Migrazione dal vecchio formato ore + minuti.
            let h = d.object(forKey: "hours") as? Int ?? 1
            let m = d.object(forKey: "minutes") as? Int ?? 0
            duration = Self.clamp(h * 60 + m)
        }
        language = AppLanguage(rawValue: d.string(forKey: "language") ?? "") ?? .system
        theme = AppTheme(rawValue: d.string(forKey: "theme") ?? "") ?? .night
        dialStyle = DialStyle(rawValue: d.string(forKey: "dialStyle") ?? "") ?? .classic
        stopOnLowBattery = d.object(forKey: "stopOnLowBattery") as? Bool ?? true
        keepDisplayOn = d.object(forKey: "keepDisplayOn") as? Bool ?? true
        stopOnHeat = d.object(forKey: "stopOnHeat") as? Bool ?? true
        #if !PREVIEW
        // Se un'esecuzione precedente è stata interrotta, riporta lo sleep alla normalità
        // (le sue sentinelle non servono più). All'avvio non si chiede la password: se lo sleep
        // è rimasto disattivato e il permesso non c'è più, offre il ripristino con un clic.
        if Permission.setSleepDisabled(false) || !Permission.isSleepDisabled() {
            Sentinel.stopAll()
        } else {
            error = t.sleepStillDisabled
            needsManualRestore = true
        }
        hasPermission = Permission.isGranted()
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                if self?.restoreSleep() ?? Permission.setSleepDisabled(false) { Sentinel.stopAll() }
            }
        }
        NotificationCenter.default.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.checkHeat() }
        }
        #endif
    }

    // MARK: Azioni

    func setDuration(_ minutes: Int) {
        let v = Self.clamp(minutes)
        if v != duration { duration = v }
    }

    /// Da fermo cambia la durata scelta; con il timer in corso allunga o accorcia il tempo rimasto.
    func nudge(_ minutes: Int) {
        switch mode {
        case .off:
            setDuration(duration + minutes)
        case .timed:
            extend(by: TimeInterval(minutes * 60))
        case .indefinite:
            break
        }
    }

    func startTimed() {
        let secs = TimeInterval(duration * 60)
        activate(.timed) { [self] in
            endDate = Date().addingTimeInterval(secs)
            remaining = secs
            total = secs
        }
    }

    func startIndefinite() {
        activate(.indefinite) { [self] in endDate = nil }
    }

    func extend(by seconds: TimeInterval) {
        guard mode == .timed, let end = endDate else { return }
        let maxSeconds = TimeInterval(Self.maxMinutes * 60)
        let currentRemaining = max(0, end.timeIntervalSinceNow)
        let targetRemaining = min(maxSeconds, currentRemaining + seconds)
        guard targetRemaining > 60 else { return }
        let appliedDelta = targetRemaining - currentRemaining
        guard abs(appliedDelta) > 0.001 else { return }
        endDate = Date().addingTimeInterval(targetRemaining)
        total = min(maxSeconds, max(targetRemaining, total + appliedDelta))
        remaining = targetRemaining
    }

    func stop(notice message: String? = nil) {
        releaseAssertions()
        ticker?.invalidate(); ticker = nil
        endDate = nil
        mode = .off
        notice = message
        // Prima si ripristina, poi si fermano le sentinelle: se il ripristino fallisce restano lì.
        if restoreSleep() {
            Sentinel.stopAll()
            needsManualRestore = false
        } else {
            error = t.cannotRestoreSleep
            needsManualRestore = true
        }
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            self.error = t.loginItemError
            self.needsManualRestore = false
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func removePermission() {
        guard !busy else { return }
        error = nil; notice = nil; needsManualRestore = false
        if isActive {
            stop()
            guard error == nil else { return }
        }
        removingPermission = true
        Task {
            let prompt = t.removePrompt
            let ok = await Task.detached { Permission.remove(prompt: prompt) }.value
            removingPermission = false
            hasPermission = Permission.isGranted()
            if ok { notice = t.permissionRemoved }
            else { error = t.removeCancelled }
        }
    }

    func retryRestoreSleep() {
        guard !busy else { return }
        restoringSleep = true
        let prompt = t.restorePrompt
        Task {
            let ok = await Task.detached {
                Permission.setSleepDisabled(false)
                    || !Permission.isSleepDisabled()
                    || Permission.restoreWithPassword(prompt: prompt)
            }.value
            restoringSleep = false
            hasPermission = Permission.isGranted()
            if ok {
                Sentinel.stopAll()
                error = nil
                needsManualRestore = false
            }
        }
    }

    func dismissMessage() {
        error = nil
        notice = nil
        needsManualRestore = false
    }

    // MARK: Interni

    /// Riporta lo sleep alla normalità. Se la regola è stata tolta a mano (README, Terminale) chiede
    /// la password, ma solo se lo sleep è davvero ancora disattivato. Vero se alla fine è normale.
    @discardableResult
    private func restoreSleep() -> Bool {
        if Permission.setSleepDisabled(false) { return true }
        guard Permission.isSleepDisabled() else { return true }
        return Permission.restoreWithPassword(prompt: t.restorePrompt)
    }

    private func activate(_ target: Mode, _ prepare: @escaping @MainActor () -> Void) {
        guard !busy else { return }
        error = nil; notice = nil; needsManualRestore = false
        if let reason = StartCheck.blocker(stopOnLowBattery: stopOnLowBattery, batteryLow: stopOnLowBattery && Battery.isLow(),
                                           stopOnHeat: stopOnHeat, thermal: ProcessInfo.processInfo.thermalState, t: t) {
            error = reason
            return
        }
        pending = target
        Task {
            let prompt = t.installPrompt
            let ok = await Task.detached { () -> Bool in
                // Prima la regola, poi il cambio: con credenziali admin in cache `sudo -n` riuscirebbe
                // anche senza regola, e lo stop successivo fallirebbe a cache scaduta.
                if !Permission.isGranted() {
                    guard Permission.install(prompt: prompt) else { return false }
                }
                // La sentinella parte PRIMA di disattivare lo sleep: un crash in quel momento
                // non lascia il Mac sveglio. Se l'attivazione fallisce, si ferma.
                Sentinel.stopAll()
                Sentinel.start(appPID: getpid())
                if Permission.setSleepDisabled(true) { return true }
                Sentinel.stopAll()
                return false
            }.value
            pending = nil
            hasPermission = Permission.isGranted()
            if ok {
                prepare()
                mode = target
                holdAssertions()
                startTicker()
            } else {
                error = t.activationCancelled
            }
        }
    }

    /// Asserzioni di alimentazione attive finché StayAwake è acceso: niente sleep per inattività e,
    /// se richiesto, niente spegnimento dello schermo né salvaschermo.
    private func holdAssertions() {
        releaseAssertions()
        func make(_ type: CFString) {
            var id = IOPMAssertionID(0)
            let level = IOPMAssertionLevel(kIOPMAssertionLevelOn)
            if IOPMAssertionCreateWithName(type, level, "StayAwake" as CFString, &id) == kIOReturnSuccess {
                assertions.append(id)
            }
        }
        make(kIOPMAssertionTypePreventUserIdleSystemSleep as CFString)
        if keepDisplayOn { make(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString) }
    }

    private func releaseAssertions() {
        for id in assertions { IOPMAssertionRelease(id) }
        assertions.removeAll()
    }

    private func startTicker() {
        ticker?.invalidate()
        tickCount = 0
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func tick() {
        if mode == .timed, let end = endDate {
            remaining = end.timeIntervalSinceNow
            if remaining <= 0 { stop(); return }
        }
        tickCount += 1
        if tickCount % 15 == 0, stopOnLowBattery, Battery.isLow() {
            stop(notice: t.stoppedLowBattery(Battery.threshold))
        }
        if tickCount % 15 == 0 { checkHeat() }
    }

    /// Ferma tutto se il Mac è troppo caldo (e la protezione è attiva).
    private func checkHeat() {
        guard isActive, stopOnHeat, Thermal.shouldStop(ProcessInfo.processInfo.thermalState) else { return }
        stop(notice: t.stoppedHeat)
    }
}

// MARK: - Barra dei menu

/// Disegna l'elemento nella barra dei menu: fulmine vuoto da spento; da attivo una pillola scura
/// con un anello che si riempie mentre il timer scorre (rosso pieno in modalità continua).
enum MenuBarArt {
    private static let orange = NSColor(srgbRed: 238 / 255, green: 123 / 255, blue: 63 / 255, alpha: 1)
    private static let red = NSColor(srgbRed: 229 / 255, green: 72 / 255, blue: 77 / 255, alpha: 1)

    @MainActor static func image(for c: Controller) -> NSImage {
        switch c.mode {
        case .off: return idle(c.t.summaryOff)
        case .timed: return pill(timed: true, progress: c.progress, title: c.menuTitle, summary: c.summary)
        case .indefinite: return pill(timed: false, progress: 1, title: "", summary: c.summary)
        }
    }

    static func idle(_ description: String) -> NSImage {
        let cfg = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let base = NSImage(systemSymbolName: "bolt", accessibilityDescription: description)!
        let img = base.withSymbolConfiguration(cfg) ?? base
        img.isTemplate = true            // si adatta a barra chiara/scura
        return img
    }

    /// Icona dello stile “Modern”: fulmine vuoto da spento, pieno e colorato da attivo
    /// (giallo = timer, rosso = continuo); i minuti li aggiunge l'etichetta accanto.
    static func classicIcon(_ mode: Controller.Mode) -> NSImage {
        let size = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let name = mode == .off ? "bolt" : "bolt.fill"
        let base = NSImage(systemSymbolName: name, accessibilityDescription: "StayAwake")!
        guard mode != .off else {
            let img = base.withSymbolConfiguration(size) ?? base
            img.isTemplate = true
            return img
        }
        let color: NSColor = mode == .timed ? .systemYellow : .systemRed
        let cfg = size.applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        let img = base.withSymbolConfiguration(cfg) ?? base
        img.isTemplate = false
        return img
    }

    private static func symbol(_ name: String, size: CGFloat) -> NSImage? {
        let cfg = NSImage.SymbolConfiguration(pointSize: size, weight: .semibold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(cfg)
    }

    /// Percorso a stadio che parte dal centro del lato alto e gira in senso orario.
    private static func stadium(_ r: NSRect) -> NSBezierPath {
        let rad = r.height / 2
        let p = NSBezierPath()
        p.move(to: NSPoint(x: r.midX, y: r.maxY))
        p.line(to: NSPoint(x: r.maxX - rad, y: r.maxY))
        p.appendArc(withCenter: NSPoint(x: r.maxX - rad, y: r.midY), radius: rad, startAngle: 90, endAngle: -90, clockwise: true)
        p.line(to: NSPoint(x: r.minX + rad, y: r.minY))
        p.appendArc(withCenter: NSPoint(x: r.minX + rad, y: r.midY), radius: rad, startAngle: -90, endAngle: -270, clockwise: true)
        p.line(to: NSPoint(x: r.midX, y: r.maxY))
        return p
    }

    static func pill(timed: Bool, progress: Double, title: String, summary: String) -> NSImage {
        let height: CGFloat = 20
        let font = NSFont(name: "AvenirNext-DemiBold", size: 11) ?? NSFont.systemFont(ofSize: 11, weight: .semibold)
        let text = NSAttributedString(string: title, attributes: [.font: font, .foregroundColor: NSColor.white])
        let bolt = symbol("bolt.fill", size: 9.5)
        let infinity = symbol("infinity", size: 10)
        let boltW = bolt?.size.width ?? 8
        let contentW = timed ? ceil(text.size().width) : (infinity?.size.width ?? 12)
        let width = 10 + boltW + 4 + contentW + 10
        let tint = timed ? orange : red
        let fraction = CGFloat(min(1, max(0, progress)))

        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
            let body = NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2)
            NSColor(srgbRed: 0.04, green: 0.04, blue: 0.045, alpha: 0.97).setFill()
            body.fill()

            let ring = rect.insetBy(dx: 1.6, dy: 1.6)
            let track = stadium(ring)
            track.lineWidth = 1.7
            track.lineCapStyle = .round
            NSColor(white: 0.28, alpha: 1).setStroke()
            track.stroke()

            if fraction > 0.004 {
                let length = 2 * (ring.width - ring.height) + .pi * ring.height
                let filled = stadium(ring)
                filled.lineWidth = 1.7
                filled.lineCapStyle = .round
                var dash: [CGFloat] = [fraction * length, length]
                filled.setLineDash(&dash, count: 2, phase: 0)
                tint.setStroke()
                filled.stroke()
            }

            var x: CGFloat = 10
            if let bolt {
                let s = bolt.size
                bolt.draw(in: NSRect(x: x, y: (rect.height - s.height) / 2, width: s.width, height: s.height))
            }
            x += boltW + 4
            if timed {
                text.draw(at: NSPoint(x: x, y: (rect.height - text.size().height) / 2))
            } else if let infinity {
                let s = infinity.size
                infinity.draw(in: NSRect(x: x, y: (rect.height - s.height) / 2, width: s.width, height: s.height))
            }
            return true
        }
        image.isTemplate = false         // mantiene i colori
        image.accessibilityDescription = summary
        return image
    }
}
