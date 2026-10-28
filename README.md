# Blockport

Runs the iOS version of Minecraft Bedrock natively on Apple Silicon Macs. It
converts your own copy of the game into a Mac Catalyst app and loads a small
runtime that patches the iPad behaviour the game relies on. No emulator, no
Rosetta: arm64 on the CPU, Metal on the GPU.

Not affiliated with Mojang or Microsoft. Contains no game files: you need a copy
bought on the App Store with your own Apple account.

## Requirements

- Apple Silicon Mac, macOS 15 or later
- A decrypted IPA of your copy, downloaded with
  [ipatool](https://github.com/majd/ipatool) and decrypted with
  [unfairplay](https://github.com/DrWhax/unfairplay)
- Xcode 26 to build

## Usage

```sh
scripts/build-app.sh
open dist/Blockport.app
```

Drop the IPA on the window, then press Play. The game is installed in
`~/Library/Application Support/Blockport`, its data in `GameData` next to it,
and its log in `~/Library/Logs/Blockport`.

## How it works

The installer marks every binary as Mac Catalyst (`LC_BUILD_VERSION`), adds a
load command for the runtime, patches `Info.plist` (resizable window, Mac
idiom, Game Mode) and signs the app locally.

The runtime replaces C functions through a dyld `__interpose` table and
Objective-C methods through the runtime:

- **Keychain**: without a Team ID, `SecItem*` fails under Catalyst. Secrets and
  the Xbox Live device key are kept in one encrypted item of the login
  keychain, through the older `SecKeychain*` API.
- **Display**: the game reads the screen size once, so it gets a fixed
  resolution and its view is scaled to the window.
- **Input**: pointer lock, no key beep, repaired mouse and keyboard setup,
  working scroll wheel.
- **Performance**: real available memory instead of 0, no busy-waiting in
  loading threads, up to 120 Hz on power, lighter defaults in `options.txt`.
- **Lifecycle**: clean exit after saving, no freeze with some VPNs, game data
  outside `~/Documents`.

## Development

```sh
swift test
scripts/build-catalyst.sh   # runtime only
scripts/build-app.sh        # dist/Blockport.app
```

Set `BLOCKPORT_TRACE=1` to log the runtime's decisions in the game log.

## License

MIT. Minecraft is a trademark of Mojang Synergies AB.
