# Gadgetbridge Zepp OS 41 个 Service 功能研究清单

## 1. 文档口径

本文依据仓库内的 Gadgetbridge 源码整理：

- 服务注册入口：`common/Gadgetbridge/app/src/main/java/nodomain/freeyourgadget/gadgetbridge/service/devices/huami/zeppos/ZeppOsSupport.java`
- 服务实现目录：`common/Gadgetbridge/app/src/main/java/nodomain/freeyourgadget/gadgetbridge/service/devices/huami/zeppos/services`

当前 `ZeppOsSupport` 注册了 **41 个服务实例**。源码中实际有 40 个被注册的 `*Service` 类，因为 `ZeppOsAssistantService` 被实例化了两次，分别服务于 Alexa（endpoint `0x0011`）和 Zepp Flow（endpoint `0x004A`）。因此“41 个 Service”指 41 个实际服务实例/endpoint，而不是 41 个不同 Java 类。

Zepp OS 连接后会先通过 endpoint `0x0000` 获取设备实际支持的服务列表。并非每款设备都提供下表全部服务；同一个 endpoint 是否要求加密，也必须以设备返回的服务表为准，不能仅凭本表写死。

## 2. 41 个 Service 总表

| # | Service 实例 | Endpoint | 主要功能 | 典型方向 |
|---:|---|---:|---|---|
| 1 | Services | `0x0000` | 查询设备支持的 endpoint 列表及加密标志，是其他上层功能的能力发现入口 | 双向 |
| 2 | Authentication | `0x0082` | 使用 authkey 完成 Zepp OS 身份认证、密钥协商和会话建立 | 双向 |
| 3 | File Transfer | `0x000D` | 通用文件传输框架，负责传输协商、分块、进度、完成和失败处理 | 双向 |
| 4 | Config | `0x000A` | 读取和写入设备配置项，包括大量开关、阈值、时间段和行为设置 | 双向 |
| 5 | AGPS | `0x0042` | 查询辅助定位数据状态，并配合文件传输更新 AGPS 数据 | 手机→设备为主 |
| 6 | Wi-Fi | `0x0003` | Wi-Fi 状态、网络扫描、网络配置及相关响应处理 | 双向 |
| 7 | FTP Server | `0x0006` | 控制设备侧 FTP 服务，用于某些较大资源或特殊数据交换流程 | 双向 |
| 8 | Contacts | `0x0014` | 同步联系人、联系人头像及相关元数据 | 手机→设备为主 |
| 9 | Morning Updates | `0x003F` | 配置“晨间更新”内容和开关，使设备展示睡眠、天气、日程等摘要 | 手机→设备为主 |
| 10 | Phone | `0x000B` | 电话状态桥接，包括来电、接听、拒接、静音和通话状态交互 | 双向 |
| 11 | Shortcut Cards | `0x0009` | 查询、排序和配置设备快捷卡片/负一屏卡片 | 双向 |
| 12 | Watchface | `0x0023` | 查询表盘、切换当前表盘、删除表盘及表盘相关管理 | 双向 |
| 13 | Alarms | `0x000F` | 查询、创建、修改、启停和删除设备闹钟 | 双向 |
| 14 | Calendar | `0x0007` | 同步日历事件、日程提醒及事件删除/更新 | 手机→设备为主 |
| 15 | Canned Messages | `0x0013` | 管理快捷回复/预设回复，并处理设备选择回复后的回传 | 双向 |
| 16 | Notification | `0x001E` | 推送、更新、撤回通知；可结合文件传输发送通知图片或附件 | 手机→设备为主 |
| 17 | Alexa Assistant | `0x0011` | Alexa 语音助手会话、语音数据和状态交互 | 双向 |
| 18 | Zepp Flow Assistant | `0x004A` | Zepp Flow 助手会话、语音数据和状态交互；与 Alexa 共用实现类 | 双向 |
| 19 | Apps | `0x00A0` | 查询、启动、卸载和管理 Zepp OS 应用及应用列表 | 双向 |
| 20 | Logs | `0x003A` | 请求设备日志、接收日志元数据，并配合传输流程导出日志 | 设备→手机为主 |
| 21 | Display Items | `0x0026` | 查询并调整设备菜单项目、功能入口的显示和排序 | 双向 |
| 22 | HTTP | `0x0001` | 代理设备发起的 HTTP 请求，返回网络响应或通过文件传输交付内容 | 双向 |
| 23 | Reminders | `0x0038` | 同步、更新和删除设备提醒事项 | 双向 |
| 24 | Loyalty Card | `0x003C` | 管理会员卡/条码卡片及其显示数据 | 手机→设备为主 |
| 25 | Voice Memos | `0x0033` | 查询、下载和删除设备录制的语音备忘录 | 设备→手机为主 |
| 26 | Maps | `0x0046` | 地图资源、导航地图数据及相关下载请求的协调 | 双向 |
| 27 | Music | `0x001B` | 设备音乐文件和曲目管理；区别于手机媒体播放控制 | 双向 |
| 28 | Find Device | `0x001A` | 手机触发设备振动/响铃；包含能力查询、启动 ACK、开始和停止查找 | 双向 |
| 29 | Silent Mode | `0x003B` | 查询和设置静音/勿扰状态以及相关模式 | 双向 |
| 30 | User Info | `0x0017` | 向设备同步用户资料，例如性别、生日、身高和体重等 | 手机→设备为主 |
| 31 | Vibration Patterns | `0x0018` | 查询和配置自定义振动模式/振动节奏 | 双向 |
| 32 | Battery | `0x0029` | 查询电量百分比、充电状态等电池信息 | 设备→手机为主 |
| 33 | Weather | `0x000E` | 同步当前天气、预报、位置及天气相关数据 | 手机→设备为主 |
| 34 | Connection | `0x0015` | 连接保活及连接状态控制，包含设备 PING 与手机 PONG | 双向 |
| 35 | World Clocks | `0x0008` | 查询、同步、排序和删除世界时钟城市 | 双向 |
| 36 | Workout | `0x0019` | 运动控制和实时运动交互，例如开始/暂停/继续/结束及状态上报 | 双向 |
| 37 | Heart Rate | `0x001D` | 心率相关控制和实时心率数据交互 | 双向 |
| 38 | Steps | `0x0016` | 获取或接收步数等当日活动概览数据 | 设备→手机为主 |
| 39 | Activity Fetch | `0x004B` | 拉取设备保存的活动/健康历史数据，并交给 Gadgetbridge fetcher 处理 | 设备→手机为主 |
| 40 | Time | `0x0047` | 同步系统时间、时区和时间格式等时间信息 | 手机→设备为主 |
| 41 | Device Info | `0x0043` | 查询设备软硬件、版本、序列信息和其他设备属性 | 设备→手机为主 |

