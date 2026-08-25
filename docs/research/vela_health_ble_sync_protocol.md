# Vela AP 健康蓝牙同步协议逆向记录

状态：进行中（第一轮 AP 侧证据已落盘）
更新时间：2026-08-25
范围：Vela 手表 AP 固件、小米运动健康相关的蓝牙同步控制面和健康数据入口。

本文只记录 AP 侧“应用数据如何被组织、排队并交给蓝牙服务”的证据。传感器镜像、底层采样驱动和算法实现不属于本次目标，也不作为 OronBox 健康同步协议的依据。

## 证据等级

- **已证实**：IDA 反编译代码、字符串、常量和现有 OronBox 实现能够互相对应。
- **强证据**：固件中有明确的文件、回调或 worker 名称，但还没有对应的空口抓包。
- **待验证**：可以作为研究假设，不能直接写入 protobuf、解析器或设备兼容性判断。

## 逆向成果保存位置

三个 AP 固件的 IDA 输入文件和数据库均已放在固件目录旁的持久目录，不再依赖临时目录：

| 机型 | 固件 | 持久化 IDA 目录 | 当前数据库名 |
| --- | --- | --- | --- |
| p62lte | Xiaomi Watch S5 eSIM | `/Users/orpudding/Documents/MiWearFirmware/ida-analysis/p62lte/` | `p62_ida` |
| p65 | Redmi Watch 6 | `/Users/orpudding/Documents/MiWearFirmware/ida-analysis/p65/` | `0b0f5614` |
| p67cn | Xiaomi Band 10 Pro | `/Users/orpudding/Documents/MiWearFirmware/ida-analysis/p67cn/` | `p67cn_ida` |

每个目录至少包含 `vela_ap.bin` 和 `vela_ap.bin.i64`。IDA MCP 当前使用这些持久数据库；数据库中保留了初始导入时的旧临时输入路径元数据，但当前会话打开的是上述持久路径，不需要重新分析。

辅助材料：

- `/Users/orpudding/Documents/MiWearFirmware/best1503_vela.py`
- p62 AP：`/Users/orpudding/Documents/MiWearFirmware/miwear.watch.p62lte_v3.112.035_full_adbe74f0.analysis/vela_ap.bin`
- p65 AP：`/Users/orpudding/Documents/MiWearFirmware/miwear.watch.p65_v3.100.031_full_29136140.analysis/vela_ap.bin`
- p67 AP：`/Users/orpudding/Documents/MiWearFirmware/miwear.watch.p67cn_v3.101.043_full_a4ce8564.analysis/vela_ap.bin`

本文件是当前逆向成果的第一份持久记录。由于文件格式和空口字段尚未全部证实，暂不把下面的推断硬编码进生产协议代码。

## OronBox 当前已知同步链

现有实现和 protobuf 已经给出了应用侧的基线：

1. `/Users/orpudding/Documents/GitHub/OronBox/protos/xiaomi/wear.proto` 中，`WearPacket.Type.FITNESS = 8`，Fitness payload 是字段 10。
2. `/Users/orpudding/Documents/GitHub/OronBox/protos/xiaomi/wear_fitness.proto` 中，健康历史同步入口目前使用：
   - `GET_TODAY_FITNESS_IDS = 1`
   - `GET_HISTORY = 2`
   - `REQUEST_FITNESS_IDS = 3`
   - `REQUEST_FITNESS_ID = 4`
   - `CONFIRM_FITNESS_ID = 5`
3. `/Users/orpudding/Documents/GitHub/OronBox/lib/src/device/xiaomi/components/health_system.dart` 目前按 7 字节 FitnessDataId 请求历史文件；文件通过 SPP activity 通道或 L2 `fileFitness` 通道传输。
4. `/Users/orpudding/Documents/GitHub/OronBox/lib/src/protocols/xiaomi/packet/l2_packet.dart` 中，`fileFitness` 是 L2 channel 5。
5. 现有 activity 文件重组逻辑使用 4 字节 little-endian 分片头、末尾 CRC32，并把重组后的内容交给健康文件解析器。这些行为已有仓库测试覆盖，但本轮 AP 反编译尚未证明它们就是 CaptureService 的内部 BTMsg 外层格式；两者必须分开记录。

## p67 AP：健康配置 protobuf 入口

下面的函数均来自持久数据库 `p67cn_ida`。函数名是 IDA 自动命名，地址是固件虚拟地址。

| 功能 | 入口/函数 | 已确认行为 |
| --- | --- | --- |
| 心率配置分发 | `sub_C65EF80 @ 0xc65ef80` | 检查 WearPacket type 8；Fitness id 10 进入 GET，id 11 进入 SET。 |
| 心率 GET | `sub_C65EAC4 @ 0xc65eac4` | 构造返回头 `08 0a 0a 00`，从 AP 内部心率配置生成 HeartRateMonitor。 |
| 心率 SET | `sub_C65ED3C @ 0xc65ed3c` | 构造返回头 `08 0b 0a 00`，把收到的配置写回 AP 内部状态并触发更新。 |
| 血氧配置分发 | `sub_C6486D4 @ 0xc6486d4` | Fitness id 8/9 分别进入血氧 GET/SET。 |
| 血氧 GET/SET | `sub_C648520 @ 0xc648520`、`sub_C6485B0 @ 0xc6485b0` | 返回头分别为 `08 08 0a 00`、`08 09 0a 00`；SET 路径包含警告阈值 80/85/90。 |
| 压力配置分发 | `sub_C62D4A8 @ 0xc62d4a8` | Fitness id 14/15 分别进入压力 GET/SET。 |
| 压力 GET/SET | `sub_C62CFD8 @ 0xc62cfd8`、`sub_C62D3FC @ 0xc62d3fc` | 返回头分别对应 `08 0e 0a 00`、`08 0f 0a 00`；前者序列化压力监测配置。 |
| 睡眠设置/研究分发 | `sub_C63AE1C @ 0xc63ae1c` | 处理睡眠规律、睡眠障碍、睡眠研究以及 HRV 列表分支。 |

上表的十六进制头是固件中的 little-endian 32 位常量，按字节展开后可直接看到 `WearPacket type=8`、Fitness id 和 protobuf payload 标志。它们是配置控制包的证据，不是历史健康文件内容。

## p62/p65 AP：配置控制面横向闭合

