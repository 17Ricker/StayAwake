import SwiftUI
import AppKit

// MARK: - Tema “Modern”: grigio morbido, superfici in rilievo e incassate
// È il primo stile dell'app (pillola scura con i tempi rapidi, rotella ore/minuti, schede in rilievo,
// tasti a puntini). Si sceglie da Impostazioni → Stile.

enum ModernPalette {
    static let ground: [Color] = [Color(hex: 0xC8C8CA), Color(hex: 0xB7B7BA)]
    static let card: [Color] = [Color(hex: 0xD4D4D6), Color(hex: 0xC6C6C9)]
    static let key: [Color] = [Color(hex: 0xE2E6E4), Color(hex: 0xD2D8D5)]
    static let inset = Color(hex: 0xB0B0B3)
    static let dark: [Color] = [Color(hex: 0x313134), Color(hex: 0x202022)]
    static let darkKey: [Color] = [Color(hex: 0x666669), Color(hex: 0x505053)]
    static let ink = Color(hex: 0x1B1B1D)
    static let inkSoft = Color(hex: 0x44444A)
    static let onDark = Color(hex: 0xF4F4F5)
    static let onDarkSoft = Color(hex: 0xB9B9BE)
    static let timed = Color(hex: 0xF2C230)
    static let indefinite = Color(hex: 0xE5484D)
    static let stopIcon = Color(hex: 0xFF6A6E)
    static let errorInk = Color(hex: 0x7E0F14)
    static let focus = Color(hex: 0x1B1B1D).opacity(0.85)
}

private let modernEdgeLight = LinearGradient(colors: [Color.white.opacity(0.6), Color.white.opacity(0)],
                                             startPoint: .top, endPoint: .bottom)

// MARK: Superfici

/// Superficie in rilievo: luce in alto a sinistra, ombra morbida in basso a destra.
struct ModernRaised: ViewModifier {
    var radius: CGFloat
    var fill: [Color]
    var depth: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background(
                shape.fill(vertical(fill))
                    .shadow(color: Color.white.opacity(0.35 * depth + 0.1), radius: 5 * depth + 1, x: -2 * depth, y: -2 * depth)
                    .shadow(color: Color.black.opacity(0.17 * depth + 0.04), radius: 9 * depth + 1, x: 2 * depth, y: 4 * depth)
            )
            .overlay(shape.strokeBorder(modernEdgeLight, lineWidth: 1))
    }
}

/// Superficie incassata: ombra interna in alto a sinistra.
struct ModernSunken: ViewModifier {
    var radius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let rim = LinearGradient(colors: [Color.black.opacity(0.16), Color.white.opacity(0.45)],
                                 startPoint: .top, endPoint: .bottom)
        content.background(
            shape.fill(ModernPalette.inset)
                .overlay(
                    shape.stroke(Color.black.opacity(0.30), lineWidth: 5)
                        .blur(radius: 3)
                        .offset(x: 1, y: 3)
                        .clipShape(shape)
                )
                .overlay(shape.strokeBorder(rim, lineWidth: 1))
        )
    }
}

/// Contorno a puntini, per le azioni secondarie.
struct ModernDotted: ViewModifier {
    var radius: CGFloat

    func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(ModernPalette.ink.opacity(0.5),
                              style: StrokeStyle(lineWidth: 1.3, lineCap: .round, dash: [0.1, 3.6]))
        )
    }
}

extension View {
    func mRaised(radius: CGFloat = 22, fill: [Color] = ModernPalette.card, depth: CGFloat = 1) -> some View {
        modifier(ModernRaised(radius: radius, fill: fill, depth: depth))
    }
    func mSunken(radius: CGFloat = 14) -> some View { modifier(ModernSunken(radius: radius)) }
    func mDotted(radius: CGFloat = 16) -> some View { modifier(ModernDotted(radius: radius)) }
}

/// Superficie scura (pillola, tasto principale, icona dell'app).
struct ModernDarkSurface: View {
    var radius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let rim = LinearGradient(colors: [Color.white.opacity(0.22), Color.white.opacity(0.02)],
                                 startPoint: .top, endPoint: .bottom)
        shape.fill(vertical(ModernPalette.dark))
            .overlay(shape.strokeBorder(rim, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.28), radius: 8, x: 0, y: 5)
    }
}

