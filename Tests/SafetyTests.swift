import Foundation

/// Avvia `/bin/sleep <s>` come finta app.
private func fakeApp(seconds: Int) -> Process {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/sleep")
    p.arguments = ["\(seconds)"]
    try? p.run()
    return p
}

func safetyTests() {
    // Batteria: percentuale da Current/Max, anche quando Max non è 100
    check(Battery.percent(current: 50, max: 100) == 50, "batteria 50/100 = 50%")
    check(Battery.percent(current: 2000, max: 4000) == 50, "batteria 2000/4000 mAh = 50%")
    check(Battery.percent(current: 19, max: 100) == 19, "batteria 19/100 = 19%")
    check(Battery.percent(current: 7, max: 0) == 7, "batteria senza Max: usa Current")

    // Temperatura: si ferma solo a «critico»
    check(Thermal.shouldStop(.critical), "temperatura critica: stop")
    check(!Thermal.shouldStop(.serious), "temperatura seria: continua")
    check(!Thermal.shouldStop(.fair), "temperatura discreta: continua")
    check(!Thermal.shouldStop(.nominal), "temperatura normale: continua")

    // Prima di attivare: batteria e temperatura (ognuna solo se la sua protezione è attiva)
    do {
        let t = Strings.for(.it)
        check(StartCheck.blocker(stopOnLowBattery: true, batteryLow: true, stopOnHeat: true, thermal: .nominal, t: t) == t.batteryTooLow(Battery.threshold),
              "attivazione: batteria bassa blocca")
        check(StartCheck.blocker(stopOnLowBattery: true, batteryLow: false, stopOnHeat: true, thermal: .critical, t: t) == t.tooHotToStart,
              "attivazione: Mac troppo caldo blocca")
        check(StartCheck.blocker(stopOnLowBattery: true, batteryLow: false, stopOnHeat: false, thermal: .critical, t: t) == nil,
              "attivazione: protezione temperatura spenta non blocca")
        check(StartCheck.blocker(stopOnLowBattery: false, batteryLow: true, stopOnHeat: true, thermal: .serious, t: t) == nil,
              "attivazione: batteria bassa con protezione spenta e temperatura seria non blocca")
    }

    // Sentinella: quando l'app muore esegue il comando finale
    check(Sentinel.script(appPID: 123, finalCommand: "X").hasPrefix("while /bin/kill -0 123 "), "sentinella: attende il PID dell'app")
    do {
        let dir = tempDir("sentinella")
        let flag = dir + "/flag"
        let app = fakeApp(seconds: 1)
        let sentinel = Sentinel.start(appPID: app.processIdentifier, finalCommand: "/bin/echo fatto > '\(flag)'")
        check(sentinel != nil, "sentinella: avviata")
        app.waitUntilExit()
        Thread.sleep(forTimeInterval: 4)
        check((try? String(contentsOfFile: flag, encoding: .utf8)) == "fatto\n", "sentinella: dopo la morte dell'app esegue il ripristino")
    }

    // Fine a fine: questo stesso eseguibile, in modalità figlio, fa da «app»: avvia la sentinella su di sé
    // e muore con SIGKILL. La sentinella deve sopravvivergli e ripristinare.
    do {
        let dir = tempDir("crash")
        let flag = dir + "/flag"
        let child = Process()
        child.executableURL = URL(fileURLWithPath: Bundle.main.executablePath ?? CommandLine.arguments[0])
        child.arguments = ["--sentinel-child", flag]
        child.standardOutput = FileHandle.nullDevice
        try? child.run()
        child.waitUntilExit()   // raccoglie il figlio morto, come fa launchd con l'app vera
        Thread.sleep(forTimeInterval: 4)
        check(child.terminationReason == .uncaughtSignal, "crash: l'app finta è morta per un segnale (SIGKILL)")
        check((try? String(contentsOfFile: flag, encoding: .utf8)) == "ripristinato\n", "crash: la sentinella sopravvive all'app e ripristina")
    }

    // stopAll: ferma le sentinelle (che così non eseguono nulla) e non tocca altri processi.
    // Nota: ferma anche la sentinella di uno StayAwake attivo su questo Mac, che si ricrea al prossimo avvio.
    do {
        let dir = tempDir("stop")
        let flag = dir + "/flag2"
        let app = fakeApp(seconds: 30)
        let sentinel = Sentinel.start(appPID: app.processIdentifier, finalCommand: "/bin/echo no > '\(flag)'")
        Thread.sleep(forTimeInterval: 0.5)
        Sentinel.stopAll()
        Thread.sleep(forTimeInterval: 1)
        check(sentinel.map { !$0.isRunning } ?? false, "stopAll: la sentinella è ferma")
        check(app.isRunning, "stopAll: gli altri processi non vengono toccati")
        app.terminate()
        app.waitUntilExit()
        Thread.sleep(forTimeInterval: 3)
        check(!FileManager.default.fileExists(atPath: flag), "stopAll: la sentinella fermata non esegue il ripristino")
    }
}
