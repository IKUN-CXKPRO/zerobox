import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:segmented_list/segmented_list.dart';
import 'package:segmented_list/tile/segmented_tile_info.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/core/models/bt_models.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/features/devices/models/xiaomi_device_features.dart';
import 'package:oronbox/src/features/devices/services/xiaomi_weather_sync_service.dart';
import 'package:oronbox/src/protocols/common/device_protocol.dart' as proto;

class XiaomiAppOrderPage extends ConsumerStatefulWidget {
  const XiaomiAppOrderPage({super.key});

  @override
  ConsumerState<XiaomiAppOrderPage> createState() => _XiaomiAppOrderPageState();
}

class _XiaomiAppOrderPageState extends ConsumerState<XiaomiAppOrderPage> {
  List<AppInfo> _apps = const [];
  List<AppInfo> _savedApps = const [];
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    if (_saving) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final apps = await ref
          .read(deviceManagerProvider.notifier)
          .loadXiaomiAppOrder();
      if (mounted) {
        setState(() {
          _apps = List.unmodifiable(apps);
          _savedApps = List.unmodifiable(apps);
          _dirty = false;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (_saving || oldIndex == newIndex) return;
    final next = [..._apps];
    final item = next.removeAt(oldIndex);
    final targetIndex = newIndex.clamp(0, next.length);
    next.insert(targetIndex, item);
    setState(() {
      _apps = next;
      _dirty = true;
    });
  }

  Future<void> _save() async {
    if (_saving || !_dirty) return;
    setState(() => _saving = true);
    try {
      await ref.read(deviceManagerProvider.notifier).setXiaomiAppOrder(_apps);
      if (mounted) {
        setState(() {
          _savedApps = List.unmodifiable(_apps);
          _dirty = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('应用顺序已保存')));
      }
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _reset() {
    if (_saving || !_dirty) return;
    setState(() {
      _apps = List.unmodifiable(_savedApps);
      _dirty = false;
    });
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          localizedErrorMessage(AppLocalizations.of(context)!, error),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deviceManagerProvider);
    final ready = state.protocolState == proto.ProtocolState.ready;
    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: const Text('应用顺序管理'),
        actions: [
          IconButton(
            onPressed: !_loading && !_saving && !_dirty ? _load : null,
            tooltip: '重新读取',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: _dirty
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'xiaomi-app-order-reset',
                  onPressed: _saving ? null : _reset,
                  icon: const Icon(Icons.undo),
                  label: const Text('撤销更改'),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.extended(
                  heroTag: 'xiaomi-app-order-save',
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_saving ? '保存中…' : '保存更改'),
                ),
              ],
            )
          : null,
      body: !ready
          ? const Center(child: Text('设备未连接'))
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _AppOrderError(message: _error!, onRetry: _load)
          : _apps.isEmpty
          ? const Center(child: Text('设备没有返回可排序的应用'))
          : Column(
              children: [
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 24),
                    itemCount: _apps.length,
                    onReorderItem: _reorder,
                    buildDefaultDragHandles: false,
                    proxyDecorator: (child, _, _) => child,
                    itemBuilder: (context, index) {
                      final app = _apps[index];
                      final title = app.appName.trim().isEmpty
                          ? app.packageName
                          : app.appName;
                      return Center(
                        key: ValueKey(app.packageName),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: StyleConstants.pageMaxWidth,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: SegmentedTileInfo(
                              isTopTile: index == 0,
                              isBottomTile: index == _apps.length - 1,
                              needDivider: index != _apps.length - 1,
                              child: _ReorderableAppTile(
                                index: index,
                                title: title,
                                enabled: !_saving,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _ReorderableAppTile extends StatelessWidget {
  const _ReorderableAppTile({
    required this.index,
    required this.title,
    required this.enabled,
  });

  final int index;
  final String title;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tileInfo = SegmentedTileInfo.of(context);
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(tileInfo.isTopTile ? 20 : 3),
            bottom: Radius.circular(tileInfo.isBottomTile ? 20 : 3),
          ),
          child: Material(
            color:
                theme.cardTheme.color ??
                theme.colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                SizedBox(
                  width: 52,
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: enabled
                            ? theme.colorScheme.primary
                            : theme.disabledColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    child: Text(
                      title,
                      style: TextStyle(
                        color: enabled
                            ? theme.colorScheme.onSurface
                            : theme.disabledColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                ReorderableDragStartListener(
                  index: index,
                  enabled: enabled,
                  child: const SizedBox(
                    width: 56,
                    height: 64,
                    child: Center(child: Icon(Icons.drag_handle)),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (tileInfo.needDivider) const SizedBox(height: 2),
      ],
    );
  }
}

class _AppOrderError extends StatelessWidget {
  const _AppOrderError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 40),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.tonal(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    ),
  );
}

class XiaomiAlarmsPage extends ConsumerStatefulWidget {
  const XiaomiAlarmsPage({super.key});

  @override
  ConsumerState<XiaomiAlarmsPage> createState() => _XiaomiAlarmsPageState();
}

class _XiaomiAlarmsPageState extends ConsumerState<XiaomiAlarmsPage> {
  List<XiaomiAlarm> _alarms = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final alarms = await ref
          .read(deviceManagerProvider.notifier)
          .loadXiaomiAlarms();
      if (mounted) setState(() => _alarms = alarms);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final draft = await _editAlarm();
    if (draft == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(deviceManagerProvider.notifier).addXiaomiAlarm(draft);
      await _load();
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(XiaomiAlarm alarm) async {
    final edited = await _editAlarm(alarm);
    if (edited == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(deviceManagerProvider.notifier).updateXiaomiAlarm(edited);
      await _load();
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<XiaomiAlarm?> _editAlarm([XiaomiAlarm? initial]) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: initial?.hour ?? TimeOfDay.now().hour,
        minute: initial?.minute ?? TimeOfDay.now().minute,
      ),
    );
    if (time == null || !mounted) return null;
    final labelController = TextEditingController(text: initial?.label ?? '');
    final label = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(initial == null ? '添加闹钟' : '编辑闹钟'),
        content: TextField(
          controller: labelController,
          autofocus: true,
          decoration: const InputDecoration(labelText: '标签（可选）'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, labelController.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    labelController.dispose();
    if (label == null) return null;
    return XiaomiAlarm(
      id: initial?.id ?? 0,
      hour: time.hour,
      minute: time.minute,
      clockMode: initial?.clockMode ?? 1,
      weekDays: initial?.weekDays ?? 127,
      enabled: initial?.enabled ?? true,
      label: label,
    );
  }

  Future<void> _toggle(XiaomiAlarm alarm, bool enabled) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(deviceManagerProvider.notifier)
          .setXiaomiAlarmEnabled(alarm.id, enabled);
      await _load();
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(XiaomiAlarm alarm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除闹钟？'),
        content: Text('${_time(alarm)} ${alarm.label}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(deviceManagerProvider.notifier)
          .removeXiaomiAlarm(alarm.id);
      await _load();
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          localizedErrorMessage(AppLocalizations.of(context)!, error),
        ),
      ),
    );
  }

  String _time(XiaomiAlarm alarm) =>
      '${alarm.hour.toString().padLeft(2, '0')}:${alarm.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deviceManagerProvider);
    final ready = state.protocolState == proto.ProtocolState.ready;
    return Scaffold(
      appBar: SysAppBar(secondary: true, title: const Text('闹钟管理')),
      floatingActionButton: ready && !_busy
          ? FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('添加闹钟'),
            )
          : null,
      body: !ready
          ? const Center(child: Text('设备未连接'))
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : SegmentedList(
              maxWidth: StyleConstants.pageMaxWidth,
              contentPadding: const EdgeInsets.only(top: 8, bottom: 24),
              sections: [
                SegmentedSection(
                  tiles: [
                    for (final alarm in _alarms)
                      SegmentedTile.switchTile(
                        key: ValueKey(alarm.id),
                        leading: const Icon(Icons.alarm_outlined),
                        title: Text(_time(alarm)),
                        description: Text(
                          alarm.label.isEmpty ? '每天' : alarm.label,
                        ),
                        initialValue: alarm.enabled,
                        enabled: !_busy,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: _busy ? null : () => _edit(alarm),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              onPressed: _busy ? null : () => _remove(alarm),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                        onToggle: (value) => _toggle(alarm, value ?? false),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

class XiaomiWeatherPage extends ConsumerStatefulWidget {
  const XiaomiWeatherPage({super.key});

  @override
  ConsumerState<XiaomiWeatherPage> createState() => _XiaomiWeatherPageState();
}

class _XiaomiWeatherPageState extends ConsumerState<XiaomiWeatherPage> {
  final _cityController = TextEditingController();
  final _weatherService = XiaomiWeatherSyncService();
  XiaomiWeatherData? _weather;
  bool _syncing = false;
  String? _error;

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() {
      _syncing = true;
      _error = null;
    });
    try {
      final weather = await _weatherService.fetch(_cityController.text);
      await ref.read(deviceManagerProvider.notifier).syncXiaomiWeather(weather);
      if (mounted) setState(() => _weather = weather);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = localizedErrorMessage(
            AppLocalizations.of(context)!,
            error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deviceManagerProvider);
    final ready = state.protocolState == proto.ProtocolState.ready;
    final weather = _weather;
    return Scaffold(
      appBar: SysAppBar(secondary: true, title: const Text('天气同步')),
      body: SegmentedList(
        maxWidth: StyleConstants.pageMaxWidth,
        contentPadding: const EdgeInsets.only(top: 8, bottom: 24),
        sections: [
          CustomSegmentedSection(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '选择城市后，OronBox 会把当前天气和未来预报一次性同步到设备',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _cityController,
                        enabled: ready && !_syncing,
                        decoration: const InputDecoration(
                          labelText: '同步城市',
                          hintText: '例如：上海',
                          prefixIcon: Icon(Icons.location_city_outlined),
                          suffixIcon: Icon(Icons.search),
                        ),
                        onSubmitted: (_) => _sync(),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: ready && !_syncing ? _sync : null,
                          icon: _syncing
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.sync),
                          label: Text(_syncing ? '同步中…' : '同步天气'),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      if (weather != null) ...[
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              _weatherIcon(weather.conditionCode),
                              size: 42,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    weather.cityName,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  Text(
                                    '${weather.temperature}℃ · ${_weatherCondition(weather.conditionCode)}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineSmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '湿度 ${weather.humidity}% · 风力 ${weather.windSpeedBeaufort} 级',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '已同步未来 ${weather.hourly.length} 小时和 ${weather.daily.length} 天预报',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (weather != null && weather.hourly.isNotEmpty)
            CustomSegmentedSection(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '未来 24 小时',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 124,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: weather.hourly.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final hour = weather.hourly[index];
                              return SizedBox(
                                width: 82,
                                child: Card(
                                  margin: EdgeInsets.zero,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 10,
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(_hourLabel(hour.time)),
                                        Icon(
                                          _weatherIcon(hour.conditionCode),
                                          size: 24,
                                        ),
                                        Text(
                                          '${hour.temperature}℃',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (weather != null && weather.daily.isNotEmpty)
            CustomSegmentedSection(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '未来 7 天',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        for (final day in weather.daily)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(_weatherIcon(day.conditionCode)),
                            title: Text(_dayLabel(day.date)),
                            subtitle: Text(
                              _weatherCondition(day.conditionCode),
                            ),
                            trailing: Text(
                              '${day.minimumTemperature}℃ / ${day.maximumTemperature}℃',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

IconData _weatherIcon(int conditionCode) => switch (conditionCode) {
  0 => Icons.wb_sunny_outlined,
  1 => Icons.wb_cloudy_outlined,
  2 => Icons.cloud_outlined,
  3 || 7 => Icons.grain,
  8 || 9 || 11 => Icons.water_drop_outlined,
  4 || 5 => Icons.thunderstorm_outlined,
  14 || 15 || 16 => Icons.ac_unit_outlined,
  18 || 19 => Icons.foggy,
  _ => Icons.cloud_outlined,
};

String _weatherCondition(int conditionCode) => switch (conditionCode) {
  0 => '晴',
  1 => '少云',
  2 => '阴',
  3 || 7 => '小雨',
  8 || 9 || 11 => '大雨',
  4 || 5 => '雷雨',
  14 || 15 || 16 => '降雪',
  18 || 19 => '雾',
  _ => '未知',
};

String _hourLabel(String value) {
  if (value.length >= 16) return value.substring(11, 16);
  return value;
}

String _dayLabel(String value) {
  if (value.length >= 10) return value.substring(5, 10);
  return value.isEmpty ? '未知日期' : value;
}
