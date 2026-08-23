import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';

class AdaptiveHealthCardWrap extends StatelessWidget {
  const AdaptiveHealthCardWrap({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        const minCardWidth = 260.0;
        final width = constraints.maxWidth;
        final columnCount = ((width + gap) / (minCardWidth + gap))
            .floor()
            .clamp(1, 4);
        final cardWidth = (width - (columnCount - 1) * gap) / columnCount;
        final fullWidthActivity = width < 600 && columnCount > 1;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (index, child) in children.indexed)
              SizedBox(
                width: index == 0 && fullWidthActivity ? width : cardWidth,
                child: child,
              ),
          ],
        );
      },
    );
  }
}

class ActivityOverviewCard extends StatelessWidget {
  const ActivityOverviewCard({
    required this.summary,
    required this.onPressed,
    super.key,
  });

  final HealthDailySummary? summary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final colors = theme.colorScheme;
    final value = summary;
    final steps = value?.steps;
    final calories = value?.activeCalories ?? value?.calories;
    final standing = value?.standingHours;
    return _HealthCard(
      onPressed: onPressed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.deviceHealthActivityOverview,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Expanded(
            child: CustomPaint(
              painter: _ActivityRingsPainter(
                trackColor: colors.outlineVariant,
                colors: [colors.primary, colors.tertiary, colors.secondary],
                progress: [
                  _progress(calories, 500),
                  _progress(steps, 10000),
                  _progress(standing, 12),
                ],
              ),
              child: const SizedBox.expand(),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ActivityValue(
                label: l10n.deviceHealthActiveCalories,
                value: calories == null ? '—' : '$calories kcal',
                color: colors.primary,
              ),
              _ActivityValue(
                label: l10n.deviceHealthSteps,
                value: steps == null ? '—' : '$steps',
                color: colors.tertiary,
              ),
              _ActivityValue(
                label: l10n.deviceHealthStanding,
                value: standing == null ? '—' : '$standing h',
                color: colors.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _progress(int? value, int target) =>
      value == null ? 0 : (value / target).clamp(0.0, 1.0);
}

class HealthMetricCard extends StatelessWidget {
  const HealthMetricCard({
    required this.metric,
    required this.title,
    required this.icon,
    required this.color,
    required this.value,
    required this.detail,
    required this.samples,
    required this.onPressed,
    this.chartStart,
    this.chartEnd,
    super.key,
  });

  final XiaomiHealthMetric metric;
  final String title;
  final IconData icon;
  final Color color;
  final String value;
  final String detail;
  final List<HealthSample> samples;
  final VoidCallback onPressed;
  final DateTime? chartStart;
  final DateTime? chartEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _HealthCard(
      onPressed: onPressed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              Icon(Icons.chevron_right, color: theme.hintColor),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 2),
          Text(detail, style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HealthYAxis(metric: metric, compact: true),
                      const SizedBox(width: 4),
                      Expanded(
                        child: CustomPaint(
                          painter: _HealthSparklinePainter(
                            metric: metric,
                            samples: samples,
                            color: color,
                            gridColor: theme.colorScheme.outlineVariant,
                            start: chartStart,
                            end: chartEnd,
                            showGrid: false,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                _HealthXAxis(start: chartStart, end: chartEnd, compact: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HealthSleepCard extends StatelessWidget {
  const HealthSleepCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.summary,
    required this.noDataLabel,
    required this.onPressed,
    super.key,
  });

  final String title;
  final IconData icon;
  final Color color;
  final HealthSleepSummary? summary;
  final String noDataLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sleep = summary;
    return _HealthCard(
      onPressed: onPressed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              Icon(Icons.chevron_right, color: theme.hintColor),
            ],
          ),
          const Spacer(),
          Text(
            sleep == null ? '—' : _formatSleepDuration(sleep.durationSeconds),
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            sleep == null
                ? noDataLabel
                : '${_formatSleepTime(sleep.startedAt)} – '
                      '${_formatSleepTime(sleep.endedAt)}',
            style: theme.textTheme.bodyMedium,
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class HealthSleepTimeline extends StatelessWidget {
  const HealthSleepTimeline({
    required this.summary,
    required this.stageLabels,
    super.key,
  });

  final HealthSleepSummary summary;
  final Map<HealthSleepStageKind, String> stageLabels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = <HealthSleepStageKind, Color>{
      HealthSleepStageKind.awake: Colors.orange,
      HealthSleepStageKind.rem: Colors.teal,
      HealthSleepStageKind.light: Colors.lightBlue,
      HealthSleepStageKind.deep: Colors.indigo,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 150,
          child: CustomPaint(
            painter: _SleepTimelinePainter(
              start: summary.startedAt,
              end: summary.endedAt,
              stages: summary.stages,
              colors: colors,
              labels: stageLabels,
              labelColor:
                  theme.textTheme.bodySmall?.color ??
                  theme.colorScheme.onSurfaceVariant,
              gridColor: theme.colorScheme.outlineVariant,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 6),
        _HealthXAxis(start: summary.startedAt, end: summary.endedAt),
      ],
    );
  }
}

class HealthLineChart extends StatelessWidget {
  const HealthLineChart({
    required this.metric,
    required this.samples,
    required this.color,
    this.height = 220,
    this.start,
    this.end,
    super.key,
  });

  final List<HealthSample> samples;
  final XiaomiHealthMetric metric;
  final Color color;
  final double height;
  final DateTime? start;
  final DateTime? end;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HealthYAxis(metric: metric),
              const SizedBox(width: 8),
              Expanded(
                child: CustomPaint(
                  painter: _HealthSparklinePainter(
                    metric: metric,
                    samples: samples,
                    color: color,
                    gridColor: theme.colorScheme.outlineVariant,
                    start: start,
                    end: end,
                    showGrid: true,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        _HealthXAxis(start: start, end: end),
      ],
    );
  }
}

class _HealthYAxis extends StatelessWidget {
  const _HealthYAxis({required this.metric, this.compact = false});

  final XiaomiHealthMetric metric;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final axis = _healthAxis(metric);
    final style =
        (compact ? theme.textTheme.labelSmall : theme.textTheme.bodySmall)
            ?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: compact ? 9 : null,
            );
    return SizedBox(
      width: compact ? 42 : 52,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(axis.format(axis.maximum), style: style),
          Text(axis.format(axis.middle), style: style),
          Text(axis.format(axis.minimum), style: style),
        ],
      ),
    );
  }
}

class _HealthXAxis extends StatelessWidget {
  const _HealthXAxis({
    required this.start,
    required this.end,
    this.compact = false,
  });

  final DateTime? start;
  final DateTime? end;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedEnd = end ?? _nextHour(DateTime.now());
    final resolvedStart =
        start ?? resolvedEnd.subtract(const Duration(hours: 24));
    final middle = resolvedStart.add(
      Duration(
        milliseconds:
            (resolvedEnd.millisecondsSinceEpoch -
                resolvedStart.millisecondsSinceEpoch) ~/
            2,
      ),
    );
    final style =
        (compact ? theme.textTheme.labelSmall : theme.textTheme.bodySmall)
            ?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: compact ? 9 : null,
            );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(_formatChartTime(resolvedStart), style: style),
        Text(_formatChartTime(middle), style: style),
        Text(_formatChartTime(resolvedEnd), style: style),
      ],
    );
  }
}

