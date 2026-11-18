import SwiftUI
import AppKit

// MARK: - Colori e caratteri

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

/// Tema “Notte”: antracite, testo crema, accento arancio.
enum Night {
    static let ground: [Color] = [Color(hex: 0x272931), Color(hex: 0x181A1F)]
    static let card: [Color] = [Color(hex: 0x20222A), Color(hex: 0x181A20)]
    static let black = Color(hex: 0x0A0A0C)
    static let well = Color(hex: 0x111216)
    static let ink = Color(hex: 0xF2E2CC)          // crema
    static let dim = Color(hex: 0xA9ABB2)
    static let faint = Color(hex: 0x6F7179)
    static let track = Color(hex: 0x3A3C43)
    static let onAccent = Color(hex: 0x17181C)
    static let orange = Color(hex: 0xEE7B3F)       // timer
    static let orangeDeep = Color(hex: 0xCB5A23)
    static let orangeSoft = Color(hex: 0x5A2D18)
    static let red = Color(hex: 0xE5484D)          // continuo
    static let redSoft = Color(hex: 0x4A1C1F)
    static let stopRed = Color(hex: 0xFF6A6E)
}

enum Face {
    static func regular(_ s: CGFloat) -> Font { .custom("AvenirNext-Regular", size: s) }
    static func medium(_ s: CGFloat) -> Font { .custom("AvenirNext-Medium", size: s) }
    static func demi(_ s: CGFloat) -> Font { .custom("AvenirNext-DemiBold", size: s) }
    static func bold(_ s: CGFloat) -> Font { .custom("AvenirNext-Bold", size: s) }
    static func mono(_ s: CGFloat) -> Font { .custom("Menlo-Regular", size: s) }
}

func vertical(_ colors: [Color]) -> LinearGradient {
    LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
}

func diagonal(_ colors: [Color]) -> LinearGradient {
    LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
}

// MARK: - Superfici

/// Scheda scura con bordo sottile e un filo di luce in alto.
struct NightCard: ViewModifier {
    var radius: CGFloat
    var fill: [Color]
    var shadow: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let rim = LinearGradient(colors: [Color.white.opacity(0.11), Color.white.opacity(0.03)],
                                 startPoint: .top, endPoint: .bottom)
        content
            .background(shape.fill(vertical(fill)))
            .overlay(shape.strokeBorder(rim, lineWidth: 1))
            .shadow(color: Color.black.opacity(shadow ? 0.35 : 0), radius: 10, x: 0, y: 6)
    }
}

extension View {
    func nightCard(radius: CGFloat = 24, fill: [Color] = Night.card, shadow: Bool = true) -> some View {
        modifier(NightCard(radius: radius, fill: fill, shadow: shadow))
    }
}

/// Riga incisa: una linea scura e una chiara sotto.
struct Groove: View {
    var dark: Color = Color.black.opacity(0.35)
    var light: Color = Color.white.opacity(0.07)

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(dark).frame(height: 1)
            Rectangle().fill(light).frame(height: 1)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Focus da tastiera

/// “Focus visibile”: l'anello compare solo dopo un tasto premuto, non all'apertura del popover né al click.
@MainActor
final class InputModality: ObservableObject {
    static let shared = InputModality()
    @Published private(set) var usingKeyboard = false

    private init() {
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown]) { [weak self] event in
            let keyboard = event.type == .keyDown
            Task { @MainActor in self?.usingKeyboard = keyboard }
            return event
        }
    }
}

struct FocusRing: View {
    var radius: CGFloat
    var color: Color = Night.ink.opacity(0.9)
    @Environment(\.isFocused) private var focused
    @ObservedObject private var modality = InputModality.shared

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(color, lineWidth: 2)
            .padding(-3)
            .opacity(focused && modality.usingKeyboard ? 1 : 0)
            .allowsHitTesting(false)
    }
}

struct FocusRingIf: View {
    let active: Bool
    let radius: CGFloat
    var color: Color = Night.ink.opacity(0.9)
    @ObservedObject private var modality = InputModality.shared

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(color, lineWidth: 2)
            .padding(-3)
            .opacity(active && modality.usingKeyboard ? 1 : 0)
            .allowsHitTesting(false)
    }
}

// MARK: - Piccoli elementi

/// Indicatore di attesa per i tasti.
struct Spinner: View {
    var onLight = false

    var body: some View {
        #if PREVIEW
        Circle().trim(from: 0, to: 0.7)
            .stroke(onLight ? Night.onAccent : Night.ink, lineWidth: 2)
            .frame(width: 14, height: 14)
        #else
        ProgressView().controlSize(.small).environment(\.colorScheme, onLight ? .light : .dark)
        #endif
    }
}

/// Ogni cifra occupa la stessa larghezza: il conto alla rovescia non “balla” ad ogni secondo.
struct Digits: View {
    let text: String
    let size: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, ch in
                Text(String(ch))
                    .font(Face.regular(size))
                    .fixedSize()
                    .frame(width: ch == ":" ? size * 0.28 : size * 0.58)
            }
        }
    }
}

enum Clock {
    /// Solo per le anteprime: un «adesso» fisso.
    nonisolated(unsafe) static var fixedNow: Date?
}

/// Ora di fine se il timer partisse adesso; si aggiorna ogni minuto. Il contenuto decide come mostrarla.
struct EndClock<Content: View>: View {
    let minutes: Int
    let locale: Locale
    @ViewBuilder let content: (TimeText) -> Content

