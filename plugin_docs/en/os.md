# os — Host Environment Info

Retrieve information about the host OS. No permission required.

## Methods

```js
const arch       = await OronBox.os.arch();       // 'x64' | 'arm64' | 'unknown'
const hostname   = await OronBox.os.hostname();    // Desktop only
const locale     = await OronBox.os.locale();      // 'en_US' | 'zh_CN' | ...
const platform   = await OronBox.os.platform();    // 'linux' | 'macos' | 'windows' | 'android' | 'ios'
const version    = await OronBox.os.version();     // Desktop only
const language   = await OronBox.os.language();    // 'en' | 'zh' | ...
const appearance = await OronBox.os.appearance();  // 'light' | 'dark'
const timezone   = await OronBox.os.timezone();    // UTC offset in minutes, e.g. 480 = UTC+8
```

## Example

```js
globalThis.activate = async (plugin) => {
  const lines = [
    `Platform: ${await OronBox.os.platform()}`,
    `Arch: ${await OronBox.os.arch()}`,
    `Language: ${await OronBox.os.language()}`,
    `Locale: ${await OronBox.os.locale()}`,
    `Appearance: ${await OronBox.os.appearance()}`,
    `Timezone: UTC${await OronBox.os.timezone() >= 0 ? '+' : ''}${await OronBox.os.timezone() / 60}h`
  ];

  await OronBox.ui.render(OronBox.ui.Text(lines.join('\n')));
};
```
