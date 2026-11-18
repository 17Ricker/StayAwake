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
        case .off: return c.t.statusOff
        case .timed: return c.t.statusTimer
        case .indefinite: return c.t.statusContinuous
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
            .accessibilityLabel(c.t.settings)
            .accessibilityValue(showSettings ? c.t.settingsOpen : c.t.settingsClosed)
        }
    }
}

// MARK: - Messaggi

struct MessageBanner: View {
    @ObservedObject var c: Controller

    var body: some View {
        if let e = c.error {
            banner(e, icon: "exclamationmark.triangle.fill", tint: Night.stopRed, restoreAction: c.needsManualRestore)
        } else if let n = c.notice {
            banner(n, icon: "info.circle", tint: Night.dim, restoreAction: false)
        }
    }

    private func banner(_ text: String, icon: String, tint: Color, restoreAction: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: icon).foregroundStyle(tint)
                Text(text).foregroundStyle(Night.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button { c.dismissMessage() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Night.dim)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(c.t.stop)
            }
            if restoreAction {
                Button { c.retryRestoreSleep() } label: {
                    HStack(spacing: 6) {
                        if c.restoringSleep { Spinner(onLight: true) }
                        Text(c.restoringSleep ? c.t.waitingPassword : c.t.restoreSleepNow)
                            .font(Face.demi(12))
                    }
                    .foregroundStyle(Night.onAccent)
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .background(Capsule().fill(Night.orange))
                }
                .buttonStyle(.plain)
                .disabled(c.busy)
            }
        }
        .font(Face.medium(12.5))
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Night.well))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }
}

// MARK: - Impostazioni

private struct SettingToggleRow: View {
    let icon: String
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool
    let t: Strings

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
        .accessibilityValue(isOn ? t.toggleOn : t.toggleOff)
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

/// Scelta a tutta larghezza (Stile, Lingua): titolo sopra e selettore sotto.
private struct NightWideChoiceRow<T: Hashable & Identifiable>: View {
    let icon: String
    let title: String
    let options: [T]
    let name: (T) -> String
    @Binding var selection: T

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 15)).foregroundStyle(Night.dim).frame(width: 22)
                Text(title).font(Face.medium(14))
            }
            HStack(spacing: 2) {
                ForEach(options) { option in
                    let chosen = option == selection
                    Button { selection = option } label: {
                        Text(name(option))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
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
            let t = c.t
            SettingToggleRow(icon: "battery.25percent", title: t.batteryProtection,
                             subtitle: t.batteryProtectionDetail(Battery.threshold), isOn: $c.stopOnLowBattery, t: t)
            SettingToggleRow(icon: "thermometer.high", title: t.heatProtection,
                             subtitle: t.heatProtectionDetail, isOn: $c.stopOnHeat, t: t)
            SettingToggleRow(icon: "display", title: t.keepDisplayOn,
                             subtitle: t.keepDisplayOnDetail, isOn: $c.keepDisplayOn, t: t)
            SettingToggleRow(icon: "arrow.up.forward.app", title: t.launchAtLogin,
                             isOn: Binding(get: { c.launchAtLogin }, set: { c.setLaunchAtLogin($0) }), t: t)
            Groove().padding(.horizontal, 10).padding(.vertical, 4)
            if c.theme == .night {
                SettingChoiceRow(icon: "dial.medium", title: t.dial,
                                 options: DialStyle.allCases, name: { t.dialName($0) }, selection: $c.dialStyle)
            }
            NightWideChoiceRow(icon: "paintpalette", title: t.style, options: AppTheme.allCases,
                               name: { t.themeName($0) }, selection: $c.theme)
            NightWideChoiceRow(icon: "globe", title: t.language, options: AppLanguage.allCases,
                               name: { t.languageName($0) }, selection: $c.language)
            Groove().padding(.horizontal, 10).padding(.vertical, 4)
            if c.hasPermission {
                Button { c.removePermission() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "lock.slash").font(.system(size: 15)).foregroundStyle(Night.dim).frame(width: 22)
                        Text(t.removePermission).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(RowButtonStyle())
                .disabled(c.busy)
            }
            Button { NSApplication.shared.terminate(nil) } label: {
                HStack(spacing: 10) {
                    Image(systemName: "xmark").font(.system(size: 15)).foregroundStyle(Night.dim).frame(width: 22)
                    Text(t.quit).frame(maxWidth: .infinity, alignment: .leading)
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
            Button(c.t.quit) { NSApplication.shared.terminate(nil) }
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
