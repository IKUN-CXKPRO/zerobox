# appside — Zepp OS AppSide 管理

管理 Zepp OS 设备上的 AppSide 会话。AppSide 是手表上的小程序在手机侧运行的
远程 JS 通道（蓝牙端点 `0x00a0`），通过 `messaging.peerSocket` 与手表实时双向通信。

插件可以通过 AppSide API 安装/更新 app-side.js 脚本、管理运行时状态、
收发消息和读取调试日志。

`appId` 为 32-bit 无符号整数（Zepp OS 小程序的应用 ID）。

## ZML

> 用法参考：[ZML](https://zepp-health.github.io/zml/zh/getting-started)

OronBox 内置了包含完整依赖的 ZML 运行时。插件不需要自行打包
`@zeppos/zml`，可以通过 `attach()` 将 ZML 运行时绑定到指定小程序，并在钩子中使用
与官方 `BaseSideService` 一致的 `this.request()`、`this.call()`、`onRequest` 和
`onCall`。

插件的 `manifest.json` 必须声明 `appside` 权限：

```json
{
  "permissions": ["appside"]
}
```

### attach(options)

创建或取得指定 `appId` 的 ZML 通信上下文。`onInit`、`onRun`、`onDestroy`、
`onRequest` 和 `onCall` 都是可选钩子。钩子中的 `this` 与返回值均为同一个
ZML 上下文。

```js
globalThis.activate = async () => {
  const zml = await OronBox.appside.attach({
    appId: 0x0010ee3b,

    onInit() {
      console.log('ZML App-side 已初始化');
    },

    async onRun() {
      const result = await this.request({
        method: 'device.getData',
        params: { type: 'summary' },
      });
      console.log('手表返回:', JSON.stringify(result));
    },

    onRequest(req, res) {
      if (req.method === 'plugin.getState') {
        res(null, { ready: true });
        return;
      }
      res({
        code: 'METHOD_NOT_FOUND',
        message: `未知方法: ${req.method}`,
      });
    },

    onCall(message) {
      console.log('收到手表通知:', JSON.stringify(message));
    },

    onDestroy() {
      console.log('ZML App-side 已停止');
    },
  });

  const result = await zml.request({
    method: 'device.getInfo',
    params: {},
  });

  await zml.call({
    method: 'plugin.ready',
    params: { success: true },
  });
};
```

### request(message, options?)

向小程序发送需要响应的 ZML 请求，返回一个 Promise。默认超时遵循内置 ZML
运行时的配置。

```js
const result = await zml.request({
  method: 'weather.get',
  params: { city: 'Shanghai' },
});
```

### call(message)

向小程序发送单向通知，不等待响应。

```js
await zml.call({
  method: 'settings.changed',
  params: { theme: 'dark' },
});
```

### detach()

解除当前插件的钩子并释放它持有的 ZML 上下文。插件关闭时 OronBox 也会自动清理。

```js
await zml.detach();
```

同一个 `appId` 只建立一个实际 App-side 会话。多个钩子不得创建第二条 BLE
连接；底层握手、分包、请求 ID、响应匹配和超时均由内置 ZML 运行时处理。
只有手表已连接、设备状态为 `ready`，并且对应小程序建立 App-side 会话后，
`request()` 和 `call()` 才能向手表发送数据。

## 方法

### list()

列出已缓存 app-side.js 脚本的 appId。

```js
const ids = await OronBox.appside.list();
// [0x0010ee3b, 0x00001234, ...]
```

### start(appId)

启动本地 AppSide QuickJS runtime。需要已缓存脚本。

```js
await OronBox.appside.start(0x0010ee3b);
```

### stop(appId)

停止 runtime。

```js
await OronBox.appside.stop(0x0010ee3b);
```

### send(appId, hexData)

将 hex 编码的二进制数据发往手表（需要手表已打开 real session）。

```js
await OronBox.appside.send(0x0010ee3b, '0100ff');
```

### inject(appId, hexData)

模拟手表发来消息，注入到本地 runtime（调试用，不需要手表打开 session）。

```js
await OronBox.appside.inject(0x0010ee3b, '48656c6c6f');
// "Hello" 的 hex → runtime 的 peerSocket.onmessage 会收到
```

### sessions()

列出当前所有活跃会话。

```js
const sessions = await OronBox.appside.sessions();
// [{ appId: 0x0010ee3b, version: 1, port1: 20, port2: 1004,
//    extra: 0, watchSessionOpen: true }, ...]
```

### events(appId)

读取调试事件日志。

```js
const events = await OronBox.appside.events(0x0010ee3b);
// [{ timestamp: '2024-01-01T00:00:00.000', type: 'start',
//    message: '脚本加载成功（1234 字符）' }, ...]
```

### clearEvents(appId)

清空调试事件。

```js
await OronBox.appside.clearEvents(0x0010ee3b);
```

## 完整示例：AppSide 管理面板

```js
globalThis.activate = async (plugin) => {
  let ids = [];
  let sessions = [];
  let result = '';
  const { Column, Text, Button } = OronBox.ui;

  const render = () => {
    const nodes = [
      Button('刷新列表', {
        onClick: OronBox.ui.action(async () => {
          ids = await OronBox.appside.list();
          result = `已缓存 ${ids.length} 个脚本: ${ids.map(i => '0x' + i.toString(16)).join(', ')}`;
        }, render),
      }),
      Button('查看会话', {
        onClick: OronBox.ui.action(async () => {
          sessions = await OronBox.appside.sessions();
          result = sessions.map(s =>
            `0x${s.appId.toString(16)}: watch=${s.watchSessionOpen}`
          ).join('\n') || '无活跃会话';
        }, render),
      }),
      Text(result),
    ];

    // 为每个缓存的 appId 添加启动/停止按钮
    for (const id of ids) {
      const hex = '0x' + id.toString(16);
      nodes.push(Button(`启动 ${hex}`, {
        onClick: OronBox.ui.action(async () => {
          try {
            await OronBox.appside.start(id);
            result = `${hex} 已启动`;
          } catch (e) { result = `启动失败: ${e.message}`; }
        }, render),
      }));
      nodes.push(Button(`停止 ${hex}`, {
        onClick: OronBox.ui.action(async () => {
          await OronBox.appside.stop(id);
          result = `${hex} 已停止`;
        }, render),
      }));
    }

    return OronBox.ui.render(Column({ gap: 8 }, nodes));
  };

  render();
};
```

## 权限

声明 `appside` 许可。只读操作（`list`、`sessions`、`events`）中等风险；
控制操作（`start`、`stop`、`send`、`inject`、`clearEvents`）高风险。
