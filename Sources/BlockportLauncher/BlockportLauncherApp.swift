import SwiftUI

@main
struct BlockportLauncherApp: App {
    @State private var model = LauncherModel()

    var body: some Scene {
        Window("Blockport", id: "launcher") {
            RootView(model: model)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        Settings {
            SettingsView(model: model)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}
