# file — Sandboxed File System

Plugins have an isolated file system with four areas:

| Area | Prefix | Access | Description |
|------|--------|--------|-------------|
| Package | `/plugin` | Read-only | Files bundled in the `.zbp` |
| Data | `/data` | Read/write | Persistent storage |
| Cache | `/cache` | Read/write | May be cleared by the system |
| Temp | `/temp` | Read/write | Cleared on restart |

Binary data uses Base64 encoding.

## Read & Write

### read(path, options)

```js
// Read as UTF-8 text
const text = await OronBox.file.read('/data/note.txt', { encoding: 'utf8' });

// Read as Base64 binary
const base64 = await OronBox.file.read('/data/image.png', { encoding: 'base64' });

// Read a slice
const chunk = await OronBox.file.read('/data/large.bin', {
  encoding: 'base64',
  offset: 1024,
  length: 512
});
```

### write(path, data, options)

```js
// Write UTF-8 text
await OronBox.file.write('/data/note.txt', 'Hello World', { encoding: 'utf8' });

// Write Base64 binary
await OronBox.file.write('/data/image.png', base64data, { encoding: 'base64' });

// Append
await OronBox.file.write('/data/log.txt', 'new line\n', {
  encoding: 'utf8', append: true
});
```

## Directory Operations

```js
// List → [{name, path, size, isDirectory}, ...]
const entries = await OronBox.file.list('/data');

// Stat → {name, path, size, isDirectory} or null
const stat = await OronBox.file.stat('/data/note.txt');

// Create directory
await OronBox.file.mkdir('/data/subdir');

// Copy
await OronBox.file.copy('/data/a.txt', '/data/b.txt');

// Move
await OronBox.file.move('/temp/a.txt', '/data/a.txt');

// Remove
await OronBox.file.remove('/data/old.txt');
```

## Native File Interaction

### pick(options)

Opens the system file picker, imports selection to `/temp/picker/...`.

```js
const picked = await OronBox.file.pick({});
if (!picked) return; // User cancelled
// picked = { name: 'photo.png', path: '/temp/picker/.../photo.png', size: 102400 }
```

### unload(path, options)

Exports a sandbox file to the host (triggers a save dialog).

```js
const result = await OronBox.file.unload('/data/report.pdf', {
  suggestedName: 'Report.pdf'
});
// result = { exported: true, name: 'Report.pdf' }
```

## Example: Logger

```js
globalThis.activate = async (plugin) => {
  const LOG_PATH = '/data/log.txt';
  let logs = '';
  const { Column, Text, Button } = OronBox.ui;

  const addLog = async () => {
    const line = `[${new Date().toLocaleTimeString()}] Log entry\n`;
    await OronBox.file.write(LOG_PATH, line, { encoding: 'utf8', append: true });
    logs = await OronBox.file.read(LOG_PATH, { encoding: 'utf8' });
  };

  const clearLogs = async () => {
    await OronBox.file.remove(LOG_PATH);
    logs = '';
  };

  const render = () => OronBox.ui.render(
    Column({ gap: 8 }, [
      Text(logs || 'No logs yet'),
      Button('Add log', { onClick: OronBox.ui.action(addLog, render) }),
      Button('Clear', { onClick: OronBox.ui.action(clearLogs, render) }),
    ]),
  );

  try { logs = await OronBox.file.read(LOG_PATH, { encoding: 'utf8' }); } catch (_) {}
  render();
};
```

## Permission

Declare `file` in the manifest. Basic read/write is low-risk; `pick` and `unload` are medium-risk.