这一轮通过 IDA Pro MCP 对持久化数据库做了函数级交叉引用，确认 p62 和 p65 使用同一组 Fitness ID。下面的函数是配置控制面，不是历史健康数据文件的同步函数；静息心率、异常心率、异常血氧和睡眠明细仍需从历史文件/同步回调中继续闭合。

### p62lte

| 功能 | 分发/处理函数 | 证据 |
| --- | --- | --- |
| 心率 | `sub_109A0DBC @ 0x109a0dbc`；GET `sub_1099E200 @ 0x1099e200`；SET `sub_10CA343C @ 0x10ca343c` | 分发检查 WearPacket type 8 后按 ID 10/11 调用；GET/SET 头分别是 `08 0a 0a 00`、`08 0b 0a 00`。频率映射为 0/1/10/30 分钟，高阈值为 100–150，低阈值为 40/45/50。 |
| 血氧 | `sub_109908C8 @ 0x109908c8`；GET `sub_10990858 @ 0x10990858`；SET `sub_10C9F608 @ 0x10c9f608` | 分发按 ID 8/9 调用；GET/SET 头是 `08 08 0a 00`、`08 09 0a 00`；SET 接受 80/85/90 阈值。 |
| 压力 | `sub_109814B0 @ 0x109814b0`；GET `sub_1097F854 @ 0x1097f854`；SET `sub_10981418 @ 0x10981418` | 分发按 ID 14/15 调用；GET/SET 头是 `08 0e 0a 00`、`08 0f 0a 00`。 |

### p65

| 功能 | 分发/处理函数 | 证据 |
| --- | --- | --- |
| 心率 | GET `sub_C79E0D0 @ 0xc79e0d0`；SET `sub_C79E358 @ 0xc79e358`；注册 `sub_C79E1D8 @ 0xc79e1d8` | GET/SET 头是 `08 0a 0a 00`、`08 0b 0a 00`；注册路径使用 ID 10/11；频率和高/低阈值映射与 p62 一致。 |
| 血氧 | 分发 `sub_C7BE93C @ 0xc7be93c`；GET `sub_C7BE778 @ 0xc7be778`；SET `sub_C7BE808 @ 0xc7be808`；注册 `sub_C7BE9C4 @ 0xc7be9c4` | 分发/注册明确使用 ID 8/9；GET/SET 头是 `08 08 0a 00`、`08 09 0a 00`；SET 阈值为 80/85/90。 |
| 压力 | GET `sub_C7C5414 @ 0xc7c5414`；SET `sub_C7C5818 @ 0xc7c5818` | GET/SET 头是 `08 0e 0a 00`、`08 0f 0a 00`；SET 会更新 AP 内部压力配置状态。压力的独立分发函数尚未单独命名。 |

这组 p62/p65 函数与 p67 的函数族形成了稳定的配置控制面证据：`WearPacket type=8`、Fitness ID 8/9/10/11/14/15 和 protobuf payload 头在不同机型上保持一致。但它们只能说明“如何开关和设置监测”，不能推出历史健康记录的文件 ID、字段布局或 L2 分片格式。

### 心率字段映射

`sub_C65EC24 @ 0xc65ec24` 把收到的 HeartRateMonitor 解码对象映射到 AP userinfo：

| AP 解码对象位置 | 固件行为 | 当前解释 |
| --- | --- | --- |
| `v2[0]` | 只有值为 1 时读取 `v2[1]`；否则内部频率为 -1 | 监测开关/频率存在性 |
| `v2[1]` | 1→0，2→1，3→10，4→30 | 监测频率，单位看起来是分钟 |
| `v2[5]` | `v2[5] == 1` 写入 `hr_health_mode` | 健康模式开关 |
| `v2[6]`、`v2[7]` | `v2[6] == 1` 时，1→100、2→110、3→120、4→130、5→140、6→150 | 高心率警告开关/阈值 |
| `v2[8]`、`v2[9]` | `v2[8] == 1` 时，1→40、2→45、3→50 | 低心率警告开关/阈值 |

`sub_C63B61C @ 0xc63b61c` 和 `sub_C63B5DC @ 0xc63b5dc` 分别读写全局配置字节，并使用解码对象的偏移 6/7、26/27。这里的对象偏移是 nanopb/C 结构布局，不等于 protobuf wire field number；因此现阶段只把上表记为“固件对象字段映射”，不修改 `/Users/orpudding/Documents/GitHub/OronBox/protos/xiaomi/wear_fitness.proto`。

仓库中的 HeartRateMonitor 定义位于该 proto 的 message 区域，包含 `mode`、`frequency`、`warning`、`warning_value`、`warning_low`、`abnormal_cardiac`、`warning_sport` 等字段。下一步要把固件对象偏移和这些 field number 通过 nanopb descriptor 或实际包逐字段闭合。

### p62/p65 横向符号证据

- p62 和 p65 都能找到 `subscribe_all_heartrate_protobuf`、`subscribe_all_oxygen_protobuf`、`subscribe_all_pressure_protobuf`、`subscribe_all_sleep_protobuf`，说明四类健康配置/状态在两个 AP 版本中都存在应用侧 protobuf 订阅入口。
- p62 的 `Fitness_FitnessID_*` 日志包含心率监测、血氧监测、压力监测、睡眠规律/障碍等 GET/SET 路径；p65 也包含对应心率、血氧、压力和睡眠 GET/SET 日志。它们是 AP 内部应用协议证据，不等于历史数据文件的 BLE 分片格式。
- p62 的 HRV 专用检索命中 61 个字符串/符号，包括 `tv_longsleep_hrv_update`、`tv_longsleep_hrv_create`、`sleep_mode_avg_hrv`、`persist.hrv_basemin`、`persist.hrv_days` 和 `algohrv`；这是 p62 支持睡眠 HRV 的强证据。
- p65 的同样 HRV 专用检索为 0，同时仍有普通睡眠历史/阶段处理符号；这与 p65 不支持睡眠 HRV 的产品能力一致，但“没有命中 HRV 符号”本身不作为 BLE 字段缺失的最终证明。

目前 p62/p65 的字符串表与代码引用在这批固件中没有直接闭合到健康历史文件传输函数，不能用这些符号地址替代空口抓包。后续仍以共同的 FitnessDataId 请求、文件类型和 L2 分片证据为准。

