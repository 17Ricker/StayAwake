import SwiftUI

// MARK: - Tema “Retro” (di riserva): apparecchio grigio caldo con schermo a punti

enum Retro {
    static let chassis: [Color] = [Color(hex: 0x9A958F), Color(hex: 0x77726D)]
    static let key: [Color] = [Color(hex: 0xE8E5DF), Color(hex: 0xC8C5BF)]
    static let lcd = Color(hex: 0x050505)
    static let dot = Color(hex: 0xDAD8D2)
    static let dotOff = Color(hex: 0x2B2B2A)
    static let orange = Color(hex: 0xE8643A)
    static let text = Color(hex: 0xB4B2AC)
    static let ink = Color(hex: 0x1C1B1A)
}

/// Caratteri 5×7 a matrice di punti.
enum DotFont {
    static let height = 7
    static let glyphs: [Character: [String]] = [
        "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
        "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
        "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
        "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
        "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
        "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
        "6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
        "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
        "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
        "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
        ":": ["0", "0", "1", "0", "1", "0", "0"],
        "-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"]
    ]

    static func cols(_ ch: Character) -> Int { glyphs[ch]?.first?.count ?? 3 }
}

struct DotText: View {
    let text: String
    let pitch: CGFloat
    let color: Color

    private var totalCols: Int {
        let chars = Array(text)
        return chars.map { DotFont.cols($0) }.reduce(0, +) + max(0, chars.count - 1)
    }

    var body: some View {
        Canvas { ctx, _ in
            var x = 0
            for ch in text {
                if let rows = DotFont.glyphs[ch] {
                    for (r, row) in rows.enumerated() {
                        for (col, bit) in row.enumerated() where bit == "1" {
                            let rect = CGRect(x: CGFloat(x + col) * pitch, y: CGFloat(r) * pitch,
                                              width: pitch * 0.8, height: pitch * 0.8)
                            ctx.fill(Path(ellipseIn: rect), with: .color(color))
                        }
                    }
                }
                x += DotFont.cols(ch) + 1
            }
        }
        .frame(width: CGFloat(totalCols) * pitch, height: CGFloat(DotFont.height) * pitch)
        .accessibilityHidden(true)
    }
}

/// Fulmine a punti in cima allo schermo.
private struct PixelBolt: View {
    private let rows = ["0000110", "0001100", "0011000", "0110000", "1111110", "0001100", "0011000", "0110000", "0100000"]

    var body: some View {
        Canvas { ctx, _ in
            for (r, row) in rows.enumerated() {
                for (col, bit) in row.enumerated() where bit == "1" {
                    ctx.fill(Path(ellipseIn: CGRect(x: CGFloat(col) * 4, y: CGFloat(r) * 4, width: 3.2, height: 3.2)),
                             with: .color(Retro.dot))
                }
            }
        }
        .frame(width: 28, height: 36)
        .accessibilityHidden(true)
    }
}

/// Riga di punti che si accendono mentre il timer scorre.
private struct DotBar: View {
    let progress: Double
    static let count = 30

