import Foundation

func stringsTests() {
    // Lingua «Sistema»: la prima lingua preferita supportata, altrimenti inglese
    check(AppLanguage.system.resolved(preferred: ["es-ES", "en"]) == .es, "Sistema: spagnolo")
    check(AppLanguage.system.resolved(preferred: ["de-DE", "it-IT"]) == .it, "Sistema: salta il tedesco, prende l'italiano")
    check(AppLanguage.system.resolved(preferred: ["de-DE", "fr"]) == .en, "Sistema: nessuna supportata → inglese")
    check(AppLanguage.system.resolved(preferred: []) == .en, "Sistema: elenco vuoto → inglese")
    check(AppLanguage.it.resolved() == .it, "lingua scelta: resta quella")
    check(AppLanguage.allCases.map(\.rawValue) == ["system", "it", "en", "es"], "ordine delle lingue")

    // Durata letta da VoiceOver, con la grammatica di ogni lingua
    let it = Strings.for(.it), en = Strings.for(.en), es = Strings.for(.es)
    check(it.durationSpoken(90) == "1 ora e 30 minuti", "it: 90 minuti a voce")
    check(en.durationSpoken(90) == "1 hour and 30 minutes", "en: 90 minuti a voce")
    check(es.durationSpoken(90) == "1 hora y 30 minutos", "es: 90 minuti a voce")
    check([it.durationSpoken(60), it.durationSpoken(120)] == ["1 ora", "2 ore"], "it: ore a voce")
    check([en.durationSpoken(60), en.durationSpoken(120)] == ["1 hour", "2 hours"], "en: ore a voce")
    check([es.durationSpoken(60), es.durationSpoken(120)] == ["1 hora", "2 horas"], "es: ore a voce")

    // Durata scritta: uguale in tutte le lingue
    for s in [it, en, es] {
        check(s.durationLong(45) == "45 min" && s.durationLong(90) == "1 h 30" && s.durationLong(120) == "2 h", "durata scritta")
    }

    // Nomi delle lingue: ognuna nella propria lingua; «Sistema» tradotto
    for s in [it, en, es] {
        check(s.languageName(.it) == "Italiano" && s.languageName(.en) == "English" && s.languageName(.es) == "Español",
              "nomi delle lingue nella propria lingua")
    }
    check([it.languageName(.system), en.languageName(.system), es.languageName(.system)] == ["Sistema", "System", "Sistema"],
          "«Sistema» tradotto")

    // Sleep rimasto disattivato: messaggi chiari e pulsante di ripristino presenti
    for s in [it, en, es] {
        check(!s.restorePrompt.isEmpty, "prompt di ripristino presente")
        check(!s.restoreSleepNow.isEmpty, "etichetta pulsante ripristino presente")
        check(!s.sleepStillDisabled.isEmpty && !s.cannotRestoreSleep.isEmpty, "messaggi di ripristino presenti")
        check(!s.loginItemError.isEmpty, "messaggio errore login item presente")
        check(!s.dismiss.isEmpty && s.dismiss != s.stop, "etichetta «chiudi» distinta da Stop")
    }

    // «fino alle» con l'articolo giusto davanti all'una
    check(it.untilTime("17:37") == "fino alle 17:37", "it: fino alle")
    check(es.untilTime("5:37") == "hasta las 5:37" && es.untilTime("1:05") == "hasta la 1:05", "es: hasta las / hasta la 1")
    check(en.untilTime("5:37") == "until 5:37", "en: until")
    check(it.untilTime("1:05") == "fino all'1:05" && it.untilTime("01:05") == "fino all'01:05", "it: fino all'una")
}
