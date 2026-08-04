# OronBox

一个又好看又快的 VelaOS / ZeppOS 可穿戴设备管理软件，使用 Flutter 构建

[English](README.en.md) · 简体中文

> ⚠️ 这是一个正在开发中的项目：OronBox 仍在积极开发，尚未达到生产可用状态

## OronBox 是什么？

OronBox 是一款跨平台可穿戴设备管理工具，无需官方客户端，即可连接、管理 VelaOS / 小米与 ZeppOS 设备，并为其安装资源

## 支持平台

| 平台 | 状态 | 说明 |
|------|------|------|
| Android | ✅ 已支持 | 已在 CrDroid 12.11 (Android16) 上测试 |
| Linux | ✅ 已支持 | 已在 Arch Linux x86_64 上测试 |
| Web | ✅ 已支持 | 已在 Chromium 150 上测试，需要浏览器支持 Web Serial / Bluetooth |
| macOS | ✅ 已支持 | 已在 macOS 27 (Beta3) 上测试 |
| Windows | ✅ 已支持 | 已在 Windows 11 25H2 上测试 |
| iOS | ❌ 不支持 | 暂无计划 |

## 功能状态

| 功能 | 状态 |
|------|------|
| VelaOS / 小米设备连接 | ✅ 已完成 |
| 安装表盘、快应用、固件包 | ✅ 已完成 |
| 小米账号登录，支持 2FA | ✅ 已完成 |
| AstroBox-Repo 社区源接入 | ✅ 已完成 |
| 优化资源安装流程 | ✅ 已完成 |
| 优化设备连接体验 | ✅ 已完成 |
| 接入米坛 OAuth 登录，获取米坛社区资源 | ✅ 已完成 |
| 创作者中心，一键发布资源到 米坛 / AstroBox-Repo | ✅ 已完成 |
| 首页完善 | 🚧 WIP |

## CLI 使用

OronBox 提供功能完整且可脚本化的命令行界面，可在无 GUI 模式下管理设备、安装资源、访问社区源以及控制后台任务，详细用法参见 [OronBox CLI 与守护进程文档](docs/zh/CLI.md)

## 从源码构建

### 环境准备

- Flutter stable（推荐用 [fvm](https://fvm.app) 管理，仓库根目录的 `.fvmrc` 已指定版本），然后 `flutter pub get`
- 网络插件 `oronbox_network` 在构建时自动从 GitHub Release 下载预编译库，无需 Rust 工具链
- 各平台额外依赖：
  - **Linux**：`gtk3` `webkit2gtk-4.1` `bluez` `libblkid` `libasound2`（构建时为 `libasound2-dev`）`xz`；打包工具按需：`dpkg-deb`（deb）、`rpmbuild`（rpm）、`makepkg`（arch）、`linuxdeploy` 或 `appimagetool`（AppImage）、`flatpak-builder` 与 GNOME SDK（Flatpak）
  - **Linux ARM64**：还需 `libflac-dev` `libogg-dev` `libopus-dev` `libvorbis-dev`；`flutter_soloud` 的配套 Xiph `.so` 仅适用于 amd64，ARM64 会自动切换到系统库，ARM64 产物也会声明对应运行时依赖
  - **Android**：Flutter 标配的 Android SDK/NDK
  - **Windows**：Visual Studio 2022（C++ 桌面工作负载）；WebView2 SDK 可用脚本安装：`windows/scripts/install_webview2_sdk.ps1`
  - **macOS**：Xcode，仅可在 macOS 主机构建
  - **Web**：无额外依赖

### 一键构建

```bash
tool/build_all.sh [--dev]
```

构建 Android + Web + 当前宿主桌面平台，产物统一输出到 `build/release/`，并生成 `sha256sums.txt`。

### 分平台构建

```bash
# Android
tool/build_android.sh [--format apk|appbundle|all] [--abi arm64-v8a|armeabi-v7a|x86_64]

# Linux
tool/build_linux.sh [--format tar.gz|deb|rpm|arch|appimage|flatpak|all] [--abi x86_64|aarch64]

# macOS（仅 macOS 主机）
tool/build_macos.sh

# Windows（任选其一）
tool\build_windows.bat [--dev]
powershell -File tool/build_windows.ps1 [-Dev] [-SkipWebView2Sdk] [-WebView2SdkVersion <版本>]

# Web
tool/build_web.sh
```

- `--format` / `--abi` 缺省时构建全部格式 / 全部 ABI；Linux `--abi` 缺省取宿主架构
- Android 发布签名通过环境变量配置：`ORONBOX_KEYSTORE_PATH`、`ORONBOX_KEYSTORE_PASSWORD`、`ORONBOX_KEY_ALIAS`、`ORONBOX_KEY_PASSWORD`；未设置时使用 debug 签名
- Linux 交叉编译 aarch64（x86_64 宿主）需将 `ORONBOX_LINUX_ARM64_SYSROOT` 指向包含 gtk3/webkit2gtk/alsa/flac/ogg/opus/vorbis 等开发包的 arm64 sysroot；交叉模式只产出 tar.gz / deb / rpm / arch

### 版本与产物约定

- 版本号取自 `pubspec.yaml` 的 `version` 字段
- 默认要求 git 工作区干净；加 `--dev` 允许脏工作区并在版本号后附加 git 元数据（如 `1.0.0.dirty.abc1234`）
- 产物命名：`oronbox-<version>-<platform>[-<arch>].<ext>`，符号表（如有）随包一并归档

## AI 开发声明

本项目使用了 AI Agent 工具协助开发

使用情况：
| 模型 | 协助的部分 |
|------|------|
| GPT 5.5/5.6-Sol | Dart 蓝牙连接行为/协议、后端逻辑重写、部分前端 |
| GPT 5.6-Luna | GitHub CI / Release 脚本重写与修复 |
| Kimi K3 | OOBE、创作者相关逻辑 |
| Kimi K2.6 | 部分前端、UI/UX、初版后端 |

## 鸣谢

OronBox 受益于以下优秀项目：

| 项目 | 参考的内容 |
|------|----------------|
| [AstroBox-Public](https://github.com/AstralSightStudios/AstroBox-Public) | 界面结构、资源流程与交互设计 |
| [AstroBox-NG-Module-Core](https://github.com/AstralSightStudios/AstroBox-NG-Module-Core) | 小米设备协议、安装流程与传输行为 |
| [AstroBox-NG-Module-Bluetooth](https://github.com/AstralSightStudios/AstroBox-NG-Module-Bluetooth) | 蓝牙连接行为 |
| [AstroBox-NG-Module-Account](https://github.com/AstralSightStudios/AstroBox-NG-Module-Account) | 小米账号登录、设备同步与 authkey 获取 |
| [AstroBox-NG-Module-Provider](https://github.com/AstralSightStudios/AstroBox-NG-Module-Provider) | 社区资源索引、CDN 与清单解析 |
| [AstroBox-NG-Module-AppWasm](https://github.com/AstralSightStudios/AstroBox-NG-Module-AppWasm) | Web Serial 与浏览器端连接流程 |
| [Gadgetbridge](https://codeberg.org/Freeyourgadget/Gadgetbridge) | ZeppOS 与可穿戴设备协议研究 |
| [Kazumi](https://github.com/Predidit/Kazumi) | Material Design 组件与界面设计 |

## 许可证

OronBox 采用 [GNU Affero General Public License v3.0](LICENSE) 许可证
