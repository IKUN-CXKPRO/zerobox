# interconnect — Cross-Plugin Messaging

Send and receive raw text messages between plugins identified by package name.
OronBox provides infrastructure only — no file transfer, chunking, or ack protocol.

## send(packageName, data, deviceId?)

```js
await OronBox.interconnect.send('com.example.target', 'hello from plugin');
```

## onMessage(callback)

Starts listening for messages from other plugins. Returns a stop function.

```js
const stop = await OronBox.interconnect.onMessage(({ packageName, data }) => {
  console.info(`Received from ${packageName}: ${data}`);
});

// Stop listening
await stop();
```

## Example: Messenger

```js
globalThis.activate = async (plugin) => {
  let target = '';
  let message = '';
  let received = '';
  const { Column, Text, TextField, Button } = OronBox.ui;

  OronBox.interconnect.onMessage(({ packageName, data }) => {
    received = `[${packageName}] ${data}`;
    render();
  });

  const render = () => OronBox.ui.render(
    Column({ gap: 8 }, [
      TextField({ value: target, placeholder: 'Target package', onChange: v => { target = v; } }),
      TextField({ value: message, placeholder: 'Message', onChange: v => { message = v; } }),
      Button('Send', { onClick: () => OronBox.interconnect.send(target, message) }),
      Text(received || 'Waiting...'),
    ]),
  );

  render();
};
```

## Permission

Declare `interconnect`. Medium-risk.
