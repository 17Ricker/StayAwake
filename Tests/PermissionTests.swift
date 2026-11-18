import Foundation

/// Il letterale stringa AppleScript che segue `prefix` in `source` (con le virgolette), o nil.
private func appleScriptLiteral(in source: String, after prefix: String) -> String? {
    guard let start = source.range(of: prefix)?.upperBound else { return nil }
    var out = "\""
    var escaped = false
    for ch in source[start...] {
        out.append(ch)
        if escaped { escaped = false; continue }
        if ch == "\\" { escaped = true; continue }
        if ch == "\"" { return out }
    }
    return nil
}

/// Valuta un letterale AppleScript con osascript (solo `return`, nessun comando eseguito).
private func appleScriptValue(_ literal: String) -> String {
    var out = shell("/usr/bin/osascript", ["-e", "return \(literal)"]).output
    if out.hasSuffix("\n") { out.removeLast() }
    return out
}

/// Esegue uno script di root SENZA root: /tmp e /etc/sudoers.d diventano `dir`, niente chown.
private func runWithoutRoot(_ script: String, in dir: String) -> Int32 {
    let local = script
        .replacingOccurrences(of: "/tmp/stayawake", with: dir + "/stayawake")
        .replacingOccurrences(of: "/etc/sudoers.d/", with: dir + "/")
        .replacingOccurrences(of: "-o root -g wheel ", with: "")
    return shell("/bin/sh", ["-c", local]).status
}

private func read(_ path: String) -> String? { try? String(contentsOfFile: path, encoding: .utf8) }

