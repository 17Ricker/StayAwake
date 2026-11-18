import SwiftUI

// MARK: - Misure

enum NightLayout {
    /// Altezza del corpo sia da fermo sia da attivo: se cambiasse, la finestra del popover si
    /// ridimensionerebbe di scatto ad ogni avvio o stop.
    /// 374 = quadrante 216 + tempi rapidi 32 + avvio 50 + riga Continuo 40 + 3 spazi da 12.
    static let bodyHeight: CGFloat = 374
}

// MARK: - Tempi rapidi

struct Preset: Identifiable {
    let minutes: Int
    var id: Int { minutes }

    static let all = [15, 30, 60, 120].map(Preset.init)
}

// MARK: - Corpo del tema “Notte”

struct NightBody: View {
    @ObservedObject var c: Controller

    var body: some View {
        Group {
            if c.isActive { NightActive(c: c) } else { NightIdle(c: c) }
        }
        .animation(.smooth(duration: 0.25), value: c.isActive)
    }
}

// MARK: - Da fermo: quadrante + tempi rapidi + avvio

struct NightIdle: View {
    @ObservedObject var c: Controller

    var body: some View {
        VStack(spacing: 12) {
            dialCard
            chips
            startButton
            ContinuoRow(c: c)
        }
        .frame(height: NightLayout.bodyHeight, alignment: .top)
        .transition(.opacity)
    }