    var body: some View {
        TimelineView(.everyMinute) { ctx in
            content(TimeText.end((Clock.fixedNow ?? ctx.date).addingTimeInterval(TimeInterval(minutes * 60)), locale: locale))
        }
    }
}

// MARK: - Stili dei pulsanti

struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Tasto principale: arancio, testo scuro.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { PrimaryBody(configuration: configuration) }
}

private struct PrimaryBody: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        let rim = LinearGradient(colors: [Color.white.opacity(0.4), Color.white.opacity(0)],
                                 startPoint: .top, endPoint: .bottom)
        configuration.label
            .font(Face.demi(16))
            .foregroundStyle(Night.onAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(shape.fill(vertical([Night.orange, Night.orangeDeep]))
                .shadow(color: Night.orange.opacity(0.32), radius: 14, x: 0, y: 6))
            .overlay(shape.strokeBorder(rim, lineWidth: 1))
            .overlay(FocusRing(radius: 18))
            .brightness(configuration.isPressed ? -0.07 : 0)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(enabled ? 1 : 0.4)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Tasto secondario: contorno sottile.
struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { GhostBody(configuration: configuration) }
}

private struct GhostBody: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var enabled
    @State private var hover = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let wash = configuration.isPressed ? 0.12 : (hover ? 0.07 : 0.0)
        configuration.label
            .font(Face.medium(14))
            .foregroundStyle(Night.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(shape.fill(Color.white.opacity(wash)))
            .overlay(shape.strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
            .overlay(FocusRing(radius: 16))
            .contentShape(shape)
            .onHover { hover = $0 }
            .opacity(enabled ? 1 : 0.4)
    }
}

/// Pastiglia dei tempi rapidi.
struct ChipButtonStyle: ButtonStyle {
    var selected: Bool
    func makeBody(configuration: Configuration) -> some View { ChipBody(configuration: configuration, selected: selected) }
}

private struct ChipBody: View {
    let configuration: ButtonStyleConfiguration
    let selected: Bool
    @State private var hover = false

    var body: some View {
        let wash = (hover || configuration.isPressed) ? 0.11 : 0.06
        configuration.label
            .font(Face.medium(13))
            .foregroundStyle(selected ? Night.onAccent : Night.dim)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(Capsule().fill(selected ? Night.ink : Color.white.opacity(wash)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(selected ? 0 : 0.10), lineWidth: 1))
            .overlay(FocusRing(radius: 16))
            .contentShape(Capsule())
            .onHover { hover = $0 }
    }
}

/// Pulsante tondo con icona (ingranaggio).
struct IconButtonStyle: ButtonStyle {
    var active: Bool
    func makeBody(configuration: Configuration) -> some View { IconBody(configuration: configuration, active: active) }
}

private struct IconBody: View {
    let configuration: ButtonStyleConfiguration
    let active: Bool
    @State private var hover = false

    var body: some View {
        let wash = active ? 0.14 : ((hover || configuration.isPressed) ? 0.10 : 0.0)
        configuration.label
            .font(.system(size: 15))
            .foregroundStyle(Night.ink)
            .frame(width: 36, height: 36)
            .background(Circle().fill(Color.white.opacity(wash)))
            .overlay(Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
            .overlay(FocusRing(radius: 18))
            .contentShape(Circle())
            .onHover { hover = $0 }
    }
}

/// Riga di menu: evidenziata al passaggio del mouse, con anello di focus.
struct RowButtonStyle: ButtonStyle {
    var minHeight: CGFloat = 44
    func makeBody(configuration: Configuration) -> some View {
        RowBody(configuration: configuration, minHeight: minHeight)
    }
}

private struct RowBody: View {
    let configuration: ButtonStyleConfiguration
    let minHeight: CGFloat
    @State private var hover = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        let wash = configuration.isPressed ? 0.10 : (hover ? 0.06 : 0.0)
        configuration.label
            .font(Face.medium(14))
            .foregroundStyle(Night.ink)
            .padding(.horizontal, 10)
            .frame(minHeight: minHeight)
            .background(shape.fill(Color.white.opacity(wash)))
            .overlay(FocusRing(radius: 12))
            .contentShape(shape)
            .onHover { hover = $0 }
    }
}

/// L'unico interruttore dell'app (Continuo e Impostazioni): pista sottile, pomello chiaro,
/// arancio con un filo di alone solo quando è acceso.
struct NightSwitch: View {
    let isOn: Bool

    var body: some View {
        let track = Capsule()
        ZStack {
            track.fill(Color.white.opacity(0.07))
            track.fill(vertical([Night.orange, Night.orangeDeep])).opacity(isOn ? 1 : 0)
            track.strokeBorder(Color.white.opacity(isOn ? 0.28 : 0.14), lineWidth: 1)
            Circle()
                .fill(vertical([Color.white, Color(hex: 0xE4D8C6)]))
                .frame(width: 20, height: 20)
                .shadow(color: Color.black.opacity(0.35), radius: 2, x: 0, y: 1)
                .offset(x: isOn ? 9 : -9)
        }
        .frame(width: 44, height: 26)
        .shadow(color: Night.orange.opacity(isOn ? 0.35 : 0), radius: 8, x: 0, y: 0)
        .animation(.smooth(duration: 0.2), value: isOn)
        .accessibilityHidden(true)
    }
}