func permissionTests() {
    let rule = "#501 ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1"
    let oldRule = "mario ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1"

    check(Permission.rule(uid: 501) == rule, "regola per UID")
    check(Permission.filePath(uid: 501) == "/etc/sudoers.d/stayawake-uid501", "un file per utente")
    check(!(Permission.filePath(uid: 501) as NSString).lastPathComponent.contains("."), "nome del file senza punti (sudo li ignora)")
    check(Permission.legacyPath == "/etc/sudoers.d/stayawake", "percorso del vecchio file")
    check(Permission.legacyRule(userName: "mario") == oldRule, "regola vecchia")

    let script = Permission.installScript(uid: 501, userName: "mario")
    for needle in ["/usr/bin/mktemp /tmp/stayawake.XXXXXX", "/usr/sbin/visudo -cf",
                   "/usr/bin/install -m 440 -o root -g wheel", "/bin/rm -f", "/etc/sudoers.d/stayawake-uid501"] {
        check(script.contains(needle), "lo script di installazione contiene \(needle)")
    }
    check(!script.contains("$(mktemp)"), "niente mktemp senza percorso")

    // Installazione eseguita senza root
    do {
        let dir = tempDir("install")
        let status = runWithoutRoot(script, in: dir)
        let installed = dir + "/stayawake-uid501"
        check(status == 0, "installazione: exit 0")
        check(read(installed) == "# StayAwake\n" + rule + "\n", "installazione: contenuto esatto")
        check(shell("/usr/sbin/visudo", ["-cf", installed]).status == 0, "installazione: visudo accetta il file")
        let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: dir))?.filter { $0.hasPrefix("stayawake.") } ?? ["?"]
        check(leftovers.isEmpty, "installazione: nessun file temporaneo rimasto")
    }

    // Migrazione dal vecchio /etc/sudoers.d/stayawake
    do {
        let mine = tempDir("migra-mio")
        try? (oldRule + "\n").write(toFile: mine + "/stayawake", atomically: true, encoding: .utf8)
        check(runWithoutRoot(script, in: mine) == 0, "migrazione: exit 0")
        check(!FileManager.default.fileExists(atPath: mine + "/stayawake"), "migrazione: il vecchio file mio viene rimosso")

        let other = tempDir("migra-altro")
        let otherRule = Permission.legacyRule(userName: "altro") + "\n"
        try? otherRule.write(toFile: other + "/stayawake", atomically: true, encoding: .utf8)
        check(runWithoutRoot(script, in: other) == 0, "migrazione altrui: exit 0")
        check(read(other + "/stayawake") == otherRule, "migrazione: il vecchio file di un altro utente resta intatto")
    }

    // Nome utente con apice: niente nome nello script, niente migrazione
    do {
        let odd = Permission.installScript(uid: 501, userName: "o'neil")
        check(!odd.contains("o'neil"), "nome con apice: non entra nello script")
        check(!odd.contains("/bin/cat"), "nome con apice: migrazione saltata")
        let dir = tempDir("apice")
        check(runWithoutRoot(odd, in: dir) == 0, "nome con apice: exit 0")
        check(read(dir + "/stayawake-uid501") == "# StayAwake\n" + rule + "\n", "nome con apice: regola installata")
    }

    // Nome con il punto (comune su macOS): migrazione funziona senza esporre il nome nel file,
    // e il nome del file resta senza punti
    do {
        let dotted = Permission.installScript(uid: 501, userName: "mario.rossi")
        let dir = tempDir("punto")
        try? (Permission.legacyRule(userName: "mario.rossi") + "\n").write(toFile: dir + "/stayawake", atomically: true, encoding: .utf8)
        check(runWithoutRoot(dotted, in: dir) == 0, "nome con punto: exit 0")
        check(read(dir + "/stayawake-uid501") == "# StayAwake\n" + rule + "\n", "nome con punto: regola installata")
        check(!FileManager.default.fileExists(atPath: dir + "/stayawake"), "nome con punto: vecchio file migrato")
    }

    // Rimozione con il vecchio file di un altro utente: resta intatto
    do {
        let dir = tempDir("rimuovi-altrui")
        let other = Permission.legacyRule(userName: "altro") + "\n"
        try? (rule + "\n").write(toFile: dir + "/stayawake-uid501", atomically: true, encoding: .utf8)
        try? other.write(toFile: dir + "/stayawake", atomically: true, encoding: .utf8)
        check(runWithoutRoot(Permission.removeScript(uid: 501, userName: "mario"), in: dir) == 0, "rimozione (vecchio file altrui): exit 0")
        check(read(dir + "/stayawake") == other, "rimozione: il vecchio file di un altro utente resta intatto")
    }

    // Rimozione
    do {
        let remove = Permission.removeScript(uid: 501, userName: "mario")
        let dir = tempDir("rimuovi")
        try? (rule + "\n").write(toFile: dir + "/stayawake-uid501", atomically: true, encoding: .utf8)
        try? (oldRule + "\n").write(toFile: dir + "/stayawake", atomically: true, encoding: .utf8)
        try? "#502 x\n".write(toFile: dir + "/stayawake-uid502", atomically: true, encoding: .utf8)
        check(runWithoutRoot(remove, in: dir) == 0, "rimozione: exit 0")
        check(!FileManager.default.fileExists(atPath: dir + "/stayawake-uid501"), "rimozione: tolto il mio file")
        check(!FileManager.default.fileExists(atPath: dir + "/stayawake"), "rimozione: tolto il vecchio file mio")
        check(FileManager.default.fileExists(atPath: dir + "/stayawake-uid502"), "rimozione: il file di un altro utente resta")
    }

    // Lettura di `pmset -g` e ripristino con password (quando la regola è stata tolta a mano)
    check(Permission.parseSleepDisabled(" SleepDisabled\t\t1\n hibernatemode 3"), "pmset: SleepDisabled 1 → disattivato")
    check(!Permission.parseSleepDisabled(" SleepDisabled\t\t0"), "pmset: SleepDisabled 0 → normale")
    check(!Permission.parseSleepDisabled("System-wide power settings:\n hibernatemode 3"), "pmset: riga assente → normale")
    check(Permission.restoreScript == "/usr/bin/pmset -a disablesleep 0", "ripristino con password: solo pmset -a disablesleep 0")

    // Escape AppleScript: andata e ritorno identici, anche con accenti, virgolette e backslash
    do {
        let prompt = "Necesita la contraseña «admin» \"x\" \\ y"
        let source = Permission.appleScriptSource(shell: script, prompt: prompt)
        check(source.contains("with administrator privileges"), "AppleScript: con privilegi di amministratore")
        let shellLiteral = appleScriptLiteral(in: source, after: "do shell script \"")
        let promptLiteral = appleScriptLiteral(in: source, after: "with prompt \"")
        check(shellLiteral.map(appleScriptValue) == script, "AppleScript: lo script torna identico")
        check(promptLiteral.map(appleScriptValue) == prompt, "AppleScript: il prompt torna identico")
    }
}
