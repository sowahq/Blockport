import BlockportShared
import SwiftUI

struct HomeView: View {
    @Bindable var model: LauncherModel
    let chooseIPA: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            heading
            playButton
            section("Display") {
                Picker("Display", selection: $model.settings.windowMode) {
                    Label("Full Screen", systemImage: "arrow.up.left.and.arrow.down.right").tag(WindowMode.fullScreen)
                    Label("Window", systemImage: "macwindow").tag(WindowMode.window)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .disabled(model.isRunning)
            section("Performance") {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(PerformancePreset.allCases) { preset in
                        PresetCard(preset: preset, selected: model.preset == preset) { model.preset = preset }
                    }
                }
                if model.preset == nil {
                    Label("Custom settings", systemImage: "slider.horizontal.3")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(model.isRunning)
            Spacer(minLength: 0)
            footer
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.isRunning ? "Playing" : "Ready to Play").font(.largeTitle.bold())
            if let startedAt = model.startedAt {
                TimelineView(.periodic(from: startedAt, by: 1)) { context in
                    Text("Playing for \(Duration.seconds(context.date.timeIntervalSince(startedAt)).formatted(.time(pattern: .minuteSecond)))")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Settings apply each time the game starts.").foregroundStyle(.secondary)
            }
        }
    }

    private var playButton: some View {
        Button {
            model.isRunning ? model.stop() : model.play()
        } label: {
            Label(model.isRunning ? "Stop the Game" : "Play", systemImage: model.isRunning ? "stop.fill" : "play.fill")
                .font(.title2.bold())
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(model.isRunning ? Theme.danger : Theme.accent)
        .controlSize(.extraLarge)
        .keyboardShortcut(.defaultAction)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            SettingsLink { Label("Advanced Settings", systemImage: "gearshape") }
            Spacer()
            Button(action: chooseIPA) { Label("Update", systemImage: "arrow.triangle.2.circlepath") }
                .disabled(model.isRunning)
            Button(action: model.showGameData) { Label("Worlds", systemImage: "folder") }
            Button(action: model.showLog) { Label("Log", systemImage: "doc.text.magnifyingglass") }
        }
        .buttonStyle(.borderless)
        .labelStyle(.titleAndIcon)
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline).foregroundStyle(.secondary)
            content()
        }
    }
}

private struct PresetCard: View {
    let preset: PerformancePreset
    let selected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 10) {
                Image(systemName: preset.symbol)
                    .font(.title3)
                    .foregroundStyle(selected ? Theme.accentBright : .secondary)
                    .frame(width: 26)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.title).font(.headline)
                    Text(preset.detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accentBright).accessibilityHidden(true)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Theme.accent.opacity(0.15) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(selected ? Theme.accent : .clear, lineWidth: 1.5))
            .contentShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .animation(.easeOut(duration: 0.15), value: selected)
    }
}
