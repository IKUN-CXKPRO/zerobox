# ZeroBox

一个又好看又快的 VelaOS / ZeppOS 可穿戴设备管理软件，使用 Flutter 构建

[English](README.en.md) · 简体中文

> ⚠️ 这是一个正在开发中的项目：ZeroBox 仍在积极开发，尚未达到生产可用状态

## ZeroBox 是什么？

ZeroBox 是一款跨平台可穿戴设备管理工具，无需官方客户端，即可连接、管理 VelaOS / 小米与 ZeppOS 设备，并为其安装资源

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
| 创作者中心，一键发布资源到 米坛 / AstroBox-Repo | 🚧 WIP |
| 首页完善 | 🚧 WIP |

## CLI 使用

ZeroBox 提供功能完整且可脚本化的命令行界面，可在无 GUI 模式下管理设备、安装资源、访问社区源以及控制后台任务，详细用法参见 [ZeroBox CLI 与守护进程文档](docs/zh/CLI.md)

## 从源码构建

~~需要先安装 [Flutter](https://docs.flutter.dev/get-started/install)~~

## AI 开发声明

本项目使用了 AI Agent 工具协助开发

使用情况：
| 模型 | 协助的部分 |
|------|------|
| ChatGPT 5.5/5.6-Sol | Dart 蓝牙连接行为/协议、后端逻辑重写、部分前端 |
| Kimi K2.6 | 部分前端、UI/UX、初版后端 |

## 鸣谢

ZeroBox 受益于以下优秀项目：

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

ZeroBox 采用 [GNU Affero General Public License v3.0](LICENSE) 许可证
