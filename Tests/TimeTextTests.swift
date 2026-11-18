import Foundation

private let rome: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Rome")!
    return c
}()

private func at(_ h: Int, _ m: Int) -> Date {
    rome.date(from: DateComponents(year: 2026, month: 11, day: 17, hour: h, minute: m))!
}

private func symbols(_ id: String) -> (am: String, pm: String) {
    let f = DateFormatter()
    f.locale = Locale(identifier: id)
    return (f.amSymbol, f.pmSymbol)
}

private func make(_ h: Int, _ m: Int, _ lang: String, _ use12h: Bool) -> TimeText {
    TimeText.make(at(h, m), locale: Locale(identifier: lang), use12h: use12h, calendar: rome)
}

func timeTextTests() {
    check(make(17, 37, "en", true) == TimeText(digits: "5:37", period: symbols("en").pm), "12 h: 17:37 → 5:37 PM")
    check(make(17, 37, "it", false) == TimeText(digits: "17:37", period: nil), "24 h: 17:37 senza AM/PM")
    check(make(22, 58, "es", true).digits == "10:58" && make(22, 58, "es", true).period == symbols("es").pm, "12 h spagnolo: 10:58 p. m.")
    check(make(0, 5, "en", true) == TimeText(digits: "12:05", period: symbols("en").am), "12 h: mezzanotte e 5 → 12:05 AM")
    check(make(12, 58, "en", true) == TimeText(digits: "12:58", period: symbols("en").pm), "12 h: mezzogiorno → 12:58 PM")
    check(make(9, 5, "it", false).digits == "09:05", "24 h: due cifre per l'ora")
    check(TimeText.uses12h(.oneToTwelve) && TimeText.uses12h(.zeroToEleven), "12 h: cicli 1–12 e 0–11")
    check(!TimeText.uses12h(.zeroToTwentyThree) && !TimeText.uses12h(.oneToTwentyFour), "24 h: cicli 0–23 e 1–24")
    check(make(17, 37, "en", true).text == "5:37\u{00A0}" + symbols("en").pm, "testo intero con spazio indivisibile prima di PM")
}