“典型方向”只描述主要业务方向，不代表协议只能单向通信。绝大多数 Service 都需要设备返回 ACK、状态或错误响应。

## 3. 按能力领域分类

### 3.1 协议基础设施

1. Services（`0x0000`）
2. Authentication（`0x0082`）
3. Connection（`0x0015`）
4. File Transfer（`0x000D`）
5. HTTP（`0x0001`）
6. FTP Server（`0x0006`）
7. Time（`0x0047`）
8. Device Info（`0x0043`）

这些服务是许多其他功能的基础。其中 Authentication、Connection、File Transfer 涉及连接与会话稳定性。对 ZeroBox 而言，它们属于高风险区域，不能为了实现普通上层功能而顺手重构。

### 3.2 日常设置与设备界面

1. Config（`0x000A`）
2. Display Items（`0x0026`）
3. Shortcut Cards（`0x0009`）
4. Silent Mode（`0x003B`）
5. Vibration Patterns（`0x0018`）
6. Watchface（`0x0023`）
7. Apps（`0x00A0`）
8. Wi-Fi（`0x0003`）
9. User Info（`0x0017`）

### 3.3 提醒、通信与个人信息

1. Notification（`0x001E`）
2. Phone（`0x000B`）
3. Contacts（`0x0014`）
4. Canned Messages（`0x0013`）
5. Alarms（`0x000F`）
6. Calendar（`0x0007`）
7. Reminders（`0x0038`）
8. Morning Updates（`0x003F`）
9. World Clocks（`0x0008`）

### 3.4 健康与运动

1. Battery（`0x0029`，状态类能力）
2. Steps（`0x0016`）
3. Heart Rate（`0x001D`）
4. Workout（`0x0019`）
5. Activity Fetch（`0x004B`）

### 3.5 内容、网络与大文件

1. Weather（`0x000E`）
2. Music（`0x001B`）
3. Maps（`0x0046`）
4. AGPS（`0x0042`）
5. Logs（`0x003A`）
6. Voice Memos（`0x0033`）
7. Loyalty Card（`0x003C`）