    var body: some View {
        Canvas { ctx, size in
            let pitch = size.width / CGFloat(Self.count)
            for i in 0..<Self.count {
                let on = Double(i + 1) <= progress * Double(Self.count) + 0.001
                let rect = CGRect(x: CGFloat(i) * pitch + pitch * 0.15, y: size.height / 2 - pitch * 0.35,
                                  width: pitch * 0.7, height: pitch * 0.7)
                ctx.fill(Path(ellipseIn: rect), with: .color(on ? Retro.orange : Retro.dotOff))
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}

/// Grana sottile della plastica.
private struct Grain: View {
    var body: some View {
        Canvas { ctx, size in
            var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
            func next() -> Double {
                seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                return Double(seed >> 33) / Double(1 << 31)
            }
            for _ in 0..<1600 {
                let x = next() * size.width
                let y = next() * size.height
                let light = next() > 0.5
                ctx.fill(Path(CGRect(x: x, y: y, width: 1, height: 1)),
                         with: .color(light ? Color.white.opacity(0.08) : Color.black.opacity(0.08)))
            }
        }
        .allowsHitTesting(false)
    }
}

/// Segno in alto a destra: quattro quadratini, uno arancio.
private struct PixelFlag: View {
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { i in
                Rectangle().fill(i == 1 ? Retro.orange : Retro.ink).frame(width: 6, height: 6)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Tasto che si ripete tenendolo premuto.
private struct RepeatKey<Content: View>: View {
    let label: String
    let action: () -> Void
    @ViewBuilder let content: () -> Content
    @State private var timer: Timer?
    @State private var pressed = false

    var body: some View {
        content()
            .brightness(pressed ? -0.08 : 0)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in begin() }
                    .onEnded { _ in end() }
            )
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { action() }
    }

    private func begin() {
        guard !pressed else { return }
        pressed = true
        action()
        timer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { _ in
            Task { @MainActor in
                timer = Timer.scheduledTimer(withTimeInterval: 0.07, repeats: true) { _ in
                    Task { @MainActor in action() }
                }
            }
        }
    }

    private func end() {
        timer?.invalidate()
        timer = nil
        pressed = false
    }
}

// MARK: - Corpo

struct RetroBody: View {
    @ObservedObject var c: Controller

    var body: some View {
        VStack(spacing: 12) {
            RetroDevice(c: c)
            HStack {
                Text(c.t.continuous.uppercased()).font(Face.mono(11)).tracking(1.6).foregroundStyle(Retro.text)
                Spacer()
                RetroSwitch(isOn: c.mode == .indefinite, busy: c.pending == .indefinite, t: c.t) { want in
                    if want { c.startIndefinite() } else { c.stop() }
                }
                .disabled(c.busy && c.pending != .indefinite)
            }
            .padding(.horizontal, 8)
        }
    }
}

private struct RetroDevice: View {
    @ObservedObject var c: Controller

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        ZStack {
            shape.fill(diagonal(Retro.chassis))
            Grain().clipShape(shape)
            shape.strokeBorder(LinearGradient(colors: [Color.white.opacity(0.4), Color.black.opacity(0.3)],
                                              startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2)
            HStack(alignment: .top, spacing: 10) {
                RetroScreen(c: c)
                RetroKeys(c: c).frame(width: 66)
            }
            .padding(12)
        }
        .frame(height: 300)
        .shadow(color: Color.black.opacity(0.5), radius: 16, x: 0, y: 10)
    }
}

private struct RetroScreen: View {
    @ObservedObject var c: Controller

    private var timeText: String {
        switch c.mode {
        case .off: return String(format: "%02d:%02d", c.duration / 60, c.duration % 60)
        case .timed: return Controller.format(c.remaining)
        case .indefinite: return "--:--"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            PixelBolt().padding(.top, 2)
            Spacer(minLength: 6)
            HStack(spacing: 6) {
                Text(c.t.mode.uppercased()).foregroundStyle(Retro.text)
                Text((c.mode == .indefinite ? c.t.continuous : c.t.timer).uppercased()).foregroundStyle(Retro.orange)
            }
            .font(Face.mono(11)).tracking(1.2)
            DotText(text: timeText, pitch: timeText.count > 5 ? 3.9 : 5.0, color: Retro.dot)
                .padding(.vertical, 10)
            if c.mode == .timed {
                DotBar(progress: c.progress).padding(.bottom, 8)
            }
            // Su una riga se entra, altrimenti l'orario va sotto: mai troncato.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) { endLabel; endValue.foregroundStyle(Retro.orange) }
                VStack(spacing: 2) { endLabel; endValue.foregroundStyle(Retro.orange) }
            }
            .font(Face.mono(11)).tracking(1.2)
            Spacer(minLength: 8)
            hint
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Retro.lcd))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(c.summary)
    }

    private var endLabel: some View {
        Text((c.mode == .indefinite ? c.t.duration : c.t.untilCaps).uppercased()).foregroundStyle(Retro.text)
    }

    @ViewBuilder private var endValue: some View {
        switch c.mode {
        case .off: EndClock(minutes: c.duration, locale: c.locale) { Text($0.text.uppercased()) }
        case .timed: Text(TimeText.end(c.endDate ?? Date(), locale: c.locale).text.uppercased())
        case .indefinite: Text(c.t.noLimit.uppercased())
        }
    }

    private var hint: some View {
        let line: Text
        if c.pending != nil {
            line = Text(c.t.retroWaiting)
        } else if c.isActive {
            line = Text("\(c.t.hintPress) \(Image(systemName: "stop.fill")) \(c.t.hintToStop)")
        } else {
            line = Text("\(c.t.hintPress) \(Image(systemName: "checkmark")) \(c.t.hintToStart)")
        }
        return line
            .font(Face.mono(10.5))
            .foregroundStyle(Retro.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .overlay(Capsule().strokeBorder(Retro.orange.opacity(0.7), lineWidth: 1))
    }
}

private struct RetroKeys: View {
    @ObservedObject var c: Controller

    var body: some View {
        VStack(spacing: 8) {
            HStack { Spacer(); PixelFlag() }.frame(height: 14)
            Groove(dark: Color.black.opacity(0.28), light: Color.white.opacity(0.22))
            upDown
            Groove(dark: Color.black.opacity(0.28), light: Color.white.opacity(0.22))
            action
            Spacer(minLength: 0)
            Text("STAYAWAKE").font(Face.mono(8.5)).tracking(1.2).foregroundStyle(Retro.ink.opacity(0.7))
        }
    }

    private var upDown: some View {
        let shape = RoundedRectangle(cornerRadius: 27, style: .continuous)
        return VStack(spacing: 0) {
            RepeatKey(label: c.t.moreTime, action: { c.nudge(5) }) { keyFace("chevron.up") }
            Rectangle().fill(Color.black.opacity(0.22)).frame(height: 1)
            RepeatKey(label: c.t.lessTime, action: { c.nudge(-5) }) { keyFace("chevron.down") }
        }
        .frame(width: 54, height: 104)
        .background(vertical(Retro.key))
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.white.opacity(0.55), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.35), radius: 4, x: 0, y: 3)
        .opacity(c.mode == .indefinite ? 0.45 : 1)
        .allowsHitTesting(c.mode != .indefinite)
    }

