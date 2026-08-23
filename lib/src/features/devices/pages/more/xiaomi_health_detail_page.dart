import 'package:flutter/material.dart';
import 'package:segmented_list/segmented_list.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/features/devices/health/health_cards.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';

class XiaomiHealthDetailArgs {
  const XiaomiHealthDetailArgs({required this.metric, required this.data});

  final XiaomiHealthMetric metric;
  final XiaomiHealthData data;
}

class XiaomiHealthDetailPage extends StatelessWidget {
  const XiaomiHealthDetailPage({super.key, required this.args});

  final XiaomiHealthDetailArgs args;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text(_title(l10n, args.metric)),
      ),
      body: SegmentedList(
        maxWidth: StyleConstants.pageMaxWidth,
        contentPadding: const EdgeInsets.only(top: 8, bottom: 24),
        sections: _sections(context),
      ),
    );
  }

  List<AbstractSegmentedSection> _sections(BuildContext context) {
    final content = switch (args.metric) {
      XiaomiHealthMetric.activity => _activity(context),
      XiaomiHealthMetric.activeCalories => _activity(context),
      XiaomiHealthMetric.heartRate => _series(context),
      XiaomiHealthMetric.bloodOxygen => _series(context),
      XiaomiHealthMetric.stress => _series(context),
      XiaomiHealthMetric.vitality => _vitality(context),
      XiaomiHealthMetric.sleep => _sleep(context),
      XiaomiHealthMetric.workout => _workouts(context),
    };
    return [
      CustomSegmentedSection(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: content,
        ),
      ),
    ];
  }

  Widget _activity(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final days = args.data.daily;
    return Column(
      children: [
        _DetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.deviceHealthActivityTrend,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _Stat(
                    label: l10n.deviceHealthActiveCalories,
                    value: _latest(
                      (day) => day.activeCalories ?? day.calories,
                      'kcal',
                    ),
                  ),
                  _Stat(
                    label: l10n.deviceHealthSteps,
                    value: _latest((day) => day.steps, ''),
                  ),
                  _Stat(
                    label: l10n.deviceHealthStanding,
                    value: _latest((day) => day.standingHours, 'h'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final day in days) ...[
          _DetailCard(
            child: Row(
              children: [
                Expanded(child: Text(_date(day.date))),
                Text(l10n.deviceHealthStepValue(day.steps ?? '—')),
                const SizedBox(width: 16),
                Text('${day.activeCalories ?? day.calories ?? '—'} kcal'),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _series(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final latestSample = args.data.latestSample(args.metric);
    final anchor = latestSample?.timestamp ?? DateTime.now();
    final chartEnd = healthHourStart(anchor).add(const Duration(hours: 1));
    final chartStart = chartEnd.subtract(const Duration(hours: 24));
    final samples =
        args.data
            .samplesFor(args.metric)
            .where(
              (sample) =>
                  sample.isUsable &&
                  !sample.timestamp.isBefore(chartStart) &&
                  sample.timestamp.isBefore(chartEnd),
            )
            .toList()
          ..sort((left, right) => left.timestamp.compareTo(right.timestamp));
    final color = _color(args.metric);
    final summary = args.data.latestDay;
    final summaryLatest = switch (args.metric) {
      XiaomiHealthMetric.heartRate => summary?.averageHeartRate,
      XiaomiHealthMetric.bloodOxygen => summary?.averageBloodOxygen,
      XiaomiHealthMetric.stress => summary?.averageStress,
      _ => null,
    };
    final latest = latestSample?.value ?? summaryLatest?.toDouble();
    final values = samples.map((sample) => sample.value).toList();
    final summaryMin = switch (args.metric) {
      XiaomiHealthMetric.heartRate => summary?.minHeartRate,
      XiaomiHealthMetric.bloodOxygen => summary?.minBloodOxygen,
      XiaomiHealthMetric.stress => summary?.minStress,
      _ => null,
    };
    final summaryMax = switch (args.metric) {
      XiaomiHealthMetric.heartRate => summary?.maxHeartRate,
      XiaomiHealthMetric.bloodOxygen => summary?.maxBloodOxygen,
      XiaomiHealthMetric.stress => summary?.maxStress,
      _ => null,
    };
    final min = values.isEmpty
        ? summaryMin?.toDouble()
        : values.reduce((a, b) => a < b ? a : b);
    final max = values.isEmpty
        ? summaryMax?.toDouble()
        : values.reduce((a, b) => a > b ? a : b);
    final average = values.isEmpty
        ? summaryLatest?.toDouble()
        : values.reduce((a, b) => a + b) / values.length;
    return Column(
      children: [
        _DetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.deviceHealthTrend,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              HealthLineChart(
                metric: args.metric,
                samples: samples,
                color: color,
                start: chartStart,
                end: chartEnd,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _DetailCard(
          child: Row(
            children: [
              _Stat(label: l10n.deviceHealthLatest, value: _number(latest)),
              _Stat(label: l10n.deviceHealthAverage, value: _number(average)),
              _Stat(
                label: l10n.deviceHealthRange,
                value: '${_number(min)}–${_number(max)}',
              ),
            ],
          ),
        ),
        if (samples.isEmpty) ...[
          const SizedBox(height: 16),
          _DetailCard(child: Text(l10n.deviceHealthNoSamples)),
        ],
      ],
    );
  }

  Widget _vitality(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final day = args.data.latestDay;
    return _DetailCard(
      child: Row(
        children: [
          _Stat(
            label: l10n.deviceHealthCurrentVitality,
            value: _number(day?.vitalityCurrent),
          ),
          _Stat(
            label: l10n.deviceHealthLightIntensity,
            value: _number(day?.vitalityIncreaseLight),
          ),
          _Stat(
            label: l10n.deviceHealthModerateHighIntensity,
            value: _number(
              (day?.vitalityIncreaseModerate ?? 0) +
                  (day?.vitalityIncreaseHigh ?? 0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sleep(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (args.data.sleep.isEmpty) {
      return _DetailCard(child: Text(l10n.deviceHealthNoSleep));
    }
    final sleeps = [...args.data.sleep]
      ..sort((left, right) => right.startedAt.compareTo(left.startedAt));
    final stageLabels = <HealthSleepStageKind, String>{
      HealthSleepStageKind.awake: l10n.deviceHealthSleepAwake,
      HealthSleepStageKind.rem: l10n.deviceHealthSleepRem,
      HealthSleepStageKind.light: l10n.deviceHealthSleepLight,
      HealthSleepStageKind.deep: l10n.deviceHealthSleepDeep,
    };
    return Column(
      children: [
        for (final (index, sleep) in sleeps.indexed) ...[
          _DetailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bedtime_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        index == 0
                            ? l10n.deviceHealthLatest
                            : _date(sleep.startedAt),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(_duration(sleep.durationSeconds)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${_sleepDateTime(sleep.startedAt)} – '
                  '${_sleepDateTime(sleep.endedAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (index == 0) ...[
                  const SizedBox(height: 16),
                  Text(
                    l10n.deviceHealthSleepStages,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 10),
                  if (sleep.stages.isEmpty)
                    Text(l10n.deviceHealthSleepNoStages)
                  else
                    HealthSleepTimeline(
                      summary: sleep,
                      stageLabels: stageLabels,
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _workouts(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (args.data.workouts.isEmpty) {
      return _DetailCard(child: Text(l10n.deviceHealthNoWorkouts));
    }
    return Column(
      children: [
        for (final workout in args.data.workouts) ...[
          _DetailCard(
            child: Row(
              children: [
                const Icon(Icons.directions_run_outlined),
                const SizedBox(width: 12),
                Expanded(child: Text(_date(workout.startedAt))),
                Text(
                  _duration(
                    workout.endedAt.difference(workout.startedAt).inSeconds,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  String _latest(int? Function(HealthDailySummary day) value, String unit) {
    final latest = args.data.activitySummary;
    final result = latest == null ? null : value(latest);
    return result == null ? '—' : '$result $unit'.trim();
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

String _title(AppLocalizations l10n, XiaomiHealthMetric metric) =>
    switch (metric) {
      XiaomiHealthMetric.activity => l10n.deviceHealthActivityOverview,
      XiaomiHealthMetric.activeCalories => l10n.deviceHealthActivityOverview,
      XiaomiHealthMetric.heartRate => l10n.deviceHealthHeartRate,
      XiaomiHealthMetric.bloodOxygen => l10n.deviceHealthBloodOxygen,
      XiaomiHealthMetric.stress => l10n.deviceHealthStress,
      XiaomiHealthMetric.vitality => l10n.deviceHealthVitality,
      XiaomiHealthMetric.sleep => l10n.deviceHealthSleep,
      XiaomiHealthMetric.workout => l10n.deviceHealthWorkout,
    };

Color _color(XiaomiHealthMetric metric) => switch (metric) {
  XiaomiHealthMetric.heartRate => Colors.redAccent,
  XiaomiHealthMetric.bloodOxygen => Colors.indigo,
  XiaomiHealthMetric.stress => Colors.orange,
  _ => Colors.teal,
};

String _number(num? value) => value == null ? '—' : value.round().toString();
String _date(DateTime value) {
  final local = value.toLocal();
  return '${local.year}/${local.month}/${local.day}';
}

String _sleepDateTime(DateTime value) {
  final local = value.toLocal();
  return '${_date(local)} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _duration(int seconds) =>
    '${seconds ~/ 3600}h ${((seconds % 3600) ~/ 60).toString().padLeft(2, '0')}m';
