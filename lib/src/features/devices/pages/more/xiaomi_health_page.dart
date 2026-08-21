import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:segmented_list/segmented_list.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/features/devices/health/health_cards.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';
import 'package:oronbox/src/features/devices/pages/more/xiaomi_health_detail_page.dart';
import 'package:oronbox/src/features/devices/widgets/xiaomi_fitness_logo.dart';
import 'package:oronbox/src/protocols/common/device_protocol.dart';

class XiaomiHealthPage extends ConsumerStatefulWidget {
  const XiaomiHealthPage({super.key});

  @override
  ConsumerState<XiaomiHealthPage> createState() => _XiaomiHealthPageState();
}

class _XiaomiHealthPageState extends ConsumerState<XiaomiHealthPage> {
  XiaomiHealthData? _data;
  String? _error;
  bool _loading = true;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await ref
          .read(deviceManagerProvider.notifier)
          .loadXiaomiHealthData();
      if (!mounted) return;
      setState(() => _data = data);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _healthErrorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() {
      _syncing = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(deviceManagerProvider.notifier)
          .syncXiaomiHealth();
      if (!mounted) return;
      setState(() => _data = result.data);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _healthErrorMessage(error));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _openDetail(XiaomiHealthMetric metric) {
    final data = _data;
    if (data == null) return;
    context.push(
      '/devices/velaos-health/detail',
      extra: XiaomiHealthDetailArgs(metric: metric, data: data),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final data = _data;
    final ready =
        ref.watch(deviceManagerProvider).protocolState == ProtocolState.ready;
    return Scaffold(
      appBar: SysAppBar(secondary: true, title: Text(l10n.deviceHealthTitle)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SegmentedList(
          maxWidth: StyleConstants.pageMaxWidth,
          contentPadding: const EdgeInsets.only(top: 8, bottom: 24),
          sections: [
            SegmentedSection(
              tiles: [
                SegmentedTile(
                  leading: _syncing
                      ? const SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const XiaomiFitnessLogo(),
                  title: Text(
                    _syncing ? l10n.deviceHealthSyncing : l10n.deviceHealthSync,
                  ),
                  description: Text(
                    data?.lastSyncedAt == null
                        ? l10n.deviceHealthNeverSynced
                        : l10n.deviceHealthLastSynced(
                            _formatDateTime(data!.lastSyncedAt!),
                          ),
                  ),
                  enabled: ready && !_syncing,
                  trailing: IconButton(
                    onPressed: ready && !_syncing ? _sync : null,
                    icon: const Icon(Icons.sync),
                    tooltip: l10n.deviceHealthSync,
                  ),
                  onPressed: (_) {
                    if (ready && !_syncing) _sync();
                  },
                ),
              ],
            ),
            if (_error != null)
              SegmentedSection(
                tiles: [
                  SegmentedTile(
                    leading: const Icon(Icons.error_outline),
                    title: Text(l10n.deviceHealthLoadFailed),
                    description: Text(_error!),
                    trailing: IconButton(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                    ),
                  ),
                ],
              ),
            if (_loading && data == null)
              const CustomSegmentedSection(
                child: SizedBox(
                  height: 220,
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else
              CustomSegmentedSection(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: AdaptiveHealthCardWrap(children: _cards(data)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _cards(XiaomiHealthData? data) {
    final value = data ?? const XiaomiHealthData();
    final cards = <Widget>[
      ActivityOverviewCard(
        summary: value.activitySummary,
        onPressed: () => _openDetail(XiaomiHealthMetric.activity),
      ),
    ];
    final capabilities = value.capabilities;
    if (capabilities.heartRate) {
      cards.add(
        _metricCard(
          data: value,
          metric: XiaomiHealthMetric.heartRate,
          title: '心率',
          icon: Icons.favorite_outline,
          color: Colors.redAccent,
          summaryValue: value.latestDay?.averageHeartRate,
          unit: 'bpm',
          detail: _range(
            value.latestDay?.minHeartRate,
            value.latestDay?.maxHeartRate,
            'bpm',
          ),
        ),
      );
    }
    if (capabilities.bloodOxygen) {
      cards.add(
        _metricCard(
          data: value,
          metric: XiaomiHealthMetric.bloodOxygen,
          title: '血氧',
          icon: Icons.bloodtype_outlined,
          color: Colors.indigo,
          summaryValue: value.latestDay?.averageBloodOxygen,
          unit: '%',
          detail: _range(
            value.latestDay?.minBloodOxygen,
            value.latestDay?.maxBloodOxygen,
            '%',
          ),
        ),
      );
    }
    if (capabilities.stress) {
      cards.add(
        _metricCard(
          data: value,
          metric: XiaomiHealthMetric.stress,
          title: '压力',
          icon: Icons.spa_outlined,
          color: Colors.orange,
          summaryValue: value.latestDay?.averageStress,
          unit: '',
          detail: _range(
            value.latestDay?.minStress,
            value.latestDay?.maxStress,
            '',
          ),
        ),
      );
    }
    if (capabilities.vitality) {
      cards.add(
        _metricCard(
          data: value,
          metric: XiaomiHealthMetric.vitality,
          title: '元气值',
          icon: Icons.bolt_outlined,
          color: Colors.amber,
          summaryValue: value.latestDay?.vitalityCurrent,
          unit: '',
          detail: '今日累计',
        ),
      );
    }
    if (capabilities.sleep) {
      final sleep = value.latestSleep;
      cards.add(
        HealthMetricCard(
          metric: XiaomiHealthMetric.sleep,
          title: '睡眠',
          icon: Icons.bedtime_outlined,
          color: Colors.deepPurple,
          value: sleep == null ? '—' : _duration(sleep.durationSeconds),
          detail: sleep == null
              ? '暂无数据'
              : '${_formatTime(sleep.startedAt)} – ${_formatTime(sleep.endedAt)}',
          samples: const [],
          onPressed: () => _openDetail(XiaomiHealthMetric.sleep),
        ),
      );
    }
    if (capabilities.workouts) {
      cards.add(
        HealthMetricCard(
          metric: XiaomiHealthMetric.workout,
          title: '运动记录',
          icon: Icons.directions_run_outlined,
          color: Colors.teal,
          value: '${value.workouts.length}',
          detail: '条记录',
          samples: const [],
          onPressed: () => _openDetail(XiaomiHealthMetric.workout),
        ),
      );
    }
    return cards;
  }

  HealthMetricCard _metricCard({
    required XiaomiHealthData data,
    required XiaomiHealthMetric metric,
    required String title,
    required IconData icon,
    required Color color,
    required int? summaryValue,
    required String unit,
    required String detail,
  }) {
    final latest = data.latestSample(metric);
    final samples =
        data.samplesFor(metric).where((sample) => sample.isUsable).toList()
          ..sort((left, right) => left.timestamp.compareTo(right.timestamp));
    final visibleSamples = samples.length <= 120
        ? samples
        : samples.sublist(samples.length - 120);
    final displayedValue = latest?.value.round() ?? summaryValue;
    return HealthMetricCard(
      metric: metric,
      title: title,
      icon: icon,
      color: color,
      value: displayedValue == null ? '—' : '$displayedValue $unit'.trim(),
      detail: latest == null ? detail : _formatDateTime(latest.timestamp),
      samples: visibleSamples,
      onPressed: () => _openDetail(metric),
    );
  }

  String _range(int? min, int? max, String unit) {
    if (min == null && max == null) return '暂无详细范围';
    if (min == null || max == null) return '${min ?? max} $unit'.trim();
    return '$min–$max $unit'.trim();
  }

  String _healthErrorMessage(Object error) {
    if (error is UnsupportedError) {
      return AppLocalizations.of(context)!.errorUnknown;
    }
    return localizedErrorMessage(AppLocalizations.of(context)!, error);
  }
}

String _formatDateTime(DateTime value) =>
    '${value.month}/${value.day} ${_formatTime(value)}';
String _formatTime(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
String _duration(int seconds) =>
    '${seconds ~/ 3600}h ${((seconds % 3600) ~/ 60).toString().padLeft(2, '0')}m';
