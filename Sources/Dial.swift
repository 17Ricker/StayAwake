import SwiftUI
import AppKit

// MARK: - Geometria del quadrante

/// Un grado dell'arco vale un minuto: 5° tra una tacca e l'altra, 30° tra due valori in chiaro.
enum DialMetrics {
    static let size = CGSize(width: 138, height: 216)
    static let center = CGPoint(x: 124, y: 108)
    static let rOut: CGFloat = 106
    static let span: Double = 85
    static var pointsPerMinute: CGFloat { rOut * .pi / 180 }
}

// MARK: - Disegno

/// Quadrante ad arco: tacche radiali che scorrono, il valore scelto è quello più a sinistra.
/// `phase` (i minuti) è animabile, così i passaggi tra una tacca e l'altra scorrono invece di scattare.
private struct DialCanvas: View, Animatable {
    var phase: Double
    let style: DialStyle
    let t: Strings

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    var body: some View {
        Canvas { ctx, _ in draw(ctx) }
            .frame(width: DialMetrics.size.width, height: DialMetrics.size.height)
    }

    private func point(_ r: CGFloat, _ deg: Double) -> CGPoint {
        let a = deg * .pi / 180
        return CGPoint(x: DialMetrics.center.x - r * CGFloat(cos(a)),
                       y: DialMetrics.center.y - r * CGFloat(sin(a)))
    }

    private func label(_ ctx: GraphicsContext, _ text: Text, deg: Double, radius: CGFloat) {
        var c = ctx
        let p = point(radius, deg)
        c.translateBy(x: p.x, y: p.y)
        c.rotate(by: .radians(deg * .pi / 180))
        c.draw(text, at: .zero, anchor: .leading)
    }

    private func draw(_ ctx: GraphicsContext) {
        let rOut = DialMetrics.rOut
        let first = Int(((phase - DialMetrics.span) / 5).rounded(.up)) * 5
        let last = Int(((phase + DialMetrics.span) / 5).rounded(.down)) * 5
        let lo = max(Controller.minMinutes, first)
        let hi = min(Controller.maxMinutes, last)
        guard lo <= hi else { return }

        for value in stride(from: lo, through: hi, by: 5) {
            let deg = Double(value) - phase
            let a = abs(deg)
            let fade = pow(max(0, 1 - a / DialMetrics.span), 1.3)
            let near = max(0, 1 - a / 3)
            let major = value % 30 == 0
            let mid = value % 15 == 0

            let base: CGFloat = major ? 16 : (mid ? 12 : 8)
            let length = base + CGFloat(near) * (26 - base)   // la tacca scelta ha sempre la stessa lunghezza
            let width = 1.3 + CGFloat(near)
            let alpha = min(1, (major ? 0.95 : 0.6) * fade + near * 0.6)

            var tick = Path()
            tick.move(to: point(rOut, deg))
            tick.addLine(to: point(rOut - length, deg))
            ctx.stroke(tick, with: .color(Night.ink.opacity(alpha)),
                       style: StrokeStyle(lineWidth: width, lineCap: .round))

            guard style == .classic, major || near > 0.02 else { continue }
            let clear = min(1, max(0, (a - 10) / 10))
            let labelAlpha = max(near, fade * 0.85 * clear)
            guard labelAlpha > 0.02 else { continue }
            let size = 12.5 + 5.5 * CGFloat(near)
            let text = Text(t.durationLong(value))
                .font(near > 0.5 ? Face.demi(size) : Face.medium(size))
                .foregroundColor(Night.ink.opacity(labelAlpha))
            label(ctx, text, deg: deg, radius: rOut - length - 6)
        }

        if style == .circle { marker(ctx) }
    }

    /// Variante “cerchio”: il valore scelto sta in un cerchio in fondo alla tacca, con la durata accanto.
    private func marker(_ ctx: GraphicsContext) {
        let selected = Controller.clamp(Int(phase.rounded()))
        let center = point(DialMetrics.rOut - 41, 0)     // il bordo del cerchio tocca la fine della tacca (26 + 15)
        let rect = CGRect(x: center.x - 15, y: center.y - 15, width: 30, height: 30)
        ctx.stroke(Path(ellipseIn: rect), with: .color(Night.ink), lineWidth: 1.5)
        let digits = "\(selected)"
        ctx.draw(Text(digits).font(Face.demi(digits.count > 3 ? 10 : 12.5)).foregroundColor(Night.ink), at: center)
        let long = t.durationLong(selected)
        ctx.draw(Text(long).font(Face.demi(long.count > 6 ? 13 : 16)).foregroundColor(Night.ink),
                 at: CGPoint(x: center.x + 23, y: center.y), anchor: .leading)
    }
}

