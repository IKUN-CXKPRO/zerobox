# appside — Zepp OS AppSide Management

Manage AppSide sessions on Zepp OS devices. AppSide is a remote JS execution
channel (Bluetooth endpoint `0x00a0`) that runs alongside watch mini-apps,
communicating with them in real time via `messaging.peerSocket`.

`appId` is a 32-bit unsigned integer (Zepp OS app ID).

## ZML

> Usage reference: [ZML](https://zepp-health.github.io/zml/zh/getting-started)

OronBox includes a self-contained ZML App-side communication runtime. Plugins do
not need to package `@zeppos/zml` themselves. Use `attach()` to bind the runtime
to a mini-app and use the official `BaseSideService`-style `this.request()`,
`this.call()`, `onRequest`, and `onCall` APIs from plugin hooks.

The plugin's `manifest.json` must declare the `appside` permission:

```json
{
  "permissions": ["appside"]
}
```

### attach(options)

Create or obtain the ZML context for an `appId`. The `onInit`, `onRun`,
`onDestroy`, `onRequest`, and `onCall` hooks are optional. Inside each hook,
`this` is the same ZML context returned by `attach()`.

```js
globalThis.activate = async () => {
  const zml = await OronBox.appside.attach({
    appId: 0x0010ee3b,

    onInit() {
      console.log('ZML App-side initialized');
    },

    async onRun() {
      const result = await this.request({
        method: 'device.getData',
        params: { type: 'summary' },
      });
      console.log('Watch response:', JSON.stringify(result));
    },

    onRequest(req, res) {
      if (req.method === 'plugin.getState') {
        res(null, { ready: true });
        return;
      }
      res({
        code: 'METHOD_NOT_FOUND',
        message: `Unknown method: ${req.method}`,
      });
    },

    onCall(message) {
      console.log('Watch notification:', JSON.stringify(message));
    },

    onDestroy() {
      console.log('ZML App-side stopped');
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

Send a ZML request that expects a response and return a Promise. The default
timeout follows the bundled ZML runtime configuration.

```js
const result = await zml.request({
  method: 'weather.get',
  params: { city: 'Shanghai' },
});
```

### call(message)

Send a one-way notification without waiting for a response.

```js
await zml.call({
  method: 'settings.changed',
  params: { theme: 'dark' },
});
```

### detach()

Remove this plugin's hooks and release its ZML context. OronBox also cleans it up
automatically when the plugin closes.

```js
await zml.detach();
```

Only one physical App-side session is created for each `appId`. Hooks must not
open another BLE connection. The bundled runtime owns the handshake, framing,
request IDs, response matching, and timeouts. `request()` and `call()` can send
data only after the watch is connected, the device is `ready`, and the mini-app
has opened its App-side session.

## Methods

### list()

```js
const ids = await OronBox.appside.list();
// [0x0010ee3b, 0x00001234, ...]
```

### start(appId)

Start the local AppSide QuickJS runtime (requires a cached script).

```js
await OronBox.appside.start(0x0010ee3b);
```

### stop(appId)

```js
await OronBox.appside.stop(0x0010ee3b);
```

### send(appId, hexData)

Send hex-encoded binary data to the watch (requires an active watch session).

```js
await OronBox.appside.send(0x0010ee3b, '0100ff');
```

### inject(appId, hexData)

Simulate a watch-to-host message, injecting into the local runtime (debugging — no watch session needed).

```js
await OronBox.appside.inject(0x0010ee3b, '48656c6c6f');
// "Hello" in hex → runtime's peerSocket.onmessage receives it
```

### sessions()

List all active sessions.

```js
const sessions = await OronBox.appside.sessions();
// [{ appId: 0x0010ee3b, version: 1, port1: 20, port2: 1004,
//    extra: 0, watchSessionOpen: true }, ...]
```

### events(appId)

Read debug event logs for an appId.

```js
const events = await OronBox.appside.events(0x0010ee3b);
// [{ timestamp: '2024-...', type: 'start', message: 'Script loaded (1234 chars)' }, ...]
```

### clearEvents(appId)

```js
await OronBox.appside.clearEvents(0x0010ee3b);
```

## Example: AppSide Manager

```js
globalThis.activate = async (plugin) => {
  let ids = [];
  let result = '';
  const { Column, Text, Button } = OronBox.ui;

  const render = () => {
    const nodes = [
      Button('Refresh', {
        onClick: OronBox.ui.action(async () => {
          ids = await OronBox.appside.list();
          result = `${ids.length} scripts cached: ${ids.map(i => '0x'+i.toString(16)).join(', ')}`;
        }, render),
      }),
      Text(result),
    ];

    for (const id of ids) {
      const hex = '0x' + id.toString(16);
      nodes.push(Button(`Start ${hex}`, {
        onClick: OronBox.ui.action(async () => {
          try { await OronBox.appside.start(id); result = `${hex} started`; }
          catch (e) { result = `Error: ${e.message}`; }
        }, render),
      }));
    }
    return OronBox.ui.render(Column({ gap: 8 }, nodes));
  };

  render();
};
```

## Permission

Declare `appside`. Read-only operations (`list`, `sessions`, `events`) are medium-risk;
control operations (`start`, `stop`, `send`, `inject`, `clearEvents`) are high-risk.
