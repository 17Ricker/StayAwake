import SwiftUI
import AppKit

// MARK: - Intestazione

struct Header: View {
    @ObservedObject var c: Controller
    @Binding var showSettings: Bool

    private var dot: Color {
        switch c.mode {
        case .off: return Night.faint
        case .timed: return Night.orange
        case .indefinite: return Night.red
        }
    }

    private var status: String {
        switch c.mode {
        case .off: return "Spento"
        case .timed: return "Attivo · timer"
        case .indefinite: return "Attivo · continuo"
        }
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                (Text("STAYAWAKE").foregroundColor(Night.ink) + Text(".").foregroundColor(Night.orange))
                    .font(Face.bold(13))
                    .tracking(2.4)
                HStack(spacing: 6) {
                    Circle().fill(dot).frame(width: 6, height: 6)
                    Text(status).font(Face.regular(12)).foregroundStyle(Night.dim)
                }
                .accessibilityElement(children: .combine)
            }
            Spacer()
            Button {
                withAnimation(.smooth(duration: 0.25)) { showSettings.toggle() }
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(IconButtonStyle(active: showSettings))
            .accessibilityLabel("Impostazioni")
            .accessibilityValue(showSettings ? "aperte" : "chiuse")
        }
    }
}

// MARK: - Messaggi

struct MessageBanner: View {
    @ObservedObject var c: Controller

    var body: some View {
        if let e = c.error {
            banner(e, icon: "exclamationmark.triangle.fill", tint: Night.stopRed)
        } else if let n = c.notice {
            banner(n, icon: "info.circle", tint: Night.dim)
        }
    }

    private func banner(_ text: String, icon: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(text).foregroundStyle(Night.ink)
        }
        .font(Face.medium(12.5))
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Night.well))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Impostazioni

private struct SettingToggleRow: View {
    let icon: String
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 15)).foregroundStyle(Night.dim).frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                    if let subtitle {
                        Text(subtitle).font(Face.regular(12)).foregroundStyle(Night.dim)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                NightSwitch(isOn: isOn)
            }
        }
        .buttonStyle(RowButtonStyle())
        .accessibilityValue(isOn ? "attivo" : "spento")
        .accessibilityAddTraits(.isToggle)
    }
}

private struct SettingChoiceRow<T: Hashable & Identifiable>: View {
    let icon: String
    let title: String
    let options: [T]
    let name: (T) -> String
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 15)).foregroundStyle(Night.dim).frame(width: 22)
            Text(title).font(Face.medium(14)).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 2) {
                ForEach(options) { option in
                    let chosen = option == selection
                    Button { selection = option } label: {
                        Text(name(option))
                            .font(Face.medium(12))
                            .foregroundStyle(chosen ? Night.onAccent : Night.dim)
                            .padding(.horizontal, 10)
                            .frame(height: 26)
                            .background(Capsule().fill(chosen ? Night.ink : Color.clear))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(chosen ? .isSelected : [])
                }
            }
            .fixedSize()
            .padding(2)
            .background(Capsule().fill(Night.well))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 44)
    }
}

/// Scelta dello stile (Notte, Retro, Modern): titolo sopra e selettore a tutta larghezza.
private struct NightStyleRow: View {
    @Binding var selection: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "paintpalette").font(.system(size: 15)).foregroundStyle(Night.dim).frame(width: 22)
                Text("Stile").font(Face.medium(14))
            }
            HStack(spacing: 2) {
                ForEach(AppTheme.allCases) { option in
                    let chosen = option == selection
                    Button { selection = option } label: {
                        Text(option.title)
                            .font(Face.medium(12.5))
                            .foregroundStyle(chosen ? Night.onAccent : Night.dim)
                            .frame(maxWidth: .infinity)
                            .frame(height: 28)
                            .background(Capsule().fill(chosen ? Night.ink : Color.clear))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(chosen ? .isSelected : [])
                }
            }
            .padding(2)
            .background(Capsule().fill(Night.well))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}

struct SettingsPanel: View {
    @ObservedObject var c: Controller

    var body: some View {
        VStack(spacing: 2) {
            SettingToggleRow(icon: "battery.25percent", title: "Protezione batteria",
                             subtitle: "Ferma sotto il \(Battery.threshold)%", isOn: $c.stopOnLowBattery)
            SettingToggleRow(icon: "display", title: "Schermo sempre acceso",
                             subtitle: "Niente spegnimento per inattività", isOn: $c.keepDisplayOn)
            SettingToggleRow(icon: "arrow.up.forward.app", title: "Avvia al login",
                             isOn: Binding(get: { c.launchAtLogin }, set: { c.setLaunchAtLogin($0) }))
            Groove().padding(.horizontal, 10).padding(.vertical, 4)
            if c.theme == .night {
                SettingChoiceRow(icon: "dial.medium", title: "Quadrante",
                                 options: DialStyle.allCases, name: { $0.title }, selection: $c.dialStyle)
            }
            NightStyleRow(selection: $c.theme)
            Groove().padding(.horizontal, 10).padding(.vertical, 4)
            if c.hasPermission {
                Button { c.removePermission() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "lock.slash").font(.system(size: 15)).foregroundStyle(Night.dim).frame(width: 22)
                        Text("Rimuovi permesso").frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(RowButtonStyle())
            }
            Button { NSApplication.shared.terminate(nil) } label: {
                HStack(spacing: 10) {
                    Image(systemName: "xmark").font(.system(size: 15)).foregroundStyle(Night.dim).frame(width: 22)
                    Text("Esci").frame(maxWidth: .infinity, alignment: .leading)
                    Text("⌘Q")
                        .font(Face.medium(11))
                        .foregroundStyle(Night.dim)
                        .fixedSize()
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                }
            }
            .buttonStyle(RowButtonStyle())
        }
        .padding(8)
        .nightCard(radius: 24)
    }
}

// MARK: - Popover

struct ContentView: View {
    @ObservedObject var c: Controller
    @State private var showSettings: Bool

    init(c: Controller, settingsOpen: Bool = false) {
        self.c = c
        _showSettings = State(initialValue: settingsOpen)
    }

    var body: some View {
        Group {
            switch c.theme {
            case .modern: ModernPopover(c: c, showSettings: $showSettings)
            case .night, .retro: DarkPopover(c: c, showSettings: $showSettings)
            }
        }
        .focusEffectDisabled()
        // ⌘Q funziona anche a impostazioni chiuse.
        .background(
            Button("Esci") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)
        )
    }
}

/// Popover dei due stili scuri: “Notte” (predefinito) e “Retro”.
private struct DarkPopover: View {
    @ObservedObject var c: Controller
    @Binding var showSettings: Bool

    var body: some View {
        VStack(spacing: 14) {
            Header(c: c, showSettings: $showSettings)
            Group {
                if c.theme == .retro { RetroBody(c: c) } else { NightBody(c: c) }
            }
            MessageBanner(c: c)
            if showSettings { SettingsPanel(c: c) }
        }
        .padding(14)
        .frame(width: 320)
        .background(ground)
        .foregroundStyle(Night.ink)
        .environment(\.colorScheme, .dark)
    }

    private var ground: some View {
        let colors: [Color] = c.theme == .retro ? [Color(hex: 0x1D1D1C), Color(hex: 0x121212)] : Night.ground
        return ZStack {
            vertical(colors)
            RadialGradient(colors: [Color.white.opacity(0.05), Color.clear],
                           center: .topTrailing, startRadius: 0, endRadius: 320)
        }
    }
}