// MARK: Pulsanti

struct ModernDarkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { ModernDarkButtonBody(configuration: configuration) }
}

private struct ModernDarkButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        configuration.label
            .font(Face.demi(16))
            .foregroundStyle(ModernPalette.onDark)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(ModernDarkSurface(radius: 16))
            .overlay(FocusRing(radius: 16, color: ModernPalette.focus))
            .brightness(configuration.isPressed ? 0.08 : 0)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(enabled ? 1 : 0.42)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct ModernDottedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { ModernDottedButtonBody(configuration: configuration) }
}

private struct ModernDottedButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var enabled
    @State private var hover = false

    var body: some View {
        let wash = configuration.isPressed ? 0.10 : (hover ? 0.05 : 0)
        configuration.label
            .font(Face.demi(15))
            .foregroundStyle(ModernPalette.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(ModernPalette.ink.opacity(wash)))
            .mDotted(radius: 16)
            .overlay(FocusRing(radius: 16, color: ModernPalette.focus))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .onHover { hover = $0 }
            .opacity(enabled ? 1 : 0.42)
    }
}

/// Riga di menu: evidenziata al passaggio del mouse, con anello di focus.
struct ModernRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { ModernRowButtonBody(configuration: configuration) }
}

private struct ModernRowButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @State private var hover = false

    var body: some View {
        let wash = configuration.isPressed ? 0.10 : (hover ? 0.06 : 0)
        configuration.label
            .font(Face.medium(14))
            .foregroundStyle(ModernPalette.ink)
            .padding(.horizontal, 10)
            .frame(minHeight: 40)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(ModernPalette.ink.opacity(wash)))
            .overlay(FocusRing(radius: 12, color: ModernPalette.focus))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onHover { hover = $0 }
    }
}

/// Interruttore: pista incassata e pomello in rilievo.
struct ModernKnob: View {
    let isOn: Bool

    var body: some View {
        ZStack {
            Capsule().fill(ModernPalette.inset)
                .overlay(Capsule().strokeBorder(Color.black.opacity(0.18), lineWidth: 1))
            Capsule().fill(vertical(ModernPalette.dark)).opacity(isOn ? 1 : 0)
            Circle().fill(vertical(ModernPalette.key))
                .frame(width: 18, height: 18)
                .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                .offset(x: isOn ? 9 : -9)
        }
        .frame(width: 42, height: 24)
        .animation(.smooth(duration: 0.18), value: isOn)
    }
}

private struct ModernToggleRow: View {
    let icon: String
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool
    let t: Strings

    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 15)).frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                    if let subtitle {
                        Text(subtitle).font(Face.regular(12)).foregroundStyle(ModernPalette.inkSoft)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                ModernKnob(isOn: isOn)
            }
        }
        .buttonStyle(ModernRowButtonStyle())
        .accessibilityValue(isOn ? t.toggleOn : t.toggleOff)
        .accessibilityAddTraits(.isToggle)
    }
}

/// Selettore a segmenti a tutta larghezza: pista incassata, voce scelta scura.
struct ModernSegmented<T: Hashable & Identifiable>: View {
    let options: [T]
    let name: (T) -> String
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options) { option in
                let chosen = option == selection
                Button { selection = option } label: {
                    Text(name(option))
                        .font(Face.medium(12.5))
                        .foregroundStyle(chosen ? ModernPalette.onDark : ModernPalette.inkSoft)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(Capsule().fill(chosen ? vertical(ModernPalette.dark) : vertical([Color.clear, Color.clear])))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(chosen ? .isSelected : [])
            }
        }
        .padding(2)
        .mSunken(radius: 16)
    }
}

// MARK: Rotella

