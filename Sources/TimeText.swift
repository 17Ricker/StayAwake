import Foundation

/// Un orario diviso in cifre e indicazione AM/PM, così le cifre possono restare grandi
/// e «PM» / «p. m.» stare accanto più piccolo, senza troncare niente.
struct TimeText: Equatable {
    let digits: String
    let period: String?

    /// Orario intero su una riga: «5:37 PM» (spazio indivisibile: «PM» non va mai a capo da solo).
    var text: String { period.map { "\(digits)\u{00A0}\($0)" } ?? digits }

    /// Solo per le anteprime: forza 12 h (`true`) o 24 h (`false`).
    nonisolated(unsafe) static var forced12h: Bool?

    /// Cifre costruite dal calendario, **non** con un `dateFormat` fisso: macOS forza un formato
    /// come `HH:mm` a 12 h quando l'utente usa le 12 h, e allora «PM» spuntava dove non c'era spazio.
    static func make(_ date: Date, locale: Locale, use12h: Bool, calendar: Calendar = .current) -> TimeText {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        let h = c.hour ?? 0, m = c.minute ?? 0
        guard use12h else { return TimeText(digits: String(format: "%02d:%02d", h, m), period: nil) }
        let f = DateFormatter()
        f.locale = locale
        let h12 = h % 12 == 0 ? 12 : h % 12
        return TimeText(digits: String(format: "%d:%02d", h12, m), period: h < 12 ? f.amSymbol : f.pmSymbol)
    }

    /// L'utente usa le 12 h? (Impostazioni di Sistema → Generali → Data e ora).
    static func systemUses12h() -> Bool { uses12h(Locale.autoupdatingCurrent.hourCycle) }

    /// 12 h per i cicli 1–12 e 0–11; 24 h per 0–23 e 1–24.
    static func uses12h(_ cycle: Locale.HourCycle) -> Bool { [.oneToTwelve, .zeroToEleven].contains(cycle) }

    /// Orario di fine come lo vede l'utente: lingua dell'app, 12/24 h di sistema.
    static func end(_ date: Date, locale: Locale) -> TimeText {
        make(date, locale: locale, use12h: forced12h ?? systemUses12h())
    }
}
