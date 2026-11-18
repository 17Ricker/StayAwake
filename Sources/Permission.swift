import Foundation

/// Il permesso di cambiare lo sleep senza password: una regola sudoers **per utente**, limitata a
/// `pmset -a disablesleep 0|1`. È l'unico punto dell'app che fa girare qualcosa come root.
///
/// Regole per ciò che gira come root:
/// - tocca solo il proprio file temporaneo in /tmp (sticky bit) e /etc/sudoers.d/;
/// - solo percorsi assoluti, così non dipende dal PATH ereditato;
/// - nessun dato non controllato dentro lo script (UID numerico; il nome utente solo se semplice).
enum Permission {
    /// File usato dalle versioni precedenti (uno solo per tutto il Mac, con il nome utente).
    static let legacyPath = "/etc/sudoers.d/stayawake"

    private static let commands = "/usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1"

    /// Regola per UID (`#501 …`): visudo la legge come utente, non come commento.
    static func rule(uid: uid_t) -> String { "#\(uid) ALL=(root) NOPASSWD: \(commands)" }

    /// Un file per utente. Niente punti nel nome: sudo ignora i file di sudoers.d che li contengono.
    static func filePath(uid: uid_t) -> String { "/etc/sudoers.d/stayawake-uid\(uid)" }

    /// La regola scritta dalle versioni precedenti, per riconoscerla e toglierla.
    static func legacyRule(userName: String) -> String { "\(userName) ALL=(root) NOPASSWD: \(commands)" }

    /// Nome utente che si può scrivere in uno script: niente apici, spazi, `%gruppo`, `#uid`, `ALL`.
    static func isSafeUserName(_ name: String) -> Bool {
        name.range(of: #"^[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil && name.uppercased() != "ALL"
    }

    /// Condizione shell «il vecchio file esiste ed è esattamente la mia regola»; nil se il nome non è sicuro.
    private static func legacyIsMine(userName: String) -> String? {
        guard isSafeUserName(userName) else { return nil }
        return "[ -f \(legacyPath) ] && [ \"$(/bin/cat \(legacyPath))\" = '\(legacyRule(userName: userName))' ]"
    }

    /// Script (da eseguire come root) che installa la regola di questo utente e, se è riuscito,
    /// toglie il vecchio file solo se contiene esattamente la vecchia regola di questo utente.
    static func installScript(uid: uid_t, userName: String) -> String {
        let comment = "# StayAwake"
        var script = "tmp=$(/usr/bin/mktemp /tmp/stayawake.XXXXXX)"
            + " && printf '%s\\n' '\(comment)' '\(rule(uid: uid))' > \"$tmp\""
            + " && /usr/sbin/visudo -cf \"$tmp\" >/dev/null"
            + " && /usr/bin/install -m 440 -o root -g wheel \"$tmp\" \(filePath(uid: uid)); rc=$?; /bin/rm -f \"$tmp\"; "
        if let mine = legacyIsMine(userName: userName) {
            script += "if [ $rc -eq 0 ] && \(mine); then /bin/rm -f \(legacyPath); fi; "
        }
        return script + "exit $rc"
    }

    /// Script (da eseguire come root) che toglie la regola di questo utente (e il vecchio file, se è suo).
    static func removeScript(uid: uid_t, userName: String) -> String {
        var script = "/bin/rm -f \(filePath(uid: uid))"
        if let mine = legacyIsMine(userName: userName) {
            script += "; if \(mine); then /bin/rm -f \(legacyPath); fi"
        }
        return script
    }

    /// Escape per un letterale stringa AppleScript: backslash e virgolette.
    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }

    /// Sorgente AppleScript che chiede la password admin (prompt del sistema) ed esegue lo script come root.
    static func appleScriptSource(shell: String, prompt: String) -> String {
        "do shell script \"\(escape(shell))\" with administrator privileges with prompt \"\(escape(prompt))\""
    }

    // MARK: Azioni sul sistema

    /// La regola di questo utente esiste **e** funziona. Il file va controllato: altrimenti credenziali
    /// admin ancora in cache farebbero sembrare valido un permesso che non c'è.
    static func isGranted() -> Bool {
        FileManager.default.fileExists(atPath: filePath(uid: getuid()))
            && run("/usr/bin/sudo", ["-n", "-l", "/usr/bin/pmset", "-a", "disablesleep", "1"])
    }

    /// `sudo -n pmset -a disablesleep 0|1`: senza password, riesce solo con la regola installata.
    @discardableResult
    static func setSleepDisabled(_ on: Bool) -> Bool {
        run("/usr/bin/sudo", ["-n", "/usr/bin/pmset", "-a", "disablesleep", on ? "1" : "0"])
    }

    /// Ripristino quando la regola non c'è più (tolta a mano): solo questo comando, con la password.
    static let restoreScript = "/usr/bin/pmset -a disablesleep 0"

    /// `pmset -g` mostra «SleepDisabled 1» quando lo sleep è disattivato.
    static func parseSleepDisabled(_ pmsetOutput: String) -> Bool {
        for line in pmsetOutput.split(separator: "\n") where line.contains("SleepDisabled") {
            return line.split(whereSeparator: \.isWhitespace).last == "1"
        }
        return false
    }

    /// Lo sleep del Mac è disattivato adesso?
    static func isSleepDisabled() -> Bool { parseSleepDisabled(output("/usr/bin/pmset", ["-g"])) }

    /// Riporta lo sleep alla normalità chiedendo la password (macOS mostra `prompt`).
    static func restoreWithPassword(prompt: String) -> Bool { admin(restoreScript, prompt: prompt) }

    /// Installa la regola (macOS chiede la password admin con `prompt`).
    static func install(prompt: String) -> Bool {
        admin(installScript(uid: getuid(), userName: NSUserName()), prompt: prompt)
    }

    /// Toglie la regola (macOS chiede la password admin con `prompt`).
    static func remove(prompt: String) -> Bool {
        admin(removeScript(uid: getuid(), userName: NSUserName()), prompt: prompt)
    }

    private static func admin(_ shell: String, prompt: String) -> Bool {
        run("/usr/bin/osascript", ["-e", appleScriptSource(shell: shell, prompt: prompt)])
    }

    private static func output(_ path: String, _ args: [String]) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return "" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }

    private static func run(_ path: String, _ args: [String]) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        p.standardInput = FileHandle.nullDevice
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return false }
        p.waitUntilExit()
        return p.terminationStatus == 0
    }
}
