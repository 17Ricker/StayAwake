import Foundation

// MARK: - Lingua

/// Lingua dell'interfaccia. `system` segue macOS.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system, it, en, es
    var id: String { rawValue }

    /// La lingua da usare davvero (mai `.system`): per «Sistema», la prima lingua preferita
    /// di macOS fra quelle supportate; se nessuna lo è, inglese.
    func resolved(preferred: [String] = Locale.preferredLanguages) -> AppLanguage {
        guard self == .system else { return self }
        for tag in preferred {
            let code = Locale(identifier: tag).language.languageCode?.identifier ?? String(tag.prefix(2))
            if let lang = AppLanguage(rawValue: code), lang != .system { return lang }
        }
        return .en
    }

    /// Locale della lingua risolta (simboli AM/PM e simili).
    var locale: Locale { Locale(identifier: resolved().rawValue) }
}

// MARK: - Testi

/// Tutti i testi dell'interfaccia, di VoiceOver e dei messaggi. Una tabella per lingua
/// (`Strings+IT/EN/ES.swift`): se a una lingua manca un testo, l'app non compila.
/// Per aggiungere una lingua: un caso in `AppLanguage`, un file `Strings+XX.swift`, una riga in `for(_:)`.
struct Strings: Sendable {
    // Lingua, stili, quadrante
    let languageName: @Sendable (AppLanguage) -> String
    let themeName: @Sendable (AppTheme) -> String
    let dialName: @Sendable (DialStyle) -> String

    // Stato e barra dei menu
    let statusOff: String
    let statusTimer: String
    let statusContinuous: String
    let summaryOff: String
    let summaryTimed: @Sendable (String) -> String
    let summaryContinuous: String

    // Azioni
    let startTimer: String
    let stop: String
    let continuous: String
    let timer: String
    let timerActive: String
    let add30: String
    let waitingPassword: String
    /// Versione corta per lo schermo del tema Retro.
    let retroWaiting: String
    /// «premi [✓] per avviare»: le parole attorno all'icona.
    let hintPress: String
    let hintToStart: String
    let hintToStop: String
    let moreTime: String
    let lessTime: String
    let mode: String

    // Durata e orari
    let duration: String
    let durationA11y: String
    let hoursUnit: @Sendable (Int) -> String
    let minutesUnit: String
    let hoursSpoken: String
    let minutesSpoken: String
    let durationLong: @Sendable (Int) -> String
    let durationSpoken: @Sendable (Int) -> String
    let untilCaps: String
    let untilTime: @Sendable (String) -> String
    let remaining: @Sendable (String) -> String
    let noEnd: String
    let noLimit: String
    let activeNoLimit: String
    let staysOnUntilStopped: String
    let lidNote: String
    let firstTimePassword: String

    // Impostazioni
    let settings: String
    let settingsOpen: String
    let settingsClosed: String
    let toggleOn: String
    let toggleOff: String
    let batteryProtection: String
    let batteryProtectionDetail: @Sendable (Int) -> String
    let heatProtection: String
    let heatProtectionDetail: String
    let keepDisplayOn: String
    let keepDisplayOnDetail: String
    let launchAtLogin: String
    let dial: String
    let style: String
    let language: String
    let removePermission: String
    let quit: String

    // Messaggi e prompt della password
    let installPrompt: String
    let removePrompt: String
    let activationCancelled: String
    let batteryTooLow: @Sendable (Int) -> String
    let stoppedLowBattery: @Sendable (Int) -> String
    let stoppedHeat: String
    let cannotRestoreSleep: String
    let loginItemError: @Sendable (String) -> String
    let permissionRemoved: String
    let removeCancelled: String
    /// Prompt della password quando lo sleep va ripristinato ma la regola non c'è più.
    let restorePrompt: String
    /// All'avvio: lo sleep è rimasto disattivato e senza permesso non si può ripristinare da soli.
    let sleepStillDisabled: String

    static func `for`(_ language: AppLanguage) -> Strings {
        switch language.resolved() {
        case .it: return .it
        case .es: return .es
        default: return .en
        }
    }

    // MARK: Pezzi comuni alle tabelle

    /// Nomi delle lingue, ognuno nella propria lingua (tranne «Sistema», che si traduce).
    static func nativeLanguageName(_ l: AppLanguage, system: String) -> String {
        switch l {
        case .system: return system
        case .it: return "Italiano"
        case .en: return "English"
        case .es: return "Español"
        }
    }

    /// `45 min`, `1 h`, `1 h 30`: uguale in tutte le lingue.
    static func compactDuration(_ m: Int) -> String {
        if m < 60 { return "\(m) min" }
        let h = m / 60, r = m % 60
        return r == 0 ? "\(h) h" : "\(h) h \(r)"
    }

    /// Durata a parole: `1 ora e 30 minuti`.
    static func spokenDuration(_ m: Int, hour: (String, String), minute: (String, String), and: String) -> String {
        let h = m / 60, r = m % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h) \(h == 1 ? hour.0 : hour.1)") }
        if r > 0 { parts.append("\(r) \(r == 1 ? minute.0 : minute.1)") }
        return parts.joined(separator: " \(and) ")
    }
}

extension String {
    /// Prima lettera maiuscola: «fino alle 5:37» → «Fino alle 5:37».
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