class _HealthAxis {
  const _HealthAxis({
    required this.minimum,
    required this.maximum,
    this.unit = '',
  });

  final double minimum;
  final double maximum;
  final String unit;

  double get middle => (minimum + maximum) / 2;

  String format(double value) {
    final number = value == value.roundToDouble()
        ? value.round().toString()
        : value.toStringAsFixed(1);
    return unit.isEmpty ? number : '$number $unit';
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.child, required this.onPressed});

  final Widget child;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        height: 214,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Padding(
              padding: EdgeInsets.all(constraints.maxWidth < 190 ? 12 : 18),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityValue extends StatelessWidget {
  const _ActivityValue({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(label, style: textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: textTheme.labelLarge),
      ],
    );
  }
}

class _ActivityRingsPainter extends CustomPainter {
  _ActivityRingsPainter({
    required this.trackColor,
    required this.colors,
    required this.progress,
  });

  final Color trackColor;
  final List<Color> colors;
  final List<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .78);
    final radius = math.min(size.width * .34, size.height * .8);
    for (var index = 0; index < 3; index++) {
      final currentRadius = radius - index * 16;
      final track = Paint()
        ..color = trackColor.withValues(alpha: .55)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 10;
      final value = Paint()
        ..color = colors[index]
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 10;
      final rect = Rect.fromCircle(center: center, radius: currentRadius);
      canvas.drawArc(rect, math.pi, math.pi, false, track);
      canvas.drawArc(rect, math.pi, math.pi * progress[index], false, value);
    }
  }

  @override
  bool shouldRepaint(covariant _ActivityRingsPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.colors != colors ||
      oldDelegate.trackColor != trackColor;
}