### p62 睡眠/研究分发函数

`sub_10981ACC @ 0x10981acc` 是 p62 的另一个 `WearPacket type=8` 分发函数。它按收到的 Fitness id 处理睡眠设置、睡眠研究和一个扩展列表分支：

- id 61、62、63 分别构造 `08 3d 0a 00`、`08 3e 0a 00`、`08 3f 0a 00` 响应头，对应睡眠配置/状态的三条控制路径。
- id 69 构造 `08 45 0a 00`，读取 payload 中的条目数量，并按 8 字节记录复制睡眠相关列表。
- id 76、77、78 进入睡眠研究相关的请求/列表路径；这些分支的具体 field 仍需结合 descriptor 或抓包确认。
- id 99 构造 `08 63 0a 00`，读取一个 32 位值、条目数量和若干 8 字节记录。它是当前 `wear_fitness.proto` 未声明的扩展消息，但现阶段没有足够证据把它命名为 HRV。
- p62 中没有搜索到 p67 那种 `08 71 0a 00`（id 113）响应头。因此 p62 的 HRV 专用字符串和 UI/应用符号只能证明 AP 能力，不能直接证明它复用 p67 的 HRV 空口编号。

这条函数把 p62 的睡眠控制面进一步闭合了，但仍没有完成“睡眠阶段/睡眠 HRV 历史文件 → FitnessDataId → L2 分片”的映射。id 99 暂存为待验证扩展，不写入生产 enum。

## p67 AP：睡眠 HRV 证据

目前能确认三层信息，但不能把它们误写成同一个 ID：

1. `sub_C63AE1C @ 0xc63ae1c` 的 WearPacket 分支中，数字 id `113`（反编译显示为字符 `q`）读取 payload 偏移 `+16` 的 `uint16`，并打印 `sync_sleep_hrv_cb` 的 `hrv list cnt`。这证明 p67 AP 有一个健康消息分支接收 HRV 列表数量。
2. p67 AP 字符串包含 `sync_sleep_hrv_cb`、`/data/fitness/sleep/hrv/`、`/data/fitness/sleep/hrv/%s` 以及 HRV UI 资源名。这证明 HRV 有独立的同步回调和持久化目录。
3. `CaptureWorkerFactory::get_worker` 的代码（IDA 反编译位置 `0xc4af5c4` 附近）包含 `case 140: algo_sleep_hrv`。这里的 140 是 CaptureService worker/sensor 类型，不是上面 WearPacket 的 113，也不是已证实的 BLE FitnessDataId。

因此当前结论是：p67 支持睡眠 HRV，AP 内部同时存在“健康 protobuf 分支 id 113”和“Capture worker 类型 140”两个不同编号；它们与公开 BLE 历史文件请求之间的映射尚未证实。p65 没有睡眠 HRV 的等价证据，和产品已知“不支持睡眠 HRV”的行为一致；但仅凭字符串缺失不能作为最终证明。

## p67 AP：历史 Fitness ID 的蓝牙入口

这一轮已经把历史 Fitness ID 的入口从蓝牙接收层追到 AP 内部服务队列：

- `sub_C700D14 @ 0xc700d14` 是 p67 的通用蓝牙 protobuf 分发函数。收到 `WearPacket type=8` 时，id 1 记录 `recv get today fitness ids`，id 2 记录 `recv get history fitness ids`；id 71–75 另作 research message 记录。
- `sub_C712B54 @ 0xc712b54` 查询静态路由表 `dword_2CD4BA94`。type 8 的子表位于 `0x200e0068`，其中 id 1、2、3、4、5 的路由标志均为 2。这个结果和仓库 `wear_fitness.proto` 中的五个 FitnessDataId 请求/确认枚举在数值上对齐。
- 路由标志 2 由 `sub_C700D14` 交给 `sub_C7089BC @ 0xc7089bc`，再调用 `sub_CABDA30 @ 0xcabda30` 的 mode 1 路径。
- `sub_CABDA30` 根据服务名表把 mode 1 写到 `s2c_queue_algo`；底层 `sub_CABDE5C @ 0xcabde5c` 打开消息队列、分配消息对象并写入 type/长度/参数后发送。这里已经是 AP 内部“蓝牙入口 → algo 服务”链路，不是传感器镜像或算法采样驱动。

当前能确认的边界是：p67 确实接收今日/历史 Fitness ID 请求，且 1–5 走统一的 algo 服务队列；当前还不能从这条通用队列包装器直接推出 7 字节 FitnessDataId 的具体字段、历史文件响应内容或 L2 channel 5 分片头。下一步要继续跟进 algo 服务对 `s2c_queue_algo` 消息的消费函数，以及它如何生成文件列表/文件确认响应。

## CaptureService：文件同步控制面

这是目前最接近“蓝牙同步数据”而非传感器算法的一组 AP 证据。

### 文件队列

- `sub_C4ACB0C @ 0xc4acb0c` 是 `capture_sync` 入口。它检查 CaptureService 状态，把状态置为同步中，并调用目录遍历函数 `sub_C42F73C` 扫描 `/data/fitness/capture`。
- 同步请求队列元素在反编译中按 44 字节对象处理，队列计数位于 AP 对象偏移 `+352`；没有文件时记录 `SyncReq list empty` 并恢复状态。
- `sub_C42F73C @ 0xc42f73c` 是递归目录遍历器。
- `sub_C4AD0F4 @ 0xc4ad0f4` 解析 capture 文件路径中的日期、模式和传感器，识别 `Online`、`Offline`、`Realtime`，并生成一个 7/9 字节的 AP 内部 capture 描述对象。
- `sub_C4AD048 @ 0xc4ad048` 按模式寻找对应的确认文件：mode 2 使用 `Compress.bin`，mode 1 使用带序号的文件名，mode 0 使用 `.json`。

这些 7/9 字节对象属于 CaptureService 内部路径解析结果，不能直接当作 OronBox 现有 7 字节 FitnessDataId。两者需要同一份空口抓包或 BT service 交叉引用才能合并。

### BTMsg 发送路径

