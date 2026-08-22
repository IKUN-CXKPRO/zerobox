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
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_chartTime(start, '00:00'), style: theme.textTheme.bodySmall),
            Text(_chartEndTime(), style: theme.textTheme.bodySmall),
          ],
        ),
      ],
    );
  }

  String _chartTime(DateTime? value, String fallback) {
    if (value == null) return fallback;
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  String _chartEndTime() {
    return _chartTime(end, '24:00');
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
    final axis = _stableAxis(metric);
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
        final normalized = ((value - axis.$1) / (axis.$2 - axis.$1)).clamp(
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

(double, double) _stableAxis(XiaomiHealthMetric metric) => switch (metric) {
  XiaomiHealthMetric.heartRate => (30, 220),
  XiaomiHealthMetric.bloodOxygen => (50, 100),
  XiaomiHealthMetric.stress => (0, 100),
  XiaomiHealthMetric.vitality => (0, 100),
  XiaomiHealthMetric.activity => (0, 1000),
  XiaomiHealthMetric.activeCalories => (0, 100),
  XiaomiHealthMetric.sleep || XiaomiHealthMetric.workout => (0, 100),
};

DateTime _nextHour(DateTime value) => DateTime(
  value.year,
  value.month,
  value.day,
  value.hour,
).add(const Duration(hours: 1));
