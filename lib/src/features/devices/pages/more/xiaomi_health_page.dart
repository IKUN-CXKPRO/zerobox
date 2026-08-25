import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:segmented_list/segmented_list.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/core/services/status_surface_bridge.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/features/devices/health/health_cards.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';
import 'package:oronbox/src/features/devices/pages/more/xiaomi_health_detail_page.dart';
import 'package:oronbox/src/features/devices/services/xiaomi_automatic_sync_service.dart';
import 'package:oronbox/src/features/devices/services/xiaomi_sync_preferences.dart';
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
  bool _autoSync = false;

  @override
  void initState() {
    super.initState();
    _autoSync = XiaomiSyncPreferences.healthAutoSync;
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
      unawaited(updateHealthStatusSurface(healthStatusSurfaceData(data)));
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
      final result = await XiaomiAutomaticSyncService(
        ref.read(deviceManagerProvider.notifier),
      ).runHealthSync();
      unawaited(
        updateHealthStatusSurface(healthStatusSurfaceData(result.data)),
      );
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
                SegmentedTile.switchTile(
                  title: Text(l10n.deviceHealthAutoSyncTitle),
                  description: Text(l10n.deviceHealthAutoSyncDescription),
                  initialValue: _autoSync,
                  onToggle: (value) {
                    final enabled = value ?? false;
                    setState(() => _autoSync = enabled);
                    unawaited(XiaomiSyncPreferences.setHealthAutoSync(enabled));
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
    final l10n = AppLocalizations.of(context)!;
    final value = data ?? const XiaomiHealthData();
    final cards = <Widget>[
      ActivityOverviewCard(
        summary: value.activitySummary,
        onPressed: () => _openDetail(XiaomiHealthMetric.activity),
      ),
    ];
    final capabilities = value.capabilities;
    final restingDay = _latestDaily(value.daily, (day) => day.restingHeartRate);
    if (capabilities.heartRate || restingDay != null) {
      cards.add(
        _metricCard(
          data: value,
          metric: XiaomiHealthMetric.heartRate,
          title: l10n.deviceHealthHeartRate,
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
    if (restingDay != null) {
      cards.add(
        HealthDailyMetricCard(
          title: l10n.deviceHealthRestingHeartRate,
          icon: Icons.favorite_border,
          color: Colors.pinkAccent,
          value: '${restingDay.restingHeartRate} bpm',
          detail: _formatDateOnly(restingDay.date),
          days: value.daily,
          valueFor: (day) => day.restingHeartRate,
          onPressed: () => _openDetail(XiaomiHealthMetric.restingHeartRate),
        ),
      );
    }
    final heartHealthRecords = _abnormalRecords(value, const {
      HealthAbnormalHealthKind.highHeartRate,
      HealthAbnormalHealthKind.lowHeartRate,
      HealthAbnormalHealthKind.irregularHeartbeat,
    });
    if (heartHealthRecords.isNotEmpty) {
      cards.add(
        HealthAbnormalHealthCard(
          title: l10n.deviceHealthHeartHealthMonitoring,
          records: heartHealthRecords,
          labelFor: (record) => _abnormalLabel(l10n, record),
          valueFor: (record) => _abnormalValue(l10n, record),
          recordLabel: l10n.deviceHealthRecordCount,
          onPressed: () => _openDetail(XiaomiHealthMetric.heartRate),
        ),
      );
    }
    if (capabilities.bloodOxygen) {
      cards.add(
        _metricCard(
          data: value,
          metric: XiaomiHealthMetric.bloodOxygen,
          title: l10n.deviceHealthBloodOxygen,
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
    final lowBloodOxygenRecords = _abnormalRecords(value, const {
      HealthAbnormalHealthKind.lowBloodOxygen,
    });
    if (lowBloodOxygenRecords.isNotEmpty) {
      cards.add(
        HealthAbnormalHealthCard(
          title: l10n.deviceHealthLowBloodOxygen,
          records: lowBloodOxygenRecords,
          labelFor: (record) => _abnormalLabel(l10n, record),
          valueFor: (record) => _abnormalValue(l10n, record),
          recordLabel: l10n.deviceHealthRecordCount,
          icon: Icons.bloodtype_outlined,
          color: Colors.indigo,
          onPressed: () => _openDetail(XiaomiHealthMetric.bloodOxygen),
        ),
      );
    }
    if (capabilities.stress) {
      cards.add(
        _metricCard(
          data: value,
          metric: XiaomiHealthMetric.stress,
          title: l10n.deviceHealthStress,
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
    final highStressRecords = _abnormalRecords(value, const {
      HealthAbnormalHealthKind.highStress,
    });
    if (highStressRecords.isNotEmpty) {
      cards.add(
        HealthAbnormalHealthCard(
          title: l10n.deviceHealthHighStress,
          records: highStressRecords,
          labelFor: (record) => _abnormalLabel(l10n, record),
          valueFor: (record) => _abnormalValue(l10n, record),
          recordLabel: l10n.deviceHealthRecordCount,
          icon: Icons.spa_outlined,
          color: Colors.orange,
          onPressed: () => _openDetail(XiaomiHealthMetric.stress),
        ),
      );
    }
    if (capabilities.vitality) {
      cards.add(
        _metricCard(
          data: value,
          metric: XiaomiHealthMetric.vitality,
          title: l10n.deviceHealthVitality,
          icon: Icons.bolt_outlined,
          color: Colors.amber,
          summaryValue: value.latestDay?.vitalityCurrent,
          unit: '',
          detail: l10n.deviceHealthTodayTotal,
        ),
      );
    }
    if (capabilities.sleep) {
      final sleep = value.latestSleep;
      cards.add(
        HealthSleepCard(
          title: l10n.deviceHealthSleepCard,
          icon: Icons.bedtime_outlined,
          color: Colors.deepPurple,
          summary: sleep,
          noDataLabel: l10n.deviceHealthNoData,
          onPressed: () => _openDetail(XiaomiHealthMetric.sleep),
        ),
      );
    }
    if (capabilities.workouts) {
      cards.add(
        HealthMetricCard(
          metric: XiaomiHealthMetric.workout,
          title: l10n.deviceHealthWorkout,
          icon: Icons.directions_run_outlined,
          color: Colors.teal,
          value: '${value.workouts.length}',
          detail: l10n.deviceHealthRecordCount,
          samples: const [],
          onPressed: () => _openDetail(XiaomiHealthMetric.workout),
        ),
      );
    }
    return cards;
  }

  List<HealthAbnormalHealthRecord> _abnormalRecords(
    XiaomiHealthData data,
    Set<HealthAbnormalHealthKind> kinds,
  ) => data.abnormalHealthRecords
      .where((record) => kinds.contains(record.kind))
      .toList(growable: false);

  String _abnormalLabel(
    AppLocalizations l10n,
    HealthAbnormalHealthRecord record,
  ) => switch (record.kind) {
    HealthAbnormalHealthKind.highHeartRate => l10n.deviceHealthHeartRateHigh,
    HealthAbnormalHealthKind.lowHeartRate => l10n.deviceHealthHeartRateLow,
    HealthAbnormalHealthKind.lowBloodOxygen => l10n.deviceHealthLowBloodOxygen,
    HealthAbnormalHealthKind.highStress => l10n.deviceHealthHighStress,
    HealthAbnormalHealthKind.irregularHeartbeat =>
      l10n.deviceHealthIrregularHeartbeat,
  };

  String _abnormalValue(
    AppLocalizations l10n,
    HealthAbnormalHealthRecord record,
  ) {
    final value = record.value;
    if (record.kind == HealthAbnormalHealthKind.irregularHeartbeat) {
      return l10n.deviceHealthDetected;
    }
    if (value == null) return '—';
    return switch (record.kind) {
      HealthAbnormalHealthKind.highHeartRate ||
      HealthAbnormalHealthKind.lowHeartRate => '$value bpm',
      HealthAbnormalHealthKind.lowBloodOxygen => '$value%',
      HealthAbnormalHealthKind.highStress => '$value',
      HealthAbnormalHealthKind.irregularHeartbeat => l10n.deviceHealthDetected,
    };
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
    final anchor = latest?.timestamp ?? DateTime.now();
    final chartEnd = healthHourStart(anchor).add(const Duration(hours: 1));
    final chartStart = chartEnd.subtract(const Duration(hours: 24));
    final samples =
        data
            .samplesFor(metric)
            .where(
              (sample) =>
                  sample.isUsable &&
                  !sample.timestamp.isBefore(chartStart) &&
                  sample.timestamp.isBefore(chartEnd),
            )
            .toList()
          ..sort((left, right) => left.timestamp.compareTo(right.timestamp));
    final displayedValue = latest?.value.round() ?? summaryValue;
    return HealthMetricCard(
      metric: metric,
      title: title,
      icon: icon,
      color: color,
      value: displayedValue == null ? '—' : '$displayedValue $unit'.trim(),
      detail: latest == null ? detail : _formatDateTime(latest.timestamp),
      samples: samples,
      chartStart: chartStart,
      chartEnd: chartEnd,
      onPressed: () => _openDetail(metric),
    );
  }

  String _range(int? min, int? max, String unit) {
    if (min == null && max == null) {
      return AppLocalizations.of(context)!.deviceHealthNoDetailedRange;
    }
    if (min == null || max == null) return '${min ?? max} $unit'.trim();
    return '$min–$max $unit'.trim();
  }

  HealthDailySummary? _latestDaily(
    List<HealthDailySummary> days,
    int? Function(HealthDailySummary day) valueFor,
  ) {
    final matching = days.where((day) => valueFor(day) != null).toList()
      ..sort((left, right) => left.date.compareTo(right.date));
    return matching.isEmpty ? null : matching.last;
  }

  String _healthErrorMessage(Object error) {
    if (error is UnsupportedError) {
      return AppLocalizations.of(context)!.errorUnknown;
    }
    return localizedErrorMessage(AppLocalizations.of(context)!, error);
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  return '${local.month}/${local.day} ${_formatTime(local)}';
}

String _formatDateOnly(DateTime value) {
  final local = value.toLocal();
  return '${local.year}/${local.month}/${local.day}';
}

String _formatTime(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