// MARK: - Rotella del mouse / trackpad

/// Intercetta solo gli eventi di scorrimento: click e trascinamenti restano a SwiftUI.
struct ScrollCatcher: NSViewRepresentable {
    let onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> CatcherView {
        let v = CatcherView()
        v.onScroll = onScroll
        return v
    }

    func updateNSView(_ nsView: CatcherView, context: Context) { nsView.onScroll = onScroll }

    final class CatcherView: NSView {
        var onScroll: ((CGFloat) -> Void)?

        override func hitTest(_ point: NSPoint) -> NSView? {
            NSApp.currentEvent?.type == .scrollWheel ? super.hitTest(point) : nil
        }

        override func scrollWheel(with event: NSEvent) {
            let dy = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.scrollingDeltaY * 8
            onScroll?(dy)
        }
    }
}

// MARK: - Controllo

struct ArcDial: View {
    @Binding var minutes: Int
    let style: DialStyle
    let t: Strings
    @State private var dragStart: Int?
    @State private var scrollRemainder: CGFloat = 0
    @FocusState private var focused: Bool

    private var edgeFade: LinearGradient {
        LinearGradient(stops: [
            .init(color: Color.clear, location: 0),
            .init(color: Color.black, location: 0.1),
            .init(color: Color.black, location: 0.9),
            .init(color: Color.clear, location: 1)
        ], startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        DialCanvas(phase: Double(minutes), style: style, t: t)
            .animation(.smooth(duration: 0.14), value: minutes)
            .mask(edgeFade)
            .contentShape(Rectangle())
            .gesture(drag)
            .overlay(scroll)
            .overlay(FocusRingIf(active: focused, radius: 14))
            .focusable()
            .focused($focused)
            .focusEffectDisabled()
            // Tastiera: su/giù ±5 minuti, con maiuscolo ±1 ora.
            .onKeyPress(.upArrow, phases: [.down, .repeat]) { press in
                step(press.modifiers.contains(.shift) ? 60 : 5); return .handled
            }
            .onKeyPress(.downArrow, phases: [.down, .repeat]) { press in
                step(press.modifiers.contains(.shift) ? -60 : -5); return .handled
            }
            // VoiceOver: un solo elemento regolabile.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(t.durationA11y)
            .accessibilityValue(t.durationSpoken(minutes))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: step(5)
                case .decrement: step(-5)
                @unknown default: break
                }
            }
    }

    private func set(_ value: Int) {
        let v = Controller.clamp(value)
        guard v != minutes else { return }
        minutes = v
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    private func step(_ delta: Int) { set(minutes + delta) }

    /// Trascinare in giù porta in basso i valori più alti: la tacca segue il dito.
    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { g in
                if dragStart == nil { dragStart = minutes }
                guard let start = dragStart, hypot(g.translation.width, g.translation.height) >= 3 else { return }
                set(Int((Double(start) + Double(g.translation.height / DialMetrics.pointsPerMinute)).rounded()))
            }
            .onEnded { g in
                defer { dragStart = nil }
                if hypot(g.translation.width, g.translation.height) < 3 { click(at: g.location) }
            }
    }

    /// Un click su una tacca porta quel valore al centro.
    private func click(at p: CGPoint) {
        let dx = p.x - DialMetrics.center.x, dy = p.y - DialMetrics.center.y
        let r = hypot(dx, dy)
        guard r > 30, r < DialMetrics.rOut + 14 else { return }
        let deg = atan2(-dy, -dx) * 180 / .pi
        guard abs(deg) <= DialMetrics.span else { return }
        set(Int((Double(minutes) + deg).rounded()))
    }

    #if !PREVIEW
    private var scroll: some View {
        ScrollCatcher { dy in
            let perStep = DialMetrics.pointsPerMinute * 5
            scrollRemainder += dy
            let steps = Int((scrollRemainder / perStep).rounded(.towardZero))
            guard steps != 0 else { return }
            scrollRemainder -= CGFloat(steps) * perStep
            step(steps * 5)
        }
    }
    #else
    private var scroll: some View { EmptyView() }
    #endif
}