class _SleepTimelinePainter extends CustomPainter {
  _SleepTimelinePainter({
    required this.start,
    required this.end,
    required this.stages,
    required this.colors,
    required this.labels,
    required this.labelColor,
    required this.gridColor,
  });

  final DateTime start;
  final DateTime end;
  final List<HealthSleepStageSegment> stages;
  final Map<HealthSleepStageKind, Color> colors;
  final Map<HealthSleepStageKind, String> labels;
  final Color labelColor;
  final Color gridColor;

  static const _kinds = [
    HealthSleepStageKind.awake,
    HealthSleepStageKind.rem,
    HealthSleepStageKind.light,
    HealthSleepStageKind.deep,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final plotLeft = 58.0;
    final plotWidth = math.max(1.0, size.width - plotLeft);
    final laneHeight = 24.0;
    final laneGap = 7.0;
    final plotTop = 5.0;
    final span = end.millisecondsSinceEpoch - start.millisecondsSinceEpoch;
    if (span <= 0) return;

    final textStyle = TextStyle(color: labelColor, fontSize: 11);
    final grid = Paint()
      ..color = gridColor.withValues(alpha: .2)
      ..strokeWidth = 1;
    for (var index = 0; index <= 4; index++) {
      final x = plotLeft + plotWidth * index / 4;
      canvas.drawLine(Offset(x, plotTop), Offset(x, size.height), grid);
    }

    for (var index = 0; index < _kinds.length; index++) {
      final kind = _kinds[index];
      final top = plotTop + index * (laneHeight + laneGap);
      final track = Paint()
        ..color = gridColor.withValues(alpha: .1)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(plotLeft, top, plotWidth, laneHeight),
          const Radius.circular(8),
        ),
        track,
      );
      _drawLabel(
        canvas,
        labels[kind] ?? kind.name,
        textStyle,
        Offset(0, top + (laneHeight - textStyle.fontSize!) / 2 - 1),
      );
    }

    for (final stage in stages) {
      final lane = _kinds.indexOf(stage.kind);
      final color = colors[stage.kind];
      if (lane < 0 || color == null) continue;
      final from = math.max(
        0,
        stage.startedAt.millisecondsSinceEpoch - start.millisecondsSinceEpoch,
      );
      final to = math.min(
        span,
        stage.endedAt.millisecondsSinceEpoch - start.millisecondsSinceEpoch,
      );
      if (to <= from) continue;
      final left = plotLeft + plotWidth * from / span;
      final right = plotLeft + plotWidth * to / span;
      final top = plotTop + lane * (laneHeight + laneGap);
      final paint = Paint()..color = color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(left, top, math.max(left + 4, right), top + laneHeight),
          const Radius.circular(8),
        ),
        paint,
      );
    }
  }

  void _drawLabel(Canvas canvas, String text, TextStyle style, Offset offset) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 54);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _SleepTimelinePainter oldDelegate) =>
      oldDelegate.start != start ||
      oldDelegate.end != end ||
      oldDelegate.stages != stages ||
      oldDelegate.colors != colors ||
      oldDelegate.labels != labels ||
      oldDelegate.labelColor != labelColor ||
      oldDelegate.gridColor != gridColor;
}

class _HealthSparklinePainter extends CustomPainter {
  _HealthSparklinePainter({
    required this.metric,
    required this.samples,
    required this.color,
    required this.gridColor,
    required this.showGrid,
    this.start,
    this.end,
  });

  final List<HealthSample> samples;
  final XiaomiHealthMetric metric;
  final Color color;
  final Color gridColor;
  final bool showGrid;
  final DateTime? start;
  final DateTime? end;

