# storage — Key-Value Storage

Persistent key-value pairs, removed when the plugin is uninstalled. Values can
be any JSON-serializable data.

## Methods

### get(key)

```js
const value = await OronBox.storage.get('lastVisit');
// Returns the stored value, or undefined if never set
```

### set(key, value)

```js
await OronBox.storage.set('lastVisit', new Date().toISOString());
await OronBox.storage.set('theme', 'dark');
await OronBox.storage.set('prefs', { fontSize: 14, lineHeight: 1.5 });
```

### remove(key)

```js
await OronBox.storage.remove('theme');
```

### clear()

```js
await OronBox.storage.clear();
```

## Example: Visit Tracker

```js
globalThis.activate = async (plugin) => {
  let lastVisit = (await OronBox.storage.get('lastVisit')) || 'Never';
  let visitCount = (await OronBox.storage.get('visitCount')) || 0;
  const { Column, Text, Button } = OronBox.ui;

  const recordVisit = async () => {
    visitCount++;
    lastVisit = new Date().toLocaleString();
    await OronBox.storage.set('visitCount', visitCount);
    await OronBox.storage.set('lastVisit', lastVisit);
  };

  const render = () => OronBox.ui.render(
    Column({ gap: 8 }, [
      Text(`Last visit: ${lastVisit}`),
      Text(`Visits: ${visitCount}`),
      Button('Record visit', { onClick: OronBox.ui.action(recordVisit, render) }),
    ]),
  );

  render();
};
```