- `sub_C4AE284 @ 0xc4ae284` 负责发送文件：检查文件非空、分析路径、设置内部模式位，并调用 `sub_CABDF38(4, 6, ..., 8, ..., 256)` 编码 BTMsg。
- `sub_CABDF38 @ 0xcabdf38` 是 nanopb 编码包装器，输出对象先写入类型/子类型，再写入 8 字节描述并调用 `pb_encode`。
- `sub_C4AE058 @ 0xc4ae058` 是 `send_file_as_btmsg`，负责忙时排队、发送确认等待和 watchdog。
- `sub_C4AE368 @ 0xc4ae368` 是确认处理：校验 ack 文件、失败时重传、成功时删除 ack 文件，并在队列空时记录 `sync file done!`。
- `sub_C4AB944 @ 0xc4ab944` 把 capture 事件分发给 worker；`CaptureSendEvent::run` 最终通过 `sub_C4AB338`/`sub_CABDC5C` 写入 `c2s_queue_<name>` 消息队列，交给 AP 内部蓝牙服务。

这条链证明了 AP 的文件同步控制面：

```text
/data/fitness/capture
        ↓
CaptureService SyncReq / file queue
        ↓
共享 btmsg protobuf（内部 type/subtype）
        ↓
c2s_queue_<name>
        ↓
AP 内部 BT service
```

`dword_2CDC3E04 @ 0x2cdc3e04` 实际上是多个 btmsg 路径共用的 protobuf descriptor：CaptureService 文件发送、设备端文件列表、上传进度和通用 btmsg 接收都引用它。因此它不能命名为 Capture 专属 descriptor，也不能直接当作公开健康同步协议。

### 共享 btmsg 与通用文件上传

- `sub_C70821C @ 0xc70821c` 是 p67 的通用 BTMsg 入口。外层类别字节 10/11 分别进入不同的 MIWEAR protobuf 处理路径；类别 11 解码同一 descriptor 后，以解码对象首字节作为 message id，当前可见分支覆盖 1–25。
- message id 23 和 4 会进入 `sub_C704BC4 @ 0xc704bc4`，即 `upload_file_list_decode`。它读取重复文件项、路径、文件类型和文件大小，然后把文件交给 `miwear_file_enqueue_by_hdl_v1`（`sub_C7D2DDC @ 0xc7d2ddc`）。
- `sub_C7D2358 @ 0xc7d2358` 启动通用上传；不同文件类型选择 4090 或 4092 字节的内部分块上限，并继续交给 `miwear_transport_send`（`sub_C7D719C @ 0xc7d719c`）。这仍是 AP 内部传输层证据，不是 L2 channel 5 的公开分片头。
- `sub_C70472C @ 0xc70472c` 生成上传进度 btmsg，内部 type/subtype 为 22/24，再由 `sub_C708A1C` 发送。它进一步证明 descriptor 是共享的，但目前没有把通用文件类型 2–11 中的任何一个证实为 FitnessDataId 或健康历史文件类型。
- `sub_C7CEB1C @ 0xc7ceb1c`、`sub_CAB4928 @ 0xcab4928` 和 `sub_C4B070C @ 0xc4b070c` 也引用该 descriptor，说明 CaptureService 的 `sub_CABDF38` 只是共享编码包装器的一条调用路径。

因此目前能闭合的是“AP 文件队列 → 内部 btmsg → AP 蓝牙服务/通用文件上传”的控制面；仍不能把它等同于 OronBox 现有 L2 channel 5 上的 4 字节分片头。两种格式在代码中必须保持独立，直到有实际空口抓包或完整服务端交叉引用。

## 健康数据文件线索

p67 AP 的字符串和路径给出了以下同步对象线索：

- 血氧：`/data/fitness/view/bo/detail.tmp`、`/data/fitness/view/bo/abnormal.tmp`
- 睡眠阶段：`/data/fitness/view/sleep/%lu_stage_for_ui`
- 睡眠心率/血氧：`/data/fitness/cache/sleep/%lu_hr`、`/data/fitness/cache/sleep/%lu_bo`
- 睡眠 HRV：`/data/fitness/sleep/hrv/`、`/data/fitness/sleep/hrv/%s`
- 压力：`/data/fitness/view/stress/detail.tmp`、`30day.tmp`、`dist.tmp`
- 睡眠缓存/异常：`/data/fitness/cache/sleep/`、`/data/fitness/cache/abnormal`

这些是 AP 文件命名和消费路径，不等于文件内部 schema。当前 OronBox 已有的心率、静息心率、异常心率、血氧、压力、睡眠时长/阶段和 HRV 解析逻辑仍应以真实文件 fixture 测试；在拿到对应 p62/p65/p67 文件或抓包之前，不应根据路径名新增字节偏移。

### Mi Fitness 当前 Vela 异常心率文件格式

这部分后来在 Mi Fitness 3.57.0i 的现行 `FitnessDataId` 解析链中闭合了，不是旧 GDSP 的 15-byte 通知格式：

- `FitnessDataId.genDataTypeByte()` 将 daily file 的类型编码为 `type=0`、`dailyType=(flags & 0x7f) >> 2`、`fileType=flags & 3`；`SchemaDebugResolver` 和 `FitnessDataParser` 都把 `dailyType=9` 命名/分派为 `abnormal` / `AbnormalRecordParser`。
- `FitnessDataValidity` 对该类型的 v1/v2 有效位长度为 0，因此异常文件的二进制 body 紧跟在 7-byte `FitnessDataId` 后面。
- `AbnormalRecordParser` 的每个段头是 13 bytes：`startTime:u32le`、`endTime:u32le`、`abnormalType:u8`、`abnormalSetValue:u16le`、`recordCount:u16le`；随后每条记录是 5 bytes：`time:u32le` + `value:u8`。
- Mi Fitness 的 `AbnormalType` 定义中，`1=HR_HIGH`、`2=HR_LOW`、`3=SPO2_LOW`、`4=STRESS_HIGH`、`5=ABNORMAL_FIB`。其中 1–4 是带采样值/阈值的异常段，5 是官方另存为 `abnormal_heart_beat` 的心脏健康不规则心跳事件，使用段起止时间。

OronBox 已在 `health_system.dart` 接入 `dailyType=9` 的 v1/v2 解析，保留每条异常采样的时间/值、段阈值和段起止时间，并将 `ABNORMAL_FIB` 保留为独立的心脏健康事件；健康同步服务统一持久化到 `abnormalHealthRecords`。这条路径与实时 `warningStatus` 分开：前者是手表历史异常记录，后者是实时状态码。