    private var dialCard: some View {
        HStack(spacing: 0) {
            ArcDial(minutes: $c.duration, style: c.dialStyle, t: c.t)
                .frame(width: DialMetrics.size.width, height: DialMetrics.size.height)
            hero
        }
        .frame(height: DialMetrics.size.height)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .nightCard(radius: 26)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(c.t.untilCaps).font(Face.medium(11)).tracking(1.8).foregroundStyle(Night.dim)
            EndClock(minutes: c.duration, locale: c.locale) { time in
                // Cifre grandi, AM/PM piccolo accanto: l'orario non si tronca mai.
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(time.digits).font(Face.demi(46)).lineLimit(1).minimumScaleFactor(0.5)
                    if let period = time.period {
                        Text(period).font(Face.demi(15)).fixedSize()
                    }
                }
                .foregroundStyle(Night.ink)
            }
            Rectangle().fill(Night.orange).frame(width: 28, height: 3)
            Text(c.t.lidNote)
                .font(Face.regular(11.5)).foregroundStyle(Night.dim)
                .fixedSize(horizontal: false, vertical: true)
            if !c.hasPermission {
                // Dentro la scheda, non sotto il tasto: così l'altezza non cambia al primo avvio.
                Text(c.t.firstTimePassword)
                    .font(Face.regular(11.5)).foregroundStyle(Night.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chips: some View {
        HStack(spacing: 8) {
            ForEach(Preset.all) { p in
                let selected = c.duration == p.minutes
                Button(c.t.durationLong(p.minutes)) { c.setDuration(p.minutes) }
                    .buttonStyle(ChipButtonStyle(selected: selected))
                    .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private var startButton: some View {
        Button { c.startTimed() } label: {
            HStack(spacing: 8) {
                if c.pending == .timed {
                    Spinner(onLight: true)
                    Text(c.t.waitingPassword)
                } else {
                    Image(systemName: "timer").font(.system(size: 15, weight: .medium))
                    Text(c.t.startTimer)
                }
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .keyboardShortcut(.defaultAction)
        .allowsHitTesting(!c.busy)
        .disabled(c.busy && c.pending != .timed)
    }
}

// MARK: - Attivo: barra a segmenti, tempo, stop

struct NightActive: View {
    @ObservedObject var c: Controller

    private var tint: Color { c.mode == .timed ? Night.orange : Night.red }
    private var soft: Color { c.mode == .timed ? Night.orangeSoft : Night.redSoft }

    var body: some View {
        VStack(spacing: 12) {
            card
            if c.mode == .timed {
                Button { c.extend(by: 1800) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 12, weight: .semibold))
                        Text(c.t.add30)
                    }
                }
                .buttonStyle(GhostButtonStyle())
            } else {
                Text(c.t.staysOnUntilStopped)
                    .font(Face.regular(13)).foregroundStyle(Night.dim)
                    .frame(maxWidth: .infinity, minHeight: 42)
            }
            ContinuoRow(c: c)
        }
        .frame(height: NightLayout.bodyHeight)
        .transition(.opacity)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 10) {
            SegmentBar(progress: c.mode == .timed ? c.progress : 1, tint: tint)
            Spacer(minLength: 0)
            HStack(alignment: .bottom, spacing: 8) {
                readout
                Spacer(minLength: 0)
                StopRoundButton(tint: tint, soft: soft, label: c.t.stop) { c.stop() }
            }
        }
        .padding(18)
        .frame(maxHeight: .infinity)
        .nightCard(radius: 30, fill: [Night.black, Color(hex: 0x0F1013)])
    }

    @ViewBuilder private var readout: some View {
        if c.mode == .timed {
            let text = Controller.format(c.remaining)
            VStack(alignment: .leading, spacing: 2) {
                Digits(text: text, size: text.count > 5 ? 40 : 52).foregroundStyle(Night.orange)
                Text(endCaption).font(Face.regular(13)).foregroundStyle(Night.dim)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(c.t.remaining(text))
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Image(systemName: "infinity").font(.system(size: 46, weight: .light)).foregroundStyle(Night.red)
                Text(c.t.noEnd).font(Face.regular(13)).foregroundStyle(Night.dim)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(c.t.activeNoLimit)
        }
    }

    private var endCaption: String {
        guard let end = c.endDate else { return "" }
        return c.t.untilTime(TimeText.end(end, locale: c.locale).text)
    }
}

/// Barra a segmenti: i primi si accendono mentre il tempo passa, gli estremi sfumano.
struct SegmentBar: View {
    let progress: Double
    let tint: Color
    static let count = 26

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<Self.count, id: \.self) { i in
                let lit = min(1, max(0, progress * Double(Self.count) - Double(i)))
                ZStack {
                    Capsule().fill(Night.track.opacity(0.75))
                    Capsule().fill(tint).opacity(lit)
                }
                .frame(width: 6)
            }
        }
        .frame(height: 96)
        .mask(LinearGradient(stops: [
            .init(color: Color.clear, location: 0),
            .init(color: Color.black, location: 0.12),
            .init(color: Color.black, location: 0.88),
            .init(color: Color.clear, location: 1)
        ], startPoint: .leading, endPoint: .trailing))
        .accessibilityHidden(true)
    }
}

struct StopRoundButton: View {
    let tint: Color
    let soft: Color
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(soft)
                RoundedRectangle(cornerRadius: 6, style: .continuous).fill(tint).frame(width: 20, height: 20)
            }
            .frame(width: 58, height: 58)
            .overlay(FocusRing(radius: 29))
        }
        .buttonStyle(PressScaleStyle())
        .keyboardShortcut(.defaultAction)
        .accessibilityLabel(label)
    }
}

// MARK: - Riga “Continuo”

/// Interruttore compatto: icona, nome e un piccolo switch. Un solo segnale di stato (la posizione e il colore
/// dello switch); “acceso/spento” lo dice VoiceOver.
struct ContinuoRow: View {
    @ObservedObject var c: Controller

    private var isOn: Bool { c.mode == .indefinite }
    private var waiting: Bool { c.pending == .indefinite }

    var body: some View {
        Button {
            if isOn { c.stop() } else { c.startIndefinite() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "infinity")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isOn ? Night.ink : Night.dim)
                    .frame(width: 22)
                Text(waiting ? c.t.waitingPassword : c.t.continuous)
                    .foregroundStyle(waiting ? Night.dim : Night.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if waiting { Spinner() } else { NightSwitch(isOn: isOn) }
            }
        }
        .buttonStyle(RowButtonStyle(minHeight: 40))
        .allowsHitTesting(!c.busy)
        .disabled(c.busy && !waiting)
        .accessibilityLabel(c.t.continuous)
        .accessibilityValue(isOn ? c.t.toggleOn : c.t.toggleOff)
        .accessibilityAddTraits(.isToggle)
    }
}