/// Rotella a scorrimento con tre righe visibili; `values` sono i soli valori ammessi.
struct ModernDrum: View {
    @Binding var value: Int
    let values: [Int]
    let unit: String
    let spoken: String
    @State private var position: Int?
    @FocusState private var focused: Bool
    static let rowH: CGFloat = 44

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            wheel
            Text(unit).font(Face.medium(13)).foregroundStyle(ModernPalette.inkSoft)
                .lineLimit(1).minimumScaleFactor(0.6).frame(width: 28, alignment: .leading)
        }
        .overlay(FocusRingIf(active: focused, radius: 12, color: ModernPalette.focus))
        .onAppear { position = value }
        .onChange(of: position) { _, new in
            guard let new, new != value else { return }
            value = new
            if value != new { position = value }          // valore corretto dai limiti: riallinea la rotella
        }
        .onChange(of: value) { _, new in
            if position != new { withAnimation(.smooth(duration: 0.25)) { position = new } }
        }
        // Tastiera: frecce su/giù spostano la selezione come la rotella.
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onKeyPress(.upArrow) { step(-1); return .handled }
        .onKeyPress(.downArrow) { step(1); return .handled }
        // VoiceOver: un solo elemento regolabile.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
        .accessibilityValue("\(value)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: step(1)
            case .decrement: step(-1)
            @unknown default: break
            }
        }
    }

    private func row(_ n: Int?) -> some View {
        let selected = n == value
        return Text(n.map { String(format: "%02d", $0) } ?? "")
            .font(selected ? Face.medium(30) : Face.regular(30))
            .foregroundStyle(selected ? ModernPalette.ink : ModernPalette.inkSoft)
            .frame(maxWidth: .infinity)
            .frame(height: Self.rowH)
    }

    private var fade: LinearGradient {
        LinearGradient(stops: [
            .init(color: Color.black.opacity(0.0), location: 0.0),
            .init(color: Color.black.opacity(0.45), location: 0.2),
            .init(color: Color.black, location: 0.4),
            .init(color: Color.black, location: 0.6),
            .init(color: Color.black.opacity(0.45), location: 0.8),
            .init(color: Color.black.opacity(0.0), location: 1.0)
        ], startPoint: .top, endPoint: .bottom)
    }

    #if PREVIEW && !LIVEWHEEL
    // Anteprima offline: niente ScrollView, solo tre righe statiche.
    private var neighbours: [Int?] {
        guard let i = values.firstIndex(of: value) else { return [nil, value, nil] }
        return [i > 0 ? values[i - 1] : nil, value, i < values.count - 1 ? values[i + 1] : nil]
    }

    private var wheel: some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { row(neighbours[$0]) }
        }
        .frame(width: 56, height: Self.rowH * 3)
        .mask(fade)
    }
    #else
    private var wheel: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(values, id: \.self) { n in
                    row(n).contentShape(Rectangle()).onTapGesture { value = n }.id(n)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $position, anchor: .center)
        .contentMargins(.vertical, Self.rowH, for: .scrollContent)
        .frame(width: 56, height: Self.rowH * 3)
        .mask(fade)
    }
    #endif

    private func step(_ d: Int) {
        guard let i = values.firstIndex(of: value) else { return }
        value = values[min(values.count - 1, max(0, i + d))]
    }
}

// MARK: Pannello durata (da fermo)

struct ModernPreset: Identifiable {
    let number: String, unit: String, spoken: String, minutes: Int
    var id: Int { minutes }
    static func all(_ t: Strings) -> [ModernPreset] {
        [15, 30, 60, 120].map { m in
            m < 60
                ? ModernPreset(number: "\(m)", unit: t.minutesUnit, spoken: t.durationSpoken(m), minutes: m)
                : ModernPreset(number: "\(m / 60)", unit: t.hoursUnit(m / 60), spoken: t.durationSpoken(m), minutes: m)
        }
    }
}

private struct ModernPresetKey: View {
    let preset: ModernPreset
    let selected: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text(preset.number).font(Face.medium(18))
                Text(preset.unit).font(Face.regular(10))
            }
            .foregroundStyle(selected ? ModernPalette.onDark : ModernPalette.onDarkSoft)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(keyBackground)
            .overlay(FocusRing(radius: 14, color: ModernPalette.focus))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .accessibilityLabel(preset.spoken)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder private var keyBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        if selected {
            shape.fill(vertical(ModernPalette.darkKey))
                .overlay(shape.strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
        } else if hover {
            shape.fill(Color.white.opacity(0.08))
        } else {
            Color.clear
        }
    }
}