## Mi Fitness 手机接收面：睡眠数据实际结构

为了直接回答“MiWear 发给手机的睡眠数据长什么样”，本轮转向逆向 Mi Fitness 3.57.0i 的手机端接收代码和 native 睡眠库。目标是确认设备发来的历史健康文件经过手机接收层后，如何进入睡眠阶段对象；不是复刻 MiWear 的算法，也不是分析手表传感器驱动。

### 持久化逆向材料

所有材料均保存在固件目录旁的持久目录：

- XAPK：`/Users/orpudding/Documents/MiWearFirmware/mi-fitness-analysis/mi-fitness-3.57.0i.xapk`
- JADX 输出：`/Users/orpudding/Documents/MiWearFirmware/mi-fitness-analysis/jadx-3.57.0i/`
- arm64 native 库：`/Users/orpudding/Documents/MiWearFirmware/mi-fitness-analysis/native/lib/arm64-v8a/`
- IDA 数据库：`libstage-lib.so.i64`、`libjni_xiaomi_sleep_algorithm.so.i64`，均在上述 native 目录内。

关键 Java 证据文件：

- [`FitnessWearPbImpl.java`](/Users/orpudding/Documents/MiWearFirmware/mi-fitness-analysis/jadx-3.57.0i/sources/com/xiaomi/fit/fitness/device/mi/send/FitnessWearPbImpl.java)：Fitness ID 请求和确认。
- [`FitnessDataReceiver.java`](/Users/orpudding/Documents/MiWearFirmware/mi-fitness-analysis/jadx-3.57.0i/sources/com/xiaomi/fit/fitness/device/mi/receive/FitnessDataReceiver.java)：分片重组、CRC32 和 7 字节数据 ID。
- [`FitnessReceiverHandler.java`](/Users/orpudding/Documents/MiWearFirmware/mi-fitness-analysis/jadx-3.57.0i/sources/com/xiaomi/fit/fitness/device/mi/receive/FitnessReceiverHandler.java)：设备数据接收回调。
- [`AllDaySleepParser.java`](/Users/orpudding/Documents/MiWearFirmware/mi-fitness-analysis/jadx-3.57.0i/sources/com/xiaomi/fit/fitness/parser/daily/AllDaySleepParser.java)：日睡眠固定字段和辅助记录。
- [`FitnessDataParser.java`](/Users/orpudding/Documents/MiWearFirmware/mi-fitness-analysis/jadx-3.57.0i/sources/com/xiaomi/fit/fitness/parser/FitnessDataParser.java)：把固定睡眠数据后的剩余内容交给 native 睡眠库。
- [`MiDevSleepAlgo.java`](/Users/orpudding/Documents/MiWearFirmware/mi-fitness-analysis/jadx-3.57.0i/sources/com/xiaomi/fit/fitness/sleep/algo/MiDevSleepAlgo.java)：native 睡眠阶段输入入口。

### 1. 手机接收链：控制面和数据面

Mi Fitness 的控制面在 `FitnessWearPbImpl` 中使用 `WearPacket` 的 Fitness 类型（`c=8`）：

| 操作 | Fitness 子操作 | 行为 |
| --- | ---: | --- |
| 今日数据 ID | 1 | 请求今日 Fitness ID |
| 历史数据 ID | 2 | 请求历史 Fitness ID |
| 请求数据 | 3/4 | 按 7 字节数据 ID 请求文件/数据 |
| 确认数据 | 5 | 确认已收到的数据 ID |

数据面随后进入 `FitnessReceiverHandler` 的设备数据回调，当前 Java 接收器处理的回调类型是 `102`。L2 定义中的 `FILE_FITNESS` 是 channel `5`；这两个数字来自不同层，不能直接写成“102 等于 channel 5”。

`FitnessDataReceiver` 已把文件传输格式闭合到以下程度：

1. 每个分片前 4 字节是两个 little-endian `uint16`：总分片数、当前序号；有效负载从偏移 4 开始。
2. 按序拼接分片后，末尾 4 字节是 CRC32；Mi Fitness 会对去掉 CRC 的完整内容做严格校验。
3. CRC 后的内容开头 7 字节是 `FitnessDataId`。每日数据 ID 的服务端形式是 6 字节，运动数据 ID 的服务端形式是 7 字节。
4. 对日睡眠数据，`dailyType=8` 进入 `AllDaySleepParser`。数据头是服务端 ID、保留字节和 validity bitmap；固定主体与 validity bitmap 对应，剩余字节才是睡眠源数据尾部。

这条链说明了“蓝牙同步文件”与“睡眠算法输入”的边界：同步分片/CRC/数据 ID 属于数据传输层，睡眠固定主体和尾部阶段包属于文件内容层。

### 2. 日睡眠固定主体和尾部

`AllDaySleepParser` 对 `dailyType=8` 的固定字段顺序为：

| 类型 | 字段/记录 | 大小或格式 |
| --- | --- | --- |
| 固定字段 | 是否完成、入睡时间、醒来时间 | 1、4、4 字节 |
| 固定字段 | 睡眠质量、睡眠效率 | 1、1 字节 |
| 固定字段 | 入睡/清醒时长、卧床时长、上床/离床时间 | 多个 4 字节字段 |
| 辅助记录 | 睡眠心率、睡眠血氧、鼾声 | 记录数和采样值；心率/血氧 1 字节，鼾声为 4 字节 float |
| 特征入口 | HRV | v5 schema 没有 HRV；v6 schema 明确定义 11 个 HRV 汇总字段和 `uint16` HRV 打点序列 |

心率、血氧和鼾声辅助记录由 Java 解析；固定主体及辅助记录之后的全部剩余字节被复制到 `sleepSrcBytes`。`MiDevSleepAlgo` 将这段 `sleepSrcBytes` 原样传给 `setSourceSleepData(byte[])`，因此这正是设备发给手机、供 native 睡眠阶段处理的原始尾部，而不是手机重新采集的传感器镜像。需要区分两条路径：v6 的 HRV 汇总和 HRV 打点在 schema body 中位于 `featureData` 之前，属于可直接解析的结构化字段；`featureData` 仍是 native 阶段算法的透明尾部。

### 2.1 v5/v6 schema：HRV 的精确位置

