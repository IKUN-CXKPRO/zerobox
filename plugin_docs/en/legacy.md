# ABv1 Compatibility Mode

OronBox is compatible with AstroBox v1 (ABv1) plugin packages. ABv1 plugins use
the `.abp` extension and run through a built-in adapter that translates the legacy
`AstroBox.*` API into current `OronBox.*` host calls.

## Detection

ABv1 plugins do not declare a `runtime` field in `manifest.json`. OronBox
automatically treats them as `runtime: legacy`. The plugin ID is auto-generated
from the SHA256 hash of the plugin name (first 12 hex chars) — no explicit `id`
is needed.

```json
{
  "name": "testplugin",
  "icon": "icon.png",
  "version": "1.0",
  "description": "Test plugin",
  "author": "test",
  "entry": "main.js",
  "permissions": ["lifecycle", "native", "ui"]
}
```

## Entry Point

ABv1 plugins use `lifecycle.onLoad` instead of `activate()`:

```js
AstroBox.lifecycle.onLoad(async () => {
  console.info('ABv1 plugin started');
});
```

Runtime globals:
- `RUNTIME` — always `"AstroBox"`
- `RUNTIME_VERSION` — OronBox version
- `PLUGIN_NAME` — plugin name
- `PLUGIN_PATH` — `"oronbox-plugin://<id>"`
- `PLUGIN_VERSION` — plugin version

## API Mapping

The adapter injects an `AstroBox` global object in JS that translates calls:

| ABv1 API | OronBox API | Notes |
|----------|-------------|-------|
| `AstroBox.config.readConfig()` | `OronBox.storage.get('__astrobox_config')` | JSON round-trip |
| `AstroBox.config.writeConfig(json)` | `OronBox.storage.set('__astrobox_config', ...)` | |
| `AstroBox.filesystem.pickFile(opts)` | `OronBox.file.pick(opts)` | Returns `{path, size, text_len}` |
| `AstroBox.filesystem.readFile(path, opts)` | `OronBox.file.read(path, opts)` | Text/Binary support |
| `AstroBox.filesystem.unloadFile(path)` | `OronBox.file.remove(path)` | Delete temp file |
| `AstroBox.network.fetch(url, opts)` | `OronBox.network.fetch(url, opts)` | Direct pass-through |
| `AstroBox.interconnect.sendQAICMessage(pkg, data)` | `OronBox.interconnect.send(pkg, data)` | |
| `AstroBox.event.addEventListener('onQAICMessage_<pkg>', fn)` | `OronBox.interconnect.onMessage(...)` | Auto subscribe/unsubscribe |
| `AstroBox.installer.addThirdPartyAppToQueue(path)` | `OronBox.device.install(path, {type:'app'})` | |
| `AstroBox.installer.addWatchFaceToQueue(path)` | `OronBox.device.install(path, {type:'watchface'})` | |
| `AstroBox.installer.addFirmwareToQueue(path)` | `OronBox.device.install(path, {type:'firmware'})` | |
| `AstroBox.thirdpartyapp.getThirdPartyAppList()` | `OronBox.device.apps.list()` | Field name conversion |
| `AstroBox.thirdpartyapp.launchQA(app, page)` | `OronBox.device.apps.launch(pkg, {page})` | |
| `AstroBox.device.getDeviceList()` | `OronBox.device.list()` | |
| `AstroBox.device.getDeviceState(addr)` | `OronBox.device.list()` + lookup | Mock legacy fields |
| `AstroBox.device.disconnectDevice()` | `OronBox.device.disconnect()` | |
| `AstroBox.debug.sendRaw(data)` | `OronBox.protocol.send(data)` | |
| `AstroBox.ui.updatePluginSettingsUI(nodes)` | `OronBox.ui.update(nodes)` | Direct pass-through |
| `AstroBox.ui.openPageWithNodes(nodes)` | `OronBox.ui.openPage(nodes)` | Direct pass-through |
| `AstroBox.ui.openPageWithUrl(url)` | `OronBox.ui.openExternal(url)` | Direct pass-through |
| `AstroBox.native.regNativeFun(fn)` | `OronBox.ui.callback(fn)` | Returns callback ID |

## Path Remapping

ABv1 plugins use `/package/` and `/tmp/` prefixes. The adapter remaps them:

| ABv1 path | OronBox path |
|-----------|-------------|
| `/package/` | `/plugin/` |
| `/tmp/` | `/temp/` |

## Unsupported Features

These ABv1 APIs throw errors in OronBox:

- `AstroBox.device.modifyDeviceState()` — device state is read-only in OronBox
- `AstroBox.provider.registerCommunityProvider()` — use native `OronBox.provider.register()`
  instead, but ABv1 plugins cannot access the native API

## Permissions

ABv1 manifest may declare legacy permission names (e.g. `lifecycle`, `native`). OronBox
ignores unknown names during validation. At runtime, the adapter calls the corresponding
`OronBox.*` host methods, which go through the native permission system. For example,
`AstroBox.interconnect.sendQAICMessage` triggers the `interconnect:send` medium-risk
authorization dialog.

## Migration Guide

Dual-compatibility pattern:

```js
if (typeof RUNTIME === 'string' && RUNTIME === 'AstroBox') {
  AstroBox.lifecycle.onLoad(async () => { /* ABv1 API */ });
} else if (typeof OronBox !== 'undefined') {
  globalThis.activate = async (plugin) => { /* OronBox API */ };
}
```

Prefer native OronBox format (`.zbp` + `runtime: "js"` + `OronBox.*` API) for full
feature access and better performance.