private struct ModernRail: View {
    @ObservedObject var c: Controller

    var body: some View {
        VStack(spacing: 4) {
            ForEach(ModernPreset.all(c.t)) { p in
                ModernPresetKey(preset: p, selected: c.duration == p.minutes) { c.setDuration(p.minutes) }
            }
        }
        .padding(6)
        .frame(width: 58)
        .frame(maxHeight: .infinity)
        .background(ModernDarkSurface(radius: 22))
    }
}

private struct ModernPicker: View {
    @ObservedObject var c: Controller

    private static let hourValues = Array(0...24)
    private static let minuteValues = Array(stride(from: 0, through: 55, by: 5))

    private var hours: Binding<Int> {
        Binding(get: { c.duration / 60 }, set: { c.setDuration($0 * 60 + c.duration % 60) })
    }

    private var minutes: Binding<Int> {
        Binding(get: { c.duration % 60 }, set: { c.setDuration((c.duration / 60) * 60 + $0) })
    }

    var body: some View {
        HStack(spacing: 8) {
            ModernRail(c: c)
            durationCard
        }
    }

    private var durationCard: some View {
        VStack(spacing: 6) {
            // Il badge con l'orario non si tronca mai: se non entra accanto a «Durata», va sotto.
            ViewThatFits(in: .horizontal) {
                HStack {
                    durationLabel
                    Spacer(minLength: 4)
                    endBadge
                }
                VStack(alignment: .leading, spacing: 4) {
                    durationLabel
                    endBadge
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 0)
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.clear)
                    .frame(height: ModernDrum.rowH)
                    .mRaised(radius: 14, fill: ModernPalette.key, depth: 0.45)
                HStack(spacing: 6) {
                    ModernDrum(value: hours, values: Self.hourValues, unit: c.t.hoursUnit(2), spoken: c.t.hoursSpoken)
                    ModernDrum(value: minutes, values: Self.minuteValues, unit: c.t.minutesUnit, spoken: c.t.minutesSpoken)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .mRaised()
    }

    private var durationLabel: some View {
        Text(c.t.duration).font(Face.medium(14)).foregroundStyle(ModernPalette.inkSoft)
    }

    private var endBadge: some View {
        EndClock(minutes: c.duration, locale: c.locale) { time in
            Text(c.t.untilTime(time.text))
                .font(Face.medium(12))
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(ModernPalette.inkSoft)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(Color.black.opacity(0.08)))
        }
    }
}

// MARK: Pannello stato (da attivo)

private struct ModernStatus: View {
    @ObservedObject var c: Controller

    private var tint: Color { c.mode == .timed ? ModernPalette.timed : ModernPalette.indefinite }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(c.mode == .timed ? c.t.timerActive : c.t.continuous)
                .font(Face.medium(14)).foregroundStyle(ModernPalette.inkSoft)
            Spacer(minLength: 0)
            bigValue
            Spacer(minLength: 0)
            badge
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .mRaised()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(c.mode == .timed
            ? c.t.remaining(Controller.format(c.remaining))
            : c.t.activeNoLimit)
    }

    @ViewBuilder private var bigValue: some View {
        if c.mode == .timed {
            let text = Controller.format(c.remaining)
            Digits(text: text, size: text.count > 5 ? 50 : 66)
        } else {
            Image(systemName: "infinity").font(.system(size: 62, weight: .light))
        }
    }

    private var badge: some View {
        HStack(spacing: 7) {
            Circle().fill(tint).frame(width: 7, height: 7)
            Text(c.mode == .timed ? badgeEnd : c.t.noEnd).font(Face.medium(13))
        }
        .padding(.horizontal, 11).padding(.vertical, 5)
        .background(Capsule().fill(tint.opacity(0.4)))
        .overlay(Capsule().strokeBorder(tint.opacity(0.75), lineWidth: 1))
    }

    private var badgeEnd: String {
        guard let end = c.endDate else { return "" }
        return c.t.untilTime(TimeText.end(end, locale: c.locale).text).capitalizedFirst
    }
}