Mi Fitness APK 内置的 [`schemas.zip`](/Users/orpudding/Documents/MiWearFirmware/mi-fitness-analysis/jadx-3.57.0i/resources/assets/schemas.zip) 提供了 `full_day_sleep_report_v5.json` 和 `full_day_sleep_report_v6.json`。这组 schema 把此前“HRV 可能在 opaque tail 中”的判断纠正为以下事实：

- v5 body 在固定字段后直接进入心率、血氧、鼾声和 `featureData`，没有 HRV 汇总字段，也没有 HRV 打点数组。
- v6 body 在固定字段后追加 24 字节 HRV 汇总区：6 个 little-endian `uint16`（平均值、标准差、中位数、下/上/中分位数）、1 个 little-endian `uint32` 时间戳、4 个 little-endian `uint16`（最大值、最小值、基线最大值、基线最小值）。
- v6 随后按心率、血氧、HRV、鼾声的顺序读取辅助记录。HRV 记录头为 `interval:uint16 LE`、`count:uint16 LE`，count 大于 0 时追加 `firstTime:uint32 LE`，然后是 count 个 `uint16 LE` 值；`featureData` 从这些记录之后开始。
- v6 validity bitmap 为 3 字节、MSB-first：固定字段占 bit 23..16，HRV 汇总占 bit 15..5，心率/血氧/HRV 打点/鼾声分别占 bit 4/3/2/1，bit 0 保留。
- Mi Fitness 的 `SleepHrvPanelHolder` 使用 `common_unit_hrv_ms_desc` 展示 HRV，因此当前 UI 的 `ms` 单位也有官方显示层依据，不是仅按常见医学单位猜测。

对应的官方解析实现是 [`AllDaySleepSchemaParser.java`](/Users/orpudding/Documents/MiWearFirmware/mi-fitness-analysis/jadx-3.57.0i/sources/com/xiaomi/fit/fitness/parser/schema/daily/AllDaySleepSchemaParser.java)，当前 OronBox 已按这个顺序读取 v6 HRV，并用 `firstTime + index * interval` 还原 HRV 点时间。p65 不支持睡眠 HRV 时，HRV validity 位应为无效或没有对应记录，产品层保持不显示。

### 3. native 睡眠尾部包头

在 IDA 中打开持久化的 `libstage-lib.so` 后，`check_device_stage`、`confirm_data_version` 和包头解析函数共同确认当前尾部包布局：

```text
00..03  fb fa fc ff       magic
04      header/consumed    当前样本为 0x11
05..0c  uint64 LE          包时间戳
0d      parity/control     校验/控制字节
0e      uint8              packet type
0f..10  uint16 BE          payload length
11..    bytes              payload
```

这里 `0x0e` 是包类型，不是当前流的版本字段。`confirm_data_version()` 会探测旧/特殊格式的标记；当它在当前 `type=16/17` 包上没有得到 100 或 101 时，`sleep_stage_algo_set_binary_data()` 默认走 v101 解析路径。因此不能把当前包的 byte 14 命名为“版本”。

### 4. `type=16`：设备睡眠汇总记录

`libstage-lib.so` 对 `type=16` 的 payload 按 **N 个 13 字节记录**处理，不是固定只有一条：

| 偏移 | 编码 | native/JNI 含义 |
| ---: | --- | --- |
| 0 | 高 4 位 | `sleepIdx` |
| 0 | 低 4 位 | `wakeCount` |
| 1..2 | `uint16 BE` | `sleepDuration`，分钟 |
| 3..4 | `uint16 BE` | `wakeDuration`，分钟 |
| 5..6 | `uint16 BE` | `lightDuration`，分钟 |
| 7..8 | `uint16 BE` | `remDuration`，分钟 |
| 9..10 | `uint16 BE` | `deepDuration`，分钟 |
| 11 | bits 4..5 | `hasRem` 状态；JNI 中值为 1 时为 true |
| 11 | bits 2..3 | `hasStage` 状态；JNI 中值为 1 时为 true |
| 12 | `uint8` | 未命名间隔/保留时长；native 用于下一条汇总的起始时间计算 |

第一条记录的起始时间是包头 `uint64 LE` 时间戳，结束时间为：

```text
start + 60 * (sleepDuration + wakeDuration)
```

下一条记录的起始时间还会加上上一条记录 byte 12 对应的分钟间隔。JNI 最终把这些字段映射为 Java `SleepStageSummary`：`sleepIdx`、入睡/出睡时间、清醒/浅睡/REM/深睡时长、睡眠总时长、醒来次数、REM/阶段标志和呼吸相关状态。

### 5. `type=17`：睡眠阶段明细

`type=17` 的 payload 长度必须按 2 字节切分，每个 2 字节值是一个阶段点：

```text
raw = uint16 BE
state_code = raw >> 12
duration_min = raw & 0x0fff
```

IDA 还原出的 native 状态映射为：

| raw `state_code` | native state |
---:|---:|
| 0 | 5 |
| 1 | 3 |
| 2 | 2 |
| 3 | 4 |
| 4 | 0 |
| 其它 | 1 |

第一阶段起始时间是包头时间戳，后续阶段从前一阶段的结束时间继续；每个阶段结束时间为起始时间加 `duration_min * 60`。`libjni_xiaomi_sleep_algorithm.so` 会把 native 结果转换成 Java `SleepStage[]`，每个元素只有 `state`、`startTime`、`endTime` 三个核心字段。

这已经是“设备 → Mi Fitness 手机”的睡眠阶段数据结构：设备阶段记录在 `featureData/sleepSrcBytes` 尾部，手机 native 只负责消费和转换，Java 层接收的是 `SleepStageSummary` 加 `SleepStage[]`。它不是 protobuf payload，也不是传感器驱动采样包。

### 6. Mi Fitness 官方显示层交叉验证

这条语义已经在 Mi Fitness 自己的显示代码中闭合，而不是仅根据 native 状态名称推断：

- `SleepSegmentUtils.convertToSegmentReport()` 将 `SleepStage.state` 原值写入 `SleepStateItem`，没有在 Java 接收层重新编号。
- `SleepStageStyle` 的默认 `stageOrder` 是 `[2, 3, 4, 5]`。
- `SleepStageStyle.colorOf()` 明确使用 `2=deep`、`3=light`、`4=REM`、`5=awake`；默认颜色也与官方图表的四条阶段轨道对应。
- 官方默认颜色为深睡 `#2231B6`、浅睡 `#3986F6`、REM `#47BEFF`、清醒 `#FF763B`。颜色不是协议必要部分，但可以作为 UI 对齐参考。

