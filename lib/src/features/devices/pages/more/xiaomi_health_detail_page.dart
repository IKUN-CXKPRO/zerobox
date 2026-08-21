import 'package:flutter/material.dart';
import 'package:segmented_list/segmented_list.dart';
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
    return Scaffold(
      appBar: SysAppBar(secondary: true, title: Text(_title(args.metric))),
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
    final days = args.data.daily;
    return Column(
      children: [
        _DetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('活动趋势', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              Row(
                children: [
                  _Stat(
                    label: '消耗',
                    value: _latest(
                      (day) => day.activeCalories ?? day.calories,
                      'kcal',
                    ),
                  ),
                  _Stat(label: '步数', value: _latest((day) => day.steps, '')),
                  _Stat(
                    label: '站立',
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
                Text('${day.steps ?? '—'} 步'),
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
    final samples =
        args.data
            .samplesFor(args.metric)
            .where((sample) => sample.isUsable)
            .toList()
          ..sort((left, right) => left.timestamp.compareTo(right.timestamp));
    final color = _color(args.metric);
    final latest = args.data.latestSample(args.metric)?.value;
    final values = samples.map((sample) => sample.value).toList();
    final min = values.isEmpty ? null : values.reduce((a, b) => a < b ? a : b);
    final max = values.isEmpty ? null : values.reduce((a, b) => a > b ? a : b);
    final average = values.isEmpty
        ? null
        : values.reduce((a, b) => a + b) / values.length;
    return Column(
      children: [
        _DetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('趋势', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              HealthLineChart(samples: samples, color: color),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _DetailCard(
          child: Row(
            children: [
              _Stat(label: '最新', value: _number(latest)),
              _Stat(label: '平均', value: _number(average)),
              _Stat(label: '范围', value: '${_number(min)}–${_number(max)}'),
            ],
          ),
        ),
        if (samples.isEmpty) ...[
          const SizedBox(height: 16),
          _DetailCard(child: const Text('暂无详细采样数据')),
        ],
      ],
    );
  }

  Widget _vitality(BuildContext context) {
    final day = args.data.latestDay;
    return _DetailCard(
      child: Row(
        children: [
          _Stat(label: '当前元气值', value: _number(day?.vitalityCurrent)),
          _Stat(label: '低强度', value: _number(day?.vitalityIncreaseLight)),
          _Stat(
            label: '中高强度',
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
    if (args.data.sleep.isEmpty) {
      return _DetailCard(child: const Text('暂无睡眠数据'));
    }
    return Column(
      children: [
        for (final sleep in args.data.sleep) ...[
          _DetailCard(
            child: Row(
              children: [
                const Icon(Icons.bedtime_outlined),
                const SizedBox(width: 12),
                Expanded(child: Text(_date(sleep.startedAt))),
                Text(_duration(sleep.durationSeconds)),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _workouts(BuildContext context) {
    if (args.data.workouts.isEmpty) {
      return _DetailCard(child: const Text('暂无运动记录'));
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

String _title(XiaomiHealthMetric metric) => switch (metric) {
  XiaomiHealthMetric.activity => '活动概览',
  XiaomiHealthMetric.activeCalories => '活动概览',
  XiaomiHealthMetric.heartRate => '心率',
  XiaomiHealthMetric.bloodOxygen => '血氧',
  XiaomiHealthMetric.stress => '压力',
  XiaomiHealthMetric.vitality => '元气值',
  XiaomiHealthMetric.sleep => '睡眠',
  XiaomiHealthMetric.workout => '运动记录',
};

Color _color(XiaomiHealthMetric metric) => switch (metric) {
  XiaomiHealthMetric.heartRate => Colors.redAccent,
  XiaomiHealthMetric.bloodOxygen => Colors.indigo,
  XiaomiHealthMetric.stress => Colors.orange,
  _ => Colors.teal,
};

String _number(num? value) => value == null ? '—' : value.round().toString();
String _date(DateTime value) => '${value.year}/${value.month}/${value.day}';
String _duration(int seconds) =>
    '${seconds ~/ 3600}h ${((seconds % 3600) ~/ 60).toString().padLeft(2, '0')}m';
