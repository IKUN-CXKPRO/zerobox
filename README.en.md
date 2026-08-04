# OronBox

A pretty fast wearable management tool for VelaOS and ZeppOS, built with Flutter

[简体中文](README.md) · English

> ⚠️ This project is under active development and is not yet production-ready

## What is OronBox?

OronBox is a cross-platform wearable device management tool that lets you connect, manage and install resources on VelaOS / Xiaomi and ZeppOS devices without the official client

## Supported platforms

| Platform | Status | Notes |
|----------|--------|-------|
| Android | ✅ Supported | Tested on CrDroid 12.11 (Android 16) |
| Linux | ✅ Supported | Tested on Arch Linux x86_64 |
| Web | ✅ Supported | Tested on Chromium 150; requires a browser with Web Serial / Bluetooth support |
| macOS | ✅ Supported | Tested on macOS 27 (Beta 3) |
| Windows | ✅ Supported | Tested on Windows 11 25H2 |
| iOS | ❌ Not supported | No plans yet |

## Features status

| Feature | Status |
|---------|--------|
| VelaOS / Xiaomi device connection | ✅ Done |
| Install watch faces, mini apps and firmware packages | ✅ Done |
| Xiaomi account login with 2FA | ✅ Done |
| AstroBox-Repo community source integration | ✅ Done |
| Optimize resource installation flow | ✅ Done |
| Optimize device connection experience | ✅ Done |
| Integrate BandBBS OAuth login for BandBBS community resources | ✅ Done |
| Creator center, one-click publish resources to BandBBS / AstroBox-Repo | ✅ Done |
| Home page improvements | 🚧 WIP |

## CLI usage

OronBox provides a powerful, scriptable command-line interface for managing devices, installing resources, accessing community sources and controlling background tasks without the GUI. See the [OronBox CLI and daemon documentation](docs/en/CLI.md) for usage details.

## Build from source

### Prerequisites

- Flutter stable (we recommend managing it with [fvm](https://fvm.app); the repo root `.fvmrc` pins the version), then `flutter pub get`
- The `oronbox_network` network plugin downloads prebuilt binaries from GitHub Releases at build time, so no Rust toolchain is required
- Platform-specific dependencies:
  - **Linux**: `gtk3` `webkit2gtk-4.1` `bluez` `libblkid` `libasound2` (`libasound2-dev` when building) `xz`; packaging tools as needed: `dpkg-deb` (deb), `rpmbuild` (rpm), `makepkg` (arch), `linuxdeploy` or `appimagetool` (AppImage), `flatpak-builder` with the GNOME SDK (Flatpak)
  - **Android**: the Android SDK/NDK bundled with a standard Flutter setup
  - **Windows**: Visual Studio 2022 (Desktop development with C++); the WebView2 SDK can be installed via `windows/scripts/install_webview2_sdk.ps1`
  - **macOS**: Xcode; can only be built on a macOS host
  - **Web**: no extra dependencies

### Build everything

```bash
tool/build_all.sh [--dev]
```

Builds Android + Web + the desktop platform of the current host. Artifacts land in `build/release/` along with a generated `sha256sums.txt`.

### Per-platform builds

```bash
# Android
tool/build_android.sh [--format apk|appbundle|all] [--abi arm64-v8a|armeabi-v7a|x86_64]

# Linux
tool/build_linux.sh [--format tar.gz|deb|rpm|arch|appimage|flatpak|all] [--abi x86_64|aarch64]

# macOS (macOS hosts only)
tool/build_macos.sh

# Windows (either one)
tool\build_windows.bat [--dev]
powershell -File tool/build_windows.ps1 [-Dev] [-SkipWebView2Sdk] [-WebView2SdkVersion <version>]

# Web
tool/build_web.sh
```

- Without `--format` / `--abi`, every format / ABI is built; on Linux `--abi` defaults to the host architecture
- Android release signing is configured through environment variables: `ORONBOX_KEYSTORE_PATH`, `ORONBOX_KEYSTORE_PASSWORD`, `ORONBOX_KEY_ALIAS`, `ORONBOX_KEY_PASSWORD`; without them the debug signing config is used
- Cross-building Linux aarch64 from an x86_64 host requires `ORONBOX_LINUX_ARM64_SYSROOT` pointing to an arm64 sysroot with the gtk3/webkit2gtk/alsa development packages; cross mode only produces tar.gz / deb / rpm / arch packages

### Versioning and artifact conventions

- The version comes from the `version` field in `pubspec.yaml`
- A clean git worktree is required by default; `--dev` allows a dirty worktree and appends git metadata to the version (e.g. `1.0.0.dirty.abc1234`)
- Artifacts are named `oronbox-<version>-<platform>[-<arch>].<ext>`; symbol archives (when present) accompany the packages

## AI development disclosure

This project was developed with the help of AI agent tools

Usage:

| Model | Areas assisted |
|-------|----------------|
| ChatGPT 5.5/5.6-Sol | Dart Bluetooth connection behavior/protocol, backend rewrite, parts of the frontend |
| Kimi K3 | OOBE, creator-related logic |
| Kimi K2.6 | Parts of the frontend, UI/UX, initial backend |

## Acknowledgements

OronBox benefits from the following excellent projects:

| Project | What we referenced |
|---------|--------------------|
| [AstroBox-Public](https://github.com/AstralSightStudios/AstroBox-Public) | UI structure, resource flow and interaction design |
| [AstroBox-NG-Module-Core](https://github.com/AstralSightStudios/AstroBox-NG-Module-Core) | Xiaomi device protocol, installation flow and transfer behavior |
| [AstroBox-NG-Module-Bluetooth](https://github.com/AstralSightStudios/AstroBox-NG-Module-Bluetooth) | Bluetooth connection behavior |
| [AstroBox-NG-Module-Account](https://github.com/AstralSightStudios/AstroBox-NG-Module-Account) | Xiaomi account login, device sync and authkey retrieval |
| [AstroBox-NG-Module-Provider](https://github.com/AstralSightStudios/AstroBox-NG-Module-Provider) | Community resource index, CDN and manifest parsing |
| [AstroBox-NG-Module-AppWasm](https://github.com/AstralSightStudios/AstroBox-NG-Module-AppWasm) | Web Serial and browser-side connection flow |
| [Gadgetbridge](https://codeberg.org/Freeyourgadget/Gadgetbridge) | ZeppOS and wearable device protocol research |
| [Kazumi](https://github.com/Predidit/Kazumi) | Material Design components and UI design |

## License

OronBox is licensed under the [GNU Affero General Public License v3.0](LICENSE)