因此 OronBox 可以直接使用以下标准阶段枚举：

```text
2 → 深睡
3 → 浅睡
4 → REM
5 → 清醒
```

native 还可能产生 `0`、`1` 或其它状态。官方图表的标准四阶段轨道不包含它们；在没有真实 p62lte/p65/p67cn 尾部样本确认前，应保留为未知/非标准状态，不要擅自并入深睡、浅睡或清醒。

### 7. 对 OronBox 的直接结论

- 现有 `health_system.dart` 对 `fb fa fc ff`、`uint64 LE` 时间戳、`type` 偏移 14、`uint16 BE` 长度和 `type=17` 的 2 字节阶段点解析方向是对的；之前测试中的包头顺序与 native `sub_12800` 一致。
- 现有解析器已经按 native 行为支持同一 `type=16` payload 内的 N 条 13 字节汇总记录，并用 byte 12 的 gap 计算后续记录起始时间；v5/v6 fixture 已覆盖这一点。
- `_sleepStageDetailValue` 现在保留 native 的完整映射：raw `0..3 → 5/3/2/4`、raw `4 → 0`、其它值 → `1`。标准 UI 只显示 2/3/4/5，0/1 保留为非标准算法状态并过滤掉。
- `type=16/17` 是本轮最重要的手机同步数据证据；`type=150` 等其它尾部包可能属于算法传感器输入，不能把所有尾部包都当成睡眠阶段记录。
- p62lte、p67cn 的睡眠 HRV 产品能力与 v6 schema 结构已经足以支撑实现汇总和打点显示；仍需要三个目标机型的真实文件/抓包做兼容性覆盖，尤其确认设备实际使用 v5 还是 v6、HRV 单位和缺失字段组合。p65 的“不支持睡眠 HRV”保持不变。

## Mi Fitness 后台健康同步调度（APK 逆向）

这一节来自本地 Mi Fitness APK 的 JADX 产物，不依赖公开资料。9.23.35 与持久保存的 3.57.0i 反编译产物都存在同一条 `FitnessAutoSyncService` 健康数据调度链；下面的行号以 9.23.35 产物为准。

关键文件：

- [`FitnessAutoSyncService.java`](/Users/orpudding/Documents/MiFitness/小米运动健康_9.23.35_jadx/sources/com/xiaomi/fit/fitness/request/FitnessAutoSyncService.java)
- [`FitnessSyncComponent.java`](/Users/orpudding/Documents/MiFitness/小米运动健康_9.23.35_jadx/sources/com/xiaomi/fit/fitness/di/FitnessSyncComponent.java)
- [`FitnessSyncRemoteImpl.java`](/Users/orpudding/Documents/MiFitness/小米运动健康_9.23.35_jadx/sources/com/xiaomi/fit/fitness/remote/FitnessSyncRemoteImpl.java)
- [`FitnessDataSyncBaseImpl.java`](/Users/orpudding/Documents/MiFitness/小米运动健康_9.23.35_jadx/sources/com/xiaomi/fit/fitness/device/FitnessDataSyncBaseImpl.java)
- [`FitnessWearSender.java`](/Users/orpudding/Documents/MiFitness/小米运动健康_9.23.35_jadx/sources/com/xiaomi/fit/fitness/device/mi/send/FitnessWearSender.java)
- [`FitnessWearPbImpl.java`](/Users/orpudding/Documents/MiFitness/小米运动健康_9.23.35_jadx/sources/com/xiaomi/fit/fitness/device/mi/send/FitnessWearPbImpl.java)

### 调度器不是实际同步频率

`FitnessAutoSyncService` 使用 Android `JobScheduler`，`JOB_ID=1999`，`setPeriodic(900000)`，即 15 分钟的系统唤醒粒度。它在组件初始化阶段先经过 AB/全局配置开关；`FitnessSyncComponent.getAutoSyncTest()` 只有在隐私同意、AB 状态为 1 且 `IS_SUPPORT_AUTO_SYNC` 为真时才调用 `FitnessAutoSyncService.schedule()`。

每次 `onStartJob()` 并不会直接无条件取数据，而是先计算：

```text
elapsed = now - DEVICE_SYNC_TIME
skip = elapsed < AUTO_SYNC_INTERVAL * 1000
```

`AUTO_SYNC_INTERVAL` 的默认值是 3600 秒，`GlobalConfig` 未取得服务端值时也回退到 3600 秒。因此 15 分钟只是检查机会，默认有效设备同步间隔约为 1 小时；JobScheduler 还可能因系统省电策略进一步延后。服务端下发的 `autoSyncInterval` 可以改变这个有效间隔。

`DEVICE_SYNC_TIME` 只在一次设备同步真正完成、且当次任务标记为正在同步时写入当前时间（`FitnessDataSyncBaseImpl` 的完成回调）。所以失败、断开或尚未完成不会被当成一次成功同步来更新时间戳。

### 官方健康同步触发链

```text
组件初始化 / AB 配置
        ↓
JobScheduler 每 15 分钟唤醒
        ↓
DEVICE_SYNC_TIME + AUTO_SYNC_INTERVAL 二次限流
        ↓
当前设备存在？ ── 否 → auto_sync 云端同步
        │
        是
        ↓
autoForceSync(true)
        ↓
syncWithDeviceAuto(did)
        ↓
FitnessDataSyncBaseImpl.syncWithDevice()
        ↓
请求今日/历史 FitnessDataId → 过滤本地已处理项 → 请求文件
```

`FitnessDataSyncBaseImpl.syncWithDevice()` 对同一个设备维护 `hasSyncingTask`；如果已有任务进行中，会记录回调并直接放弃重复启动。同步完成后才清除任务标记，并以 `auto_sync` 原因触发云端增量同步。这是官方的“单飞”行为，不是靠 UI 转圈来防重入。

### 官方请求的是“设备提供的 ID 列表”，不是直接指定时间段

后台自动路径 `FitnessDeviceSyncManager.startSyncWithDevice()` 调用 `FitnessWearSender.requestData()`：

