# storage — 键值存储

持久化键值对，卸载插件时一并删除。值可以是任意 JSON 可序列化的数据。

## 方法

### get(key)

读取一个键的值。

```js
const value = await OronBox.storage.get('lastVisit');
// value 为存储的值，未设置过则返回 undefined
```

### set(key, value)

写入一个键值对。

```js
await OronBox.storage.set('lastVisit', new Date().toISOString());
await OronBox.storage.set('theme', 'dark');
await OronBox.storage.set('prefs', { fontSize: 14, lineHeight: 1.5 });
```

### remove(key)

删除一个键。

```js
await OronBox.storage.remove('theme');
```

### clear()

清空所有存储。

```js
await OronBox.storage.clear();
```

## 完整示例

```js
globalThis.activate = async (plugin) => {
  let lastVisit = (await OronBox.storage.get('lastVisit')) || '从未访问';
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
      Text(`上次访问: ${lastVisit}`),
      Text(`访问次数: ${visitCount}`),
      Button('记录访问', { onClick: OronBox.ui.action(recordVisit, render) }),
    ]),
  );

  render();
};
```
