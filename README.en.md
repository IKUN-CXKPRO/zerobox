# ZeroBox

A pretty fast wearable management tool for VelaOS and ZeppOS, built with Flutter

[简体中文](README.md) · English

> ⚠️ This project is under active development and is not yet production-ready

## What is ZeroBox?

ZeroBox is a cross-platform wearable device management tool that lets you connect, manage and install resources on VelaOS / Xiaomi and ZeppOS devices without the official client

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
| Creator center, one-click publish resources to BandBBS / AstroBox-Repo | 🚧 WIP |
| Home page improvements | 🚧 WIP |

## Build from source

~~You need [Flutter](https://docs.flutter.dev/get-started/install) installed~~

## AI development disclosure

This project was developed with the help of AI agent tools

Usage:

| Model | Areas assisted |
|-------|----------------|
| ChatGPT 5.5/5.6-Sol | Dart Bluetooth connection behavior/protocol, backend rewrite, parts of the frontend |
| Kimi K2.6 | Parts of the frontend, UI/UX, initial backend |

## Acknowledgements

ZeroBox benefits from the following excellent projects:

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

ZeroBox is licensed under the [GNU Affero General Public License v3.0](LICENSE)