1. `getTodayFitnessIds(did, isBgAutoSync=true)` 发送 Fitness type 8、子操作 1，并在 payload 中把后台原因置为 1。
2. 手表返回今日数据 ID 列表；手机逐个按 7 字节 `FitnessDataId` 判断是否需要同步，并过滤本地数据库中已经完成的项。
3. 有待同步项时发送子操作 3/4 请求这些 ID 对应的数据；今日请求完成后再 `getHistoryFitnessIds()`，发送子操作 2 获取历史列表并同样过滤、请求。
4. 请求完成后由接收回调解析文件、写入同步状态，最后发送确认。

因此，自动同步的主语义是“让手表返回当前可提供的一批 ID，再按本地状态增量拉取”。调用方没有在这条自动入口中传入任意的开始/结束时间；时间范围体现在手表返回的 `FitnessDataId` 时间戳和今日/历史列表里。另有手动的 `syncWithDevice(did, dataIds)` 入口，可以显式传入一组 7 字节 ID，但它仍然不是通用的任意时间查询接口。

### 与 OronBox 当前实现的差距

当前 OronBox 的 `_DevicesPageState` 仍把自动同步绑定到进入设备页/设备页分支，并且 `XiaomiSyncPreferences` 没有持久化最后一次健康同步时间；Android `BackgroundTaskService` 目前只是前台通知服务，没有 `JobScheduler`/`WorkManager` 周期任务。`DeviceManager` 已有 `syncDevice()` 单飞，但健康同步还有独立 future，页面的 `_syncingTime` 会在后台任务真正开始时立即显示。

按官方行为实现时，应该把“调度机会”和“实际执行”拆开：

- Android 后台用系统周期任务提供约 15 分钟的唤醒机会；不要把 15 分钟当作强制拉取间隔。
- 以设备 ID 持久化 `lastSuccessfulHealthSyncAt`，默认按 3600 秒限流，成功完成后再写入；20/30 分钟只能作为明确的用户策略，不能作为官方默认行为。
- 用一个覆盖设备同步、健康同步、固件/表盘/应用传输的全局互斥状态；进行中只置 `pendingAutoSync`，完成后若已过冷却窗口再补跑一次，不重复启动，也不提前显示页面 spinner。
- 触发源改为进程启动、设备连接成功、后台周期唤醒和用户手动同步；进入设备页只读取状态，不承担同步职责。
- 后台执行不弹页面 loading；前台时只更新同步状态 surface，完成/失败再按现有 UI 规则提示。

### 新版 `SyncJobService` 的边界

APK 中还存在 `com.xiaomi.fitness.sync.SyncJobService`，同样使用 900000 ms。它的 `SyncEngine.syncAll()` 主要处理天气、日历、股票、时间、睡眠作息设置和电量等设备侧配置；一次性任务完成后再安排 15 分钟后的 refresh，并在 BLE 连接成功约 10 秒后安排一次。它不是上面健康历史文件 `FitnessAutoSyncService` 的替代品，不能把这两条 15 分钟链混为一谈。

## 公开资料交叉核对

公开资料只能作为背景和交叉检查，不能替代固件或空口证据：

- [Gadgetbridge Xiaomi protobuf watches](https://gadgetbridge.org/basics/topics/xiaomi-protobuf/) 将 Mi Band 10 Pro、Redmi Watch 6 等设备列为 Xiaomi protobuf 设备，并把活动、心率、血氧、压力和睡眠阶段列为已实现或实验性能力；该页面同时列出静息/统计类数据仍有缺口。这是第三方功能矩阵，不是本项目协议字段证明。
- [atc1441 p67 分析 issue](https://github.com/atc1441/MiBand10-BES2700iMP-BEST1503-Hacking/issues/3) 和 [对应仓库](https://github.com/atc1441/MiBand10-BES2700iMP-BEST1503-Hacking) 交叉确认 p67 属于 Vela/NuttX 体系，并使用 Bluetooth Classic SPP/RFCOMM channel 5 的传输背景；这能支持 OronBox 的 channel 5 方向，但不能证明现有 4 字节健康文件分片头就是固件内部 btmsg 格式。

## 三个目标机型矩阵

| 机型 | 产品能力 | 当前 AP/协议状态 |
| --- | --- | --- |
| p62lte / Xiaomi Watch S5 eSIM | 支持睡眠 HRV | 已闭合心率、血氧、压力配置控制面，以及睡眠/研究 id 61/62/63/69 和扩展 id 99 的 AP 分发；Mi Fitness v6 HRV body 已可解析，仍需该机型真实文件覆盖。 |
| p65 / Redmi Watch 6 | 不支持睡眠 HRV | 已闭合心率、血氧配置和压力 GET/SET；普通睡眠处理存在，但 HRV 专用符号未命中，健康历史同步仍需继续核对。 |
| p67cn / Xiaomi Band 10 Pro | 支持睡眠 HRV | 已确认 HRV 健康分支、独立 HRV 目录、同步回调字符串、`algo_sleep_hrv` worker，以及历史 Fitness ID 1–5 从蓝牙入口到 `s2c_queue_algo` 的路由；Mi Fitness v6 HRV body 已可解析，仍需该机型真实文件覆盖。 |

## 下一步和禁止提前编码的部分

1. 继续跟进 `s2c_queue_algo` 的消费函数，并结合共享 btmsg descriptor，确认 Fitness 文件列表、文件请求、确认、ack 和上传进度字段，以及它与公开 BLE/L2 服务的边界。
2. 在 p62lte/p65/p67cn 三个 AP 中继续按函数结构而不是只按字符串做横向 diff，找出健康文件 worker 和回调注册表；目前配置控制面以及 p62 睡眠控制分发已完成一轮横向闭合。
3. 找到一组实际的 FitnessDataId 请求、L2 channel 5 分片、CRC 和确认响应，闭合“7 字节 ID → AP capture 文件 → 4 字节分片文件”的映射。
4. 分别取得睡眠阶段、睡眠 HRV、异常心率和异常血氧文件样本，再为现有解析器补 fixture 和字段注释。
5. 只有在上述证据闭环后，才修改 protobuf enum、设备能力矩阵或生产解析代码；当前本研究轮次只新增本文档，没有把 `113`、`140` 或 Capture BTMsg 字段硬编码进产品。
