import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';

class AdaptiveHealthCardWrap extends StatelessWidget {
  const AdaptiveHealthCardWrap({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 16.0;
        const minCardWidth = 260.0;
        final width = constraints.maxWidth;
        final columnCount = ((width + gap) / (minCardWidth + gap))
            .floor()
            .clamp(1, 4);
        final cardWidth = (width - (columnCount - 1) * gap) / columnCount;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children)
              SizedBox(width: cardWidth, child: child),
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
          Text('活动概览', style: theme.textTheme.titleMedium),
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
            children: [
              _ActivityValue(
                label: '消耗',
                value: calories == null ? '—' : '$calories kcal',
                color: colors.primary,
              ),
              _ActivityValue(
                label: '步数',
                value: steps == null ? '—' : '$steps',
                color: colors.tertiary,
              ),
              _ActivityValue(
                label: '站立',
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
                samples: samples,
                color: color,
                gridColor: theme.colorScheme.outlineVariant,
                start: chartStart,
                end: chartEnd,
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
    required this.samples,
    required this.color,
    this.height = 220,
    this.start,
    this.end,
    super.key,
  });

  final List<HealthSample> samples;
  final Color color;
  final double height;
  final DateTime? start;
  final DateTime? end;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _HealthSparklinePainter(
          samples: samples,
          color: color,
          gridColor: theme.colorScheme.outlineVariant,
          start: start,
          end: end,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.child, required this.onPressed});

  final Widget child;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 214,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(padding: const EdgeInsets.all(18), child: child),
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
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
      ),
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
      oldDelegate.progress != progress || oldDelegate.colors != colors;
}

class _HealthSparklinePainter extends CustomPainter {
  _HealthSparklinePainter({
    required this.samples,
    required this.color,
    required this.gridColor,
    this.start,
    this.end,
  });

  final List<HealthSample> samples;
  final Color color;
  final Color gridColor;
  final DateTime? start;
  final DateTime? end;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = gridColor.withValues(alpha: .45)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      grid,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      grid,
    );
    final valid = samples.where((sample) => sample.isUsable).toList()
      ..sort((left, right) => left.timestamp.compareTo(right.timestamp));
    if (valid.isEmpty) return;
    final values = valid.map((sample) => sample.value).toList();
    final min = values.reduce(math.min);
    final max = values.reduce(math.max);
    final range = max - min;
    final hasTimeSpan = valid.last.timestamp.isAfter(valid.first.timestamp);
    final firstTimestamp =
        start ??
        (hasTimeSpan
            ? valid.first.timestamp
            : valid.first.timestamp.subtract(const Duration(hours: 1)));
    final lastTimestamp =
        end ??
        (hasTimeSpan
            ? valid.last.timestamp
            : valid.first.timestamp.add(const Duration(hours: 1)));
    final span = math.max(
      1,
      lastTimestamp.millisecondsSinceEpoch -
          firstTimestamp.millisecondsSinceEpoch,
    );
    final points = <Offset>[];
    for (var index = 0; index < values.length; index++) {
      final timestamp = valid[index].timestamp.millisecondsSinceEpoch;
      final x =
          size.width *
          ((timestamp - firstTimestamp.millisecondsSinceEpoch) / span).clamp(
            0.0,
            1.0,
          );
      final normalized = range == 0 ? .5 : (values[index] - min) / range;
      final y = size.height - normalized * size.height;
      points.add(Offset(x, y));
    }
    if (points.length == 1) {
      canvas.drawCircle(points.single, 4, Paint()..color = color);
      return;
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length; index++) {
      path.lineTo(points[index].dx, points[index].dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _HealthSparklinePainter oldDelegate) =>
      oldDelegate.samples != samples ||
      oldDelegate.color != color ||
      oldDelegate.start != start ||
      oldDelegate.end != end;
}
