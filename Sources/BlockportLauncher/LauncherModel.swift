import AppKit
import BlockportCore
import BlockportShared
import Foundation
import Observation

/// State of the launcher: the installed game, an installation in progress,
/// the running game and the saved launch settings.
@MainActor
@Observable
final class LauncherModel {
    enum Phase: Equatable {
        case needsGame
        case installing(Installer.Step)
        case ready
    }

    private static let settingsKey = "launchSettings"

    let locations: Locations
    private let defaults: UserDefaults
    private(set) var game: InstalledGame?
    private(set) var phase: Phase
    private(set) var isRunning = false
    private(set) var startedAt: Date?
    var errorMessage: String?
    var settings: LaunchSettings {
        didSet { save() }
    }

    private var process: Process?

    init(locations: Locations = .user, defaults: UserDefaults = .standard) {
        self.locations = locations
        self.defaults = defaults
        let installed = InstalledGame(app: locations.installedApp)
        game = installed
        phase = installed == nil ? .needsGame : .ready
        settings = defaults.data(forKey: Self.settingsKey).flatMap { try? JSONDecoder().decode(LaunchSettings.self, from: $0) } ?? LaunchSettings()
    }

    var preset: PerformancePreset? {
        get { PerformancePreset.matching(settings) }
        set { newValue?.apply(to: &settings) }
    }

    var installStepNumber: Int? {
        if case .installing(let step) = phase { step.rawValue + 1 } else { nil }
    }

    var isInstalling: Bool {
        if case .installing = phase { true } else { false }
    }

    func install(ipa: URL) {
        guard !isInstalling, !isRunning else { return }
        guard let runtime = RuntimeLocator.runtime() else {
            errorMessage = String(localized: "The Blockport runtime is missing from the launcher.")
            return
        }
        errorMessage = nil
        phase = .installing(.extract)
        let locations = locations
        Task.detached(priority: .userInitiated) {
            do {
                let game = try Installer.install(ipa: ipa, runtime: runtime, locations: locations) { step in
                    Task { @MainActor in self.phase = .installing(step) }
                }
                await self.finishInstall(game)
            } catch {
                await self.failInstall(error)
            }
        }
    }

    func play() {
        guard let game, !isRunning else { return }
        do {
            process = try GameLauncher.launch(game, settings: settings, locations: locations) { _ in
                Task { @MainActor in
                    self.isRunning = false
                    self.startedAt = nil
                    self.process = nil
                }
            }
            isRunning = true
            startedAt = .now
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Could not start the game: \(error.localizedDescription)")
        }
    }

    func stop() {
        process?.terminate()
    }

    func showLog() {
        NSWorkspace.shared.open(locations.log)
    }

    /// Opens the game's data folder, where its worlds are saved.
    func showGameData() {
        let worlds = GameDataLocation.documents(in: locations.gameData).appending(path: "games/com.mojang/minecraftWorlds")
        let folder = FileManager.default.fileExists(atPath: worlds.path) ? worlds : locations.gameData
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(folder)
    }

    private func finishInstall(_ installed: InstalledGame) {
        game = installed
        phase = .ready
    }

    private func failInstall(_ error: Error) {
        errorMessage = "\(error)"
        phase = game == nil ? .needsGame : .ready
    }

    private func save() {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: Self.settingsKey)
        }
    }
}