// MARK: Intestazione

private struct ModernHeader: View {
    @ObservedObject var c: Controller

    private var tint: Color {
        switch c.mode {
        case .off: return ModernPalette.onDark
        case .timed: return ModernPalette.timed
        case .indefinite: return ModernPalette.indefinite
        }
    }

    private var status: String {
        switch c.mode {
        case .off: return c.t.statusOff
        case .timed: return c.t.statusTimer
        case .indefinite: return c.t.statusContinuous
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: c.isActive ? "bolt.fill" : "bolt")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 46, height: 46)
                .background(ModernDarkSurface(radius: 15))
            VStack(alignment: .leading, spacing: 1) {
                Text("StayAwake").font(Face.demi(18)).foregroundStyle(ModernPalette.ink)
                Text(status).font(Face.regular(13)).foregroundStyle(ModernPalette.inkSoft)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: Popover

struct ModernPopover: View {
    @ObservedObject var c: Controller
    @Binding var showSettings: Bool

    var body: some View {
        VStack(spacing: 14) {
            ModernHeader(c: c)

            Group {
                if c.isActive { ModernStatus(c: c).transition(.opacity) } else { ModernPicker(c: c).transition(.opacity) }
            }
            .frame(height: 208)
            .animation(.smooth(duration: 0.28), value: c.isActive)

            controls
            messages
            if !c.hasPermission && !c.isActive { note }
            Groove(dark: ModernPalette.ink.opacity(0.14), light: Color.white.opacity(0.45))
            footer
            if showSettings { settings }
        }
        .padding(14)
        .frame(width: 300)
        .background(ground)
        .foregroundStyle(ModernPalette.ink)
        .environment(\.colorScheme, .light)
    }

    private var ground: some View {
        ZStack {
            vertical(ModernPalette.ground)
            RadialGradient(colors: [Color.white.opacity(0.28), Color.white.opacity(0)],
                           center: .topLeading, startRadius: 0, endRadius: 320)
        }
    }

    // MARK: Pulsanti principali

    @ViewBuilder private var controls: some View {
        VStack(spacing: 8) {
            switch c.mode {
            case .off:
                Button { c.startTimed() } label: { label(c.t.startTimer, icon: "timer", for: .timed) }
                    .buttonStyle(ModernDarkButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .allowsHitTesting(!c.busy)
                    .disabled(c.busy && c.pending != .timed)
                Button { c.startIndefinite() } label: { label(c.t.continuous, icon: "infinity", for: .indefinite) }
                    .buttonStyle(ModernDottedButtonStyle())
                    .allowsHitTesting(!c.busy)
                    .disabled(c.busy && c.pending != .indefinite)
            case .timed:
                stopButton
                Button { c.extend(by: 1800) } label: { label(c.t.add30, icon: "plus", for: nil) }
                    .buttonStyle(ModernDottedButtonStyle())
            case .indefinite:
                Text(c.t.staysOnUntilStopped)
                    .font(Face.regular(13)).foregroundStyle(ModernPalette.inkSoft)
                    .frame(maxWidth: .infinity, minHeight: 44)
                stopButton
            }
        }
    }

    private var stopButton: some View {
        Button { c.stop() } label: {
            HStack(spacing: 8) {
                Image(systemName: "stop.fill").font(.system(size: 14)).foregroundStyle(ModernPalette.stopIcon)
                Text(c.t.stop)
            }
        }
        .buttonStyle(ModernDarkButtonStyle())
        .keyboardShortcut(.defaultAction)
    }

    private func label(_ text: String, icon: String, for target: Controller.Mode?) -> some View {
        HStack(spacing: 8) {
            if let target, c.pending == target {
                Spinner()
                Text(c.t.waitingPassword)
            } else {
                Image(systemName: icon).font(.system(size: 15))
                Text(text)
            }
        }
    }

    // MARK: Messaggi e nota

    @ViewBuilder private var messages: some View {
        if let e = c.error {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(ModernPalette.errorInk)
                    Text(e).foregroundStyle(ModernPalette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button { c.dismissMessage() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(ModernPalette.inkSoft)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(c.t.stop)
                }
                if c.needsManualRestore {
                    Button { c.retryRestoreSleep() } label: {
                        HStack(spacing: 6) {
                            if c.restoringSleep { Spinner() }
                            Text(c.restoringSleep ? c.t.waitingPassword : c.t.restoreSleepNow)
                                .font(Face.demi(12))
                        }
                        .foregroundStyle(ModernPalette.onDark)
                        .padding(.horizontal, 12)
                        .frame(height: 28)
                        .background(Capsule().fill(vertical(ModernPalette.dark)))
                    }
                    .buttonStyle(.plain)
                    .disabled(c.busy)
                }
            }
            .font(Face.medium(12.5))
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(12)
            .mSunken(radius: 14)
        } else if let n = c.notice {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle").foregroundStyle(ModernPalette.inkSoft)
                Text(n).foregroundStyle(ModernPalette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button { c.dismissMessage() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ModernPalette.inkSoft)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(c.t.stop)
            }
            .font(Face.medium(12.5))
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(12)
            .mSunken(radius: 14)
        }
    }

    private var note: some View {
        VStack(spacing: 2) {
            Text(c.t.lidNote)
            Text(c.t.firstTimePassword)
        }
        .font(Face.regular(12))
        .foregroundStyle(ModernPalette.inkSoft)
        .multilineTextAlignment(.center)
    }

    // MARK: Piede e impostazioni

    private var footer: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.smooth(duration: 0.25)) { showSettings.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15))
                        .foregroundStyle(ModernPalette.onDark)
                        .frame(width: 32, height: 32)
                        .background(ModernDarkSurface(radius: 11))
                    Text(c.t.settings).fixedSize()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(ModernPalette.inkSoft)
                        .rotationEffect(.degrees(showSettings ? 180 : 0))
                }
            }
            .buttonStyle(ModernRowButtonStyle())
            .accessibilityValue(showSettings ? c.t.settingsOpen : c.t.settingsClosed)
            Spacer(minLength: 0)
            Button { NSApplication.shared.terminate(nil) } label: {
                HStack(spacing: 8) {
                    Text(c.t.quit).fixedSize()
                    Text("⌘Q")
                        .font(Face.medium(11))
                        .foregroundStyle(ModernPalette.inkSoft)
                        .fixedSize()
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Capsule().fill(Color.black.opacity(0.10)))
                }
            }
            .buttonStyle(ModernRowButtonStyle())
        }
        .padding(.horizontal, -10)   // il contenuto delle righe si allinea alla griglia dei pulsanti
    }

    private var settings: some View {
        VStack(spacing: 2) {
            let t = c.t
            ModernToggleRow(icon: "battery.25percent", title: t.batteryProtection,
                            subtitle: t.batteryProtectionDetail(Battery.threshold), isOn: $c.stopOnLowBattery, t: t)
            ModernToggleRow(icon: "thermometer.high", title: t.heatProtection,
                            subtitle: t.heatProtectionDetail, isOn: $c.stopOnHeat, t: t)
            ModernToggleRow(icon: "display", title: t.keepDisplayOn,
                            subtitle: t.keepDisplayOnDetail, isOn: $c.keepDisplayOn, t: t)
            ModernToggleRow(icon: "arrow.up.forward.app", title: t.launchAtLogin,
                            isOn: Binding(get: { c.launchAtLogin }, set: { c.setLaunchAtLogin($0) }), t: t)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "paintpalette").font(.system(size: 15)).frame(width: 22)
                    Text(t.style).font(Face.medium(14))
                }
                ModernSegmented(options: AppTheme.allCases, name: { t.themeName($0) }, selection: $c.theme)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "globe").font(.system(size: 15)).frame(width: 22)
                    Text(t.language).font(Face.medium(14))
                }
                ModernSegmented(options: AppLanguage.allCases, name: { t.languageName($0) }, selection: $c.language)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            if c.hasPermission {
                Button { c.removePermission() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "lock.slash").font(.system(size: 15)).frame(width: 22)
                        Text(t.removePermission).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(ModernRowButtonStyle())
                .disabled(c.busy)
            }
        }
        .padding(6)
        .mRaised(radius: 18, depth: 0.7)
    }
}
