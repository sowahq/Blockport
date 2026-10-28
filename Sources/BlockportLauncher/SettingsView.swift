import BlockportShared
import SwiftUI

/// Advanced settings, in the app's Settings window (⌘,).
struct SettingsView: View {
    @Bindable var model: LauncherModel

    var body: some View {
        Form {
            if model.isRunning {
                Label("Changes apply the next time the game starts.", systemImage: "info.circle")
                    .foregroundStyle(.secondary)
            }
            Section {
                Picker("Game resolution", selection: $model.settings.resolution) {
                    ForEach(ResolutionChoice.all, id: \.label) { Text($0.label).tag($0.size) }
                }
                Picker("Render sharpness", selection: $model.settings.renderScale) {
                    Text("Retina (maximum)").tag(Double?.none)
                    Text("High (×1.5)").tag(Double?.some(1.5))
                    Text("Medium (×1.25)").tag(Double?.some(1.25))
                    Text("Low (×1)").tag(Double?.some(1))
                }
            } header: {
                Text("Picture")
            } footer: {
                Text("The game keeps this resolution and the window scales it. Lower sharpness eases the load on the graphics card.")
            }
            Section {
                Picker("On power adapter", selection: $model.settings.frameRate) {
                    Text("Match the display (up to 120)").tag(Int?.none)
                    Text("60 fps").tag(Int?.some(60))
                    Text("30 fps").tag(Int?.some(30))
                }
                Picker("On battery", selection: $model.settings.batteryFrameRate) {
                    Text("Same as on power adapter").tag(Int?.none)
                    Text("60 fps").tag(Int?.some(60))
                    Text("30 fps").tag(Int?.some(30))
                }
            } header: {
                Text("Frames per second")
            } footer: {
                Text("The battery setting also applies in Low Power Mode.")
            }
            Section {
                Toggle("Limit busy-waiting in loading threads", isOn: $model.settings.yieldBackoff)
            } header: {
                Text("Processor")
            } footer: {
                Text("Greatly reduces CPU use in game. Turn it off only to compare.")
            }
            Section {
                Button("Restore Defaults") { model.settings = LaunchSettings(windowMode: model.settings.windowMode) }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Resolutions offered for the game, in points.
struct ResolutionChoice {
    let label: String
    let size: CGSize?

    static let all = [
        ResolutionChoice(label: String(localized: "Screen (automatic)"), size: nil),
        ResolutionChoice(label: "1280 × 800", size: CGSize(width: 1280, height: 800)),
        ResolutionChoice(label: "1440 × 900", size: CGSize(width: 1440, height: 900)),
        ResolutionChoice(label: "1680 × 1050", size: CGSize(width: 1680, height: 1050)),
    ]
}