  @override
  void paint(Canvas canvas, Size size) {
    final chartEnd = end ?? _nextHour(DateTime.now());
    final chartStart = start ?? chartEnd.subtract(const Duration(hours: 24));
    final ranges = aggregateHealthHourlyRanges(
      samples,
      start: chartStart,
      end: chartEnd,
    );
    if (showGrid) {
      final grid = Paint()
        ..color = gridColor.withValues(alpha: .45)
        ..strokeWidth = 1;
      for (final fraction in const [0.0, .5, 1.0]) {
        final y = size.height * fraction;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
      }
    }
    final axis = _healthAxis(metric);
    final plotHeight = math.max(1.0, size.height - 8);
    final trackPaint = Paint()
      ..color = gridColor.withValues(alpha: showGrid ? .3 : .18)
      ..strokeWidth = showGrid ? 10 : 7
      ..strokeCap = StrokeCap.round;
    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = showGrid ? 10 : 7
      ..strokeCap = StrokeCap.round;
    final slotWidth = size.width / 24;
    for (var index = 0; index < 24; index++) {
      final x = slotWidth * (index + .5);
      canvas.drawLine(Offset(x, 4), Offset(x, size.height - 4), trackPaint);
      final range = ranges[index];
      if (range == null) continue;
      double y(double value) {
        final normalized =
            ((value - axis.minimum) / (axis.maximum - axis.minimum)).clamp(
              0.0,
              1.0,
            );
        return 4 + plotHeight * (1 - normalized);
      }

      var top = y(range.maximum);
      var bottom = y(range.minimum);
      final minimumLength = showGrid ? 10.0 : 8.0;
      if (bottom - top < minimumLength) {
        final center = (top + bottom) / 2;
        top = center - minimumLength / 2;
        bottom = center + minimumLength / 2;
      }
      canvas.drawLine(Offset(x, top), Offset(x, bottom), valuePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HealthSparklinePainter oldDelegate) =>
      oldDelegate.samples != samples ||
      oldDelegate.metric != metric ||
      oldDelegate.color != color ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.showGrid != showGrid ||
      oldDelegate.start != start ||
      oldDelegate.end != end;
}

class HealthHourRange {
  const HealthHourRange({required this.minimum, required this.maximum});

  final double minimum;
  final double maximum;
}

List<HealthHourRange?> aggregateHealthHourlyRanges(
  Iterable<HealthSample> samples, {
  required DateTime start,
  required DateTime end,
}) {
  final buckets = List<List<double>>.generate(24, (_) => <double>[]);
  final span = end.millisecondsSinceEpoch - start.millisecondsSinceEpoch;
  if (span <= 0) return List<HealthHourRange?>.filled(24, null);
  for (final sample in samples) {
    if (!sample.isUsable ||
        sample.timestamp.isBefore(start) ||
        !sample.timestamp.isBefore(end)) {
      continue;
    }
    final elapsed =
        sample.timestamp.millisecondsSinceEpoch - start.millisecondsSinceEpoch;
    final index = (elapsed * 24 ~/ span).clamp(0, 23);
    buckets[index].add(sample.value);
  }
  return buckets
      .map((values) {
        if (values.isEmpty) return null;
        return HealthHourRange(
          minimum: values.reduce(math.min),
          maximum: values.reduce(math.max),
        );
      })
      .toList(growable: false);
}

_HealthAxis _healthAxis(XiaomiHealthMetric metric) => switch (metric) {
  XiaomiHealthMetric.heartRate => const _HealthAxis(
    minimum: 30,
    maximum: 220,
    unit: 'bpm',
  ),
  XiaomiHealthMetric.bloodOxygen => const _HealthAxis(
    minimum: 50,
    maximum: 100,
    unit: '%',
  ),
  XiaomiHealthMetric.stress => const _HealthAxis(minimum: 0, maximum: 100),
  XiaomiHealthMetric.vitality => const _HealthAxis(minimum: 0, maximum: 100),
  XiaomiHealthMetric.activity => const _HealthAxis(
    minimum: 0,
    maximum: 1000,
    unit: 'steps',
  ),
  XiaomiHealthMetric.activeCalories => const _HealthAxis(
    minimum: 0,
    maximum: 100,
    unit: 'kcal',
  ),
  XiaomiHealthMetric.sleep ||
  XiaomiHealthMetric.workout => const _HealthAxis(minimum: 0, maximum: 100),
};

DateTime healthHourStart(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day, local.hour);
}

DateTime _nextHour(DateTime value) =>
    healthHourStart(value).add(const Duration(hours: 1));

String _formatSleepTime(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _formatChartTime(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _formatSleepDuration(int seconds) =>
    '${seconds ~/ 3600}h ${((seconds % 3600) ~/ 60).toString().padLeft(2, '0')}m';