    private func keyFace(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Color(hex: 0x6A6863))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var action: some View {
        Button { c.isActive ? c.stop() : c.startTimed() } label: {
            ZStack {
                Circle().fill(LinearGradient(colors: [Color(hex: 0xF0764A), Color(hex: 0xD9552B)],
                                             startPoint: .top, endPoint: .bottom))
                Circle().strokeBorder(Retro.ink.opacity(0.55), style: StrokeStyle(lineWidth: 1.2, dash: [1.2, 2.6]))
                    .padding(5)
                if c.pending == .timed {
                    Spinner(onLight: true)
                } else {
                    Image(systemName: c.isActive ? "stop.fill" : "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Retro.ink)
                }
            }
            .frame(width: 56, height: 56)
            .overlay(FocusRing(radius: 28))
        }
        .buttonStyle(PressScaleStyle())
        .keyboardShortcut(.defaultAction)
        .allowsHitTesting(!c.busy)
        .accessibilityLabel(c.isActive ? c.t.stop : c.t.startTimer)
    }
}

/// Interruttore a slitta, come sui vecchi apparecchi.
private struct RetroSwitch: View {
    let isOn: Bool
    let busy: Bool
    let t: Strings
    let action: (Bool) -> Void

    var body: some View {
        Button { action(!isOn) } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule().fill(Retro.lcd)
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
                HStack {
                    if isOn { Circle().fill(Retro.orange).frame(width: 6, height: 6); Spacer() }
                    else { Spacer(); Circle().fill(Retro.dotOff).frame(width: 6, height: 6) }
                }
                .padding(.horizontal, 11)
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(vertical(Retro.key))
                    .overlay(grip)
                    .frame(width: 30, height: 22)
                    .shadow(color: Color.black.opacity(0.4), radius: 2, x: 0, y: 1)
                    .padding(3)
            }
            .frame(width: 72, height: 28)
            .overlay(FocusRing(radius: 14))
        }
        .buttonStyle(PressScaleStyle())
        .animation(.smooth(duration: 0.2), value: isOn)
        .accessibilityLabel(t.continuous)
        .accessibilityValue(isOn ? t.toggleOn : t.toggleOff)
        .accessibilityAddTraits(.isToggle)
    }

    private var grip: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { _ in
                Rectangle().fill(Color.black.opacity(0.25)).frame(width: 1.2, height: 12)
            }
        }
    }
}
