import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @Bindable var model: LauncherModel
    @State private var choosingIPA = false
    @State private var dropTargeted = false
    @State private var pendingUpdate: URL?

    var body: some View {
        HStack(spacing: 0) {
            HeroPanel(model: model)
                .frame(width: Theme.heroWidth)
            ZStack(alignment: .bottom) {
                content
                    .padding(Theme.contentPadding)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                if let message = model.errorMessage {
                    ErrorBanner(message: message) { model.errorMessage = nil }
                        .padding(16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.2), value: model.errorMessage)
        }
        .frame(width: Theme.windowSize.width, height: Theme.windowSize.height)
        .fileImporter(isPresented: $choosingIPA, allowedContentTypes: [.ipa]) { result in
            if case .success(let url) = result { requestInstall(url) }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let ipa = urls.first(where: { $0.pathExtension.lowercased() == "ipa" }) else { return false }
            requestInstall(ipa)
            return true
        } isTargeted: { dropTargeted = $0 }
        .confirmationDialog(
            "Replace the current installation?",
            isPresented: Binding(get: { pendingUpdate != nil }, set: { if !$0 { pendingUpdate = nil } }),
            presenting: pendingUpdate
        ) { ipa in
            Button("Install \(ipa.lastPathComponent)") {
                pendingUpdate = nil
                model.install(ipa: ipa)
            }
            Button("Cancel", role: .cancel) { pendingUpdate = nil }
        } message: { _ in
            Text("Your worlds, settings and sign-in are kept.")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .needsGame:
            OnboardingView(dropTargeted: dropTargeted) { choosingIPA = true }
        case .installing(let step):
            InstallingView(current: step)
        case .ready:
            HomeView(model: model) { choosingIPA = true }
        }
    }

    /// Installs right away the first time; asks before replacing a game.
    private func requestInstall(_ ipa: URL) {
        guard !model.isInstalling, !model.isRunning else { return }
        if model.game == nil {
            model.install(ipa: ipa)
        } else {
            pendingUpdate = ipa
        }
    }
}

extension UTType {
    static let ipa = UTType(filenameExtension: "ipa") ?? .data
}

private struct HeroPanel: View {
    let model: LauncherModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            BlockBackdrop()
            VStack(alignment: .leading, spacing: 10) {
                Label {
                    Text(verbatim: "Blockport")
                } icon: {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .frame(width: 28, height: 28)
                }
                .font(.headline)
                .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text(verbatim: "Minecraft")
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
                HStack(spacing: 8) {
                    if let game = model.game {
                        Chip(text: "Bedrock \(game.version)", tint: Theme.gold)
                    }
                    Chip(text: status, tint: model.isRunning ? Theme.accentBright : .white)
                }
            }
            .padding(24)
            .padding(.top, 20)
        }
    }

    private var status: String {
        if model.isRunning { return String(localized: "Running") }
        return switch model.phase {
        case .needsGame: String(localized: "Not installed")
        case .installing: String(localized: "Installing")
        case .ready: String(localized: "Ready")
        }
    }
}

private struct Chip: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.black.opacity(0.45), in: Capsule())
            .overlay(Capsule().strokeBorder(tint.opacity(0.5)))
    }
}

struct ErrorBanner: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.gold)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Something went wrong").font(.headline)
                Text(message).font(.callout).foregroundStyle(.secondary).textSelection(.enabled).lineLimit(4)
            }
            Spacer(minLength: 8)
            Button("Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(message, forType: .string)
            }
            Button("Close", action: dismiss).keyboardShortcut(.cancelAction)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.danger.opacity(0.6)))
    }
}
