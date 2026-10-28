# Blockport

Blockport runs the iOS version of Minecraft Bedrock natively on Apple Silicon
Macs. It converts your own copy of the game into a Mac Catalyst app and loads a
small runtime that supplies what an iOS game expects but a Mac does not
provide. There is no emulator, virtual machine or Rosetta: the game's arm64 code
runs on the CPU and renders with Metal on the GPU.

Blockport is not affiliated with Mojang or Microsoft and contains no game files.
You need a copy of Minecraft bought on the App Store with your own Apple
account.

## Requirements

- An Apple Silicon Mac with macOS 15 or later.
- A decrypted IPA from your own purchase:
  - download it with [ipatool](https://github.com/majd/ipatool);
  - decrypt it on your Mac with [unfairplay](https://github.com/DrWhax/unfairplay).
- To build from source: Xcode 26.

Do not share the IPA or the converted app. Each player needs their own copy.

## Usage

```sh
scripts/build-app.sh
open dist/Blockport.app
```

Drop the decrypted IPA on the window. Blockport installs the game in
`~/Library/Application Support/Blockport` and starts it from there. The game
keeps its worlds, options and sign-in files in
`~/Library/Application Support/Blockport/GameData`, and writes its log to
`~/Library/Logs/Blockport/minecraft.log`.

The main window offers the display mode and a performance profile. Advanced
settings (resolution, render sharpness, frame rate on power and on battery, CPU
optimisation) are in the Settings window. The interface is available in
English, French, German and Spanish.

## Approach

An Apple Silicon Mac can execute iOS arm64 code, and macOS ships the iOS
frameworks for Mac Catalyst. What stands between a decrypted iOS game and a
working Mac app is a set of assumptions the game makes about its platform. Each
section below describes one of them, why it breaks on a Mac, and what Blockport
does about it. The fixes were found by running the game, tracing what failed,
and testing each change against the real game.

### 1. Getting the binary to run

macOS only runs iOS apps installed from the App Store and signed by Apple. A
re-signed iOS binary is refused. The installer therefore declares every binary
in the bundle as Mac Catalyst instead of iOS:

- It rewrites the platform in the `LC_BUILD_VERSION` load command (from iOS, 2,
  to Mac Catalyst, 6). Two frameworks still use the older
  `LC_VERSION_MIN_IPHONEOS` command; it is replaced by an `LC_BUILD_VERSION`
  command, using free space after the load commands.
- It removes the iOS signatures and store licences, restores the executable
  bit that decrypted IPAs often lose, and signs the app locally (ad hoc).

All frameworks the game links exist on macOS, natively or in
`/System/iOSSupport`.

### 2. Loading the runtime

The installer adds an `LC_LOAD_DYLIB` command for
`libBlockportRuntime.dylib` to the game executable, so the runtime loads with
the game like any of its frameworks. Its constructor runs before the game's own
code and installs two kinds of replacements:

- C functions (keychain, memory, threads, networking, exit) are replaced with a
  dyld `__interpose` table.
- Objective-C methods (screen, view layout, input, display link) are replaced
  through the Objective-C runtime, on the most specific class possible.

### 3. Keychain

The game, PlayFab and the Xbox Live library store their secrets in the keychain.
An iOS app under Mac Catalyst uses the data protection keychain, which requires
an entitlement tied to a developer Team ID. A locally signed app has none, so
every call fails with `errSecMissingEntitlement` and the game crashes at launch
("Couldn't add the Keychain Item").

Redirecting the calls to the login keychain does not work: under Catalyst,
`SecItem*` targets the data protection keychain whatever the query says. The
older file-based `SecKeychain*` API still works from a Catalyst process. The
runtime therefore answers `SecItemAdd`, `SecItemCopyMatching`, `SecItemUpdate`
and `SecItemDelete` itself:

- Generic passwords and keys are held in memory, in a vault saved as a single
  encrypted item of the login keychain. One item means macOS asks at most once
  for access after the app's signature changes, instead of once per secret.
- The game reads `kSecAttrAccessGroup` back to learn its Team ID prefix. The
  installer records the original application identifier, and the runtime
  reports it.
- Xbox Live generates a permanent key pair as its device proof key, with
  `SecKeyGeneratePair`. Without that key, sign-in fails with the error
  "Drowned". The runtime generates the pair in memory, stores both halves in
  the vault with the attributes the keychain would have set (including the
  application label, the SHA-1 of the public key), and finds them again when
  the library queries by label or persistent reference.

### 4. Display

An iPad app under Catalyst is scaled to 77% and rendered above the display's
resolution. The installer adds the Mac device family to `Info.plist`, so the
game renders at the display's pixels. It also clears `UIRequiresFullScreen` and
declares every orientation, without which Catalyst keeps the window at a fixed
iPad size.

The game reads the screen size once, at launch, and never again: an iPad's
screen does not change size. When the window is resized, the engine keeps
rendering at its original size, which letterboxes the picture and offsets the
mouse. Blockport therefore gives the game a fixed
screen from launch, by default the display's full-screen area, and its view
keeps that size. A scale transform fits the view to the window. UIKit maps
pointer locations through the transform, so input stays aligned, and MetalKit
never sees the view change size. The window keeps the game's aspect ratio.

### 5. Input

- The game reads the mouse and keyboard through GameController and asks for
  pointer lock with `prefersPointerLocked`, which Catalyst does not enforce for
  a window. The runtime follows the game's requests and locks the cursor with
  CoreGraphics, releasing it when another app is active. The game requests a
  lock update on every mouse move; only changes are forwarded.
- Because no view consumes the key events, AppKit plays the alert sound on
  every key press. The runtime silences it for unhandled key presses only.
- The game sets up its mouse and keyboard handlers for whichever device is
  current when it starts. On a Mac a device can connect before the game listens,
  leaving clicks or keys dead for the session. The runtime re-runs the game's
  own setup for every device without a handler.
- The game reads the scroll wheel from the horizontal axis; the runtime passes
  vertical scrolling to it.

### 6. Performance

- `os_proc_available_memory` reports how much an iOS process may still
  allocate. On macOS it returns 0, so the game believes it is out of memory.
  The runtime reports half the physical memory minus the current footprint.
- The game's chunk-streaming threads spin on `sched_yield` between jobs. A
  thread that yields repeatedly within microseconds sleeps for 50 µs instead.
- The game's display link is pinned to 60 Hz. The runtime allows up to 120 Hz
  on power and a lower rate on battery or in Low Power Mode.
- A render scale lowers the resolution the game renders at, through the view's
  content scale, so every drawable stays consistent with the engine.
- On first launch, `options.txt` gets the Simple graphics mode, the classic
  interface profile and vsync. Later changes made in the game are kept.
- The installer declares the app as a game, which enables macOS Game Mode in
  full screen.

### 7. Lifecycle and data

- UIKit ends the app with `exit`, whose static destructors crash under the
  game's running threads and leave a process behind. Once the termination
  callbacks have run and the game has saved, the runtime exits directly.
- With some VPN interfaces, the game resolves the placeholder host `Error`
  every frame, and each lookup takes five seconds to fail. The runtime fails it
  immediately.
- Without a sandbox, the game would write to the user's Documents folder. The
  runtime redirects the Documents lookup (`NSSearchPathForDirectoriesInDomains`
  and `FileManager`) to the GameData folder.

## Architecture

| Target | Platform | Role |
| --- | --- | --- |
| `BlockportLauncher` | macOS | SwiftUI launcher: install, settings, launch |
| `BlockportCore` | macOS | Installer (Mach-O patching, Info.plist, icon, signing) and game launcher |
| `blockport` | macOS | Command-line installer and launcher, for development |
| `BlockportShared` | both | Launch settings and data location, passed through the environment |
| `BlockportRuntime` | Catalyst | Runtime loaded into the game |
| `BlockportNative` | Catalyst | Replacements written in C for speed (`sched_yield`, `getaddrinfo`, `exit`, Documents lookup) |
| `BlockportInterpose` | Catalyst | dyld interpose table and library constructor |
| `CLegacyKeychain`, `CMacDisplay` | Catalyst | Declarations of macOS APIs the SDK marks unavailable for Catalyst |

## Development

```sh
swift test                                # unit tests (macOS)
scripts/build-catalyst.sh                 # runtime for Mac Catalyst
scripts/build-app.sh                      # dist/Blockport.app with the runtime inside
scripts/make-icon.sh                      # regenerate the app icon
```

The launcher passes its settings to the runtime through the environment:

| Variable | Values | Default |
| --- | --- | --- |
| `BLOCKPORT_WINDOW_MODE` | `fullscreen`, `window` | `fullscreen` |
| `BLOCKPORT_RESOLUTION` | `WIDTHxHEIGHT` in points | full-screen area |
| `BLOCKPORT_RENDER_SCALE` | 0.5 to 3 | display scale |
| `BLOCKPORT_FPS` | frames per second | display range |
| `BLOCKPORT_BATTERY_FPS` | frames per second, `0` for as on power | 60 |
| `BLOCKPORT_YIELD` | `spin` to disable the thread backoff | backoff on |
| `BLOCKPORT_DATA_DIR` | game data folder | `~/Library/Application Support/Blockport/GameData` |
| `BLOCKPORT_TRACE` | any value, to log the runtime's decisions | off |

## Known limitations

- After each install or update, macOS may ask once for access to the keychain
  item, because the local signature changes.
- The window keeps the game's aspect ratio.
- The game must be signed in again after the data folder changes.

## License

MIT. Minecraft is a trademark of Mojang Synergies AB. This project is not
affiliated with or endorsed by Mojang or Microsoft.
