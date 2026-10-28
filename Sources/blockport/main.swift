import BlockportCore
import BlockportShared
import Foundation

let usage = """
usage: blockport install <decrypted.ipa>
       blockport play [fullscreen|window]
"""

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
    exit(EXIT_FAILURE)
}

let arguments = CommandLine.arguments.dropFirst()
let locations = Locations.user

switch arguments.first {
case "install":
    guard let ipa = arguments.dropFirst().first else { fail(usage) }
    guard let runtime = RuntimeLocator.runtime() else { fail("runtime not found: set BLOCKPORT_RUNTIME") }
    do {
        let game = try Installer.install(ipa: URL(fileURLWithPath: ipa), runtime: runtime, locations: locations) { step in
            print("• \(step.title)")
        }
        print("Minecraft \(game.version) installed in \(game.app.path)")
    } catch {
        fail("failed: \(error)")
    }
case "play":
    guard let game = InstalledGame(app: locations.installedApp) else { fail("no game installed") }
    let mode = arguments.dropFirst().first.flatMap(WindowMode.init(rawValue:)) ?? .fullScreen
    let finished = DispatchSemaphore(value: 0)
    do {
        _ = try GameLauncher.launch(game, settings: LaunchSettings(windowMode: mode), locations: locations) { status in
            print("exited (\(status)), log: \(locations.log.path)")
            finished.signal()
        }
    } catch {
        fail("could not launch: \(error)")
    }
    finished.wait()
default:
    fail(usage)
}
