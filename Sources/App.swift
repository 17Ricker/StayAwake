import SwiftUI

#if !PREVIEW && !FUNCTEST
@main
struct StayAwakeApp: App {
    @StateObject private var c = Controller()

    var body: some Scene {
        MenuBarExtra {
            ContentView(c: c)
        } label: {
            if c.theme == .modern {
                // Stile “Modern”: fulmine colorato e minuti accanto, come nella prima versione.
                HStack(spacing: 4) {
                    Image(nsImage: MenuBarArt.classicIcon(c.mode))
                    if c.mode == .timed { Text(c.menuTitle).monospacedDigit() }
                }
            } else {
                Image(nsImage: MenuBarArt.image(for: c))
            }
        }
        .menuBarExtraStyle(.window)
    }
}
#endif