这组功能常常依赖 File Transfer、HTTP 或设备侧 FTP，不应只移植单一 endpoint 的表面命令。

### 3.6 助手与交互

1. Alexa Assistant（`0x0011`）
2. Zepp Flow Assistant（`0x004A`）
3. Find Device（`0x001A`）

## 4. ZeroBox 当前覆盖情况

截至本文整理时，ZeroBox 已具备以下 Zepp OS 上层系统：

| ZeroBox System | Endpoint | 当前能力 |
|---|---:|---|
| `ZeppOsAuthSystem` | `0x0082` | authkey 认证与会话密钥建立 |
| `ZeppOsServicesSystem` | `0x0000` | 服务列表和 endpoint 加密标志查询 |
| `ZeppOsBatterySystem` | `0x0029` | 电量与充电状态查询 |
| `ZeppOsFindDeviceSystem` | `0x001A` | 基础开始/停止查找 |

其中查找设备目前只覆盖基础开始和停止命令。Gadgetbridge 还实现了能力查询、能力响应、启动 ACK，以及对部分旧设备的周期性重复触发逻辑，这些可以作为 ZeroBox 下一步较安全的上层完善方向。

## 5. 建议研究和移植顺序

### 第一阶段：低风险、可独立验证

1. 完善 Find Device（`0x001A`）能力协商和 ACK。
2. Device Info（`0x0043`），用于展示固件和硬件信息。
3. Time（`0x0047`），功能边界清晰。
4. World Clocks（`0x0008`）。
5. Silent Mode（`0x003B`）。
6. Alarms（`0x000F`）与 Reminders（`0x0038`）。

### 第二阶段：设备设置和内容同步

1. Config（`0x000A`），但应按配置项逐个移植，不要一次照搬全部枚举。
2. Display Items（`0x0026`）和 Shortcut Cards（`0x0009`）。
3. Weather（`0x000E`）。
4. Calendar（`0x0007`）和 Contacts（`0x0014`）。
5. Notification（`0x001E`）与 Phone（`0x000B`）。

### 第三阶段：复杂状态与大文件

1. Watchface（`0x0023`）和 Apps（`0x00A0`）。
2. Activity Fetch（`0x004B`）、Workout（`0x0019`）和 Heart Rate（`0x001D`）。
3. File Transfer（`0x000D`）依赖功能：Music、Maps、AGPS、Logs、Voice Memos。
4. HTTP（`0x0001`）、FTP Server（`0x0006`）和 Wi-Fi（`0x0003`）。
5. Alexa/Zepp Flow 语音助手。

## 6. 每个 Service 移植到 ZeroBox 时的检查模板

每新增一个功能，建议依次确认：

1. 设备通过 `0x0000` 服务列表声明了目标 endpoint。
2. 读取服务列表返回的加密标志，不能凭经验固定明文或密文。
3. 阅读对应 Gadgetbridge Service 的全部命令常量、请求格式、响应格式和错误分支。
4. 判断是否依赖 File Transfer、HTTP、FTP、配置服务或其他 endpoint。
5. 在 ZeroBox 中建立独立 `ZeppOs*System`，注册到 `ZeppOsDeviceFactory`。
6. 将接收 payload 分派给对应 System，不把业务解析塞进连接组件。
7. Android/本地 `DeviceManager` 提供调用入口。
8. 桌面 `RemoteDeviceManager`、daemon 命令和 `LocalCommandBus` 同步补齐。
9. UI 统一放在 Zepp OS 专区，并保持项目现有 Material 3 风格。
10. 不修改现有 BLE 扫描、GATT 建链、UUID 查找、authkey、分包、Transport 或连接生命周期。

## 7. 重要结论

- 41 个 Service 是 Gadgetbridge 当前 `ZeppOsSupport` 的 41 个实际服务实例，不代表每台设备都支持 41 个 endpoint。
- endpoint `0x0000` 返回的服务表才是目标设备能力和加密要求的最终依据。
- 同名功能可能依赖多个服务。例如地图、音乐、日志和语音备忘录通常不只是发送一个业务 endpoint，还会依赖文件传输或网络代理。
- ZeroBox 当前已经具备稳定的服务查询、认证、加密 endpoint 收发基础。后续应在这套基础上逐项增加独立上层 System，不应重新设计连接层。
- 最适合作为下一项工作的，是补全 Find Device，或新增边界清晰的 Device Info、World Clocks、Silent Mode、Alarms 等功能。
