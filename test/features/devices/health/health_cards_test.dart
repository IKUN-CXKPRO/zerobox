import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/features/devices/health/health_cards.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';

void main() {
  test('treats zero stress as a missing measurement', () {
    final timestamp = DateTime(2026, 8, 22, 9);
    expect(
      HealthSample(
        timestamp: timestamp,
        metric: XiaomiHealthMetric.stress,
        value: 0,
      ).isUsable,
      isFalse,
    );
    expect(
      HealthSample(
        timestamp: timestamp,
        metric: XiaomiHealthMetric.stress,
        value: 51,
      ).isUsable,
      isTrue,
    );
  });

  test('aggregates the latest 24 hours into fixed hourly ranges', () {
    final start = DateTime(2026, 8, 21, 9);
    final ranges = aggregateHealthHourlyRanges(
      [
        HealthSample(
          timestamp: start.add(const Duration(minutes: 5)),
          metric: XiaomiHealthMetric.heartRate,
          value: 70,
        ),
        HealthSample(
          timestamp: start.add(const Duration(minutes: 45)),
          metric: XiaomiHealthMetric.heartRate,
          value: 96,
        ),
        HealthSample(
          timestamp: start.add(const Duration(hours: 23, minutes: 30)),
          metric: XiaomiHealthMetric.heartRate,
          value: 64,
        ),
      ],
      start: start,
      end: start.add(const Duration(hours: 24)),
    );

    expect(ranges, hasLength(24));
    expect(ranges.first?.minimum, 70);
    expect(ranges.first?.maximum, 96);
    expect(ranges[1], isNull);
    expect(ranges.last?.minimum, 64);
    expect(ranges.last?.maximum, 64);
  });

  testWidgets('phone layout keeps cards in one readable column', (
    tester,
  ) async {
    const keys = [Key('activity'), Key('first'), Key('second'), Key('third')];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 328,
              child: AdaptiveHealthCardWrap(
                children: [
                  SizedBox(key: keys[0], height: 20),
                  SizedBox(key: keys[1], height: 20),
                  SizedBox(key: keys[2], height: 20),
                  SizedBox(key: keys[3], height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final activity = tester.getRect(find.byKey(keys[0]));
    final first = tester.getRect(find.byKey(keys[1]));
    final second = tester.getRect(find.byKey(keys[2]));
    final third = tester.getRect(find.byKey(keys[3]));
    expect(activity.width, 328);
    expect(first.width, 328);
    expect(second.width, 328);
    expect(third.width, 328);
    expect(first.top, greaterThan(activity.top));
    expect(second.top, greaterThan(first.top));
    expect(third.top, greaterThan(second.top));
  });

  testWidgets('activity values are distributed around the card width', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 328,
            child: ActivityOverviewCard(summary: null, onPressed: () {}),
          ),
        ),
      ),
    );

    final labels = [
      '消耗',
      '步数',
      '站立',
    ].map((label) => tester.getCenter(find.text(label)).dx).toList();
    expect(labels[1] - labels[0], closeTo(labels[2] - labels[1], 2));
  });
}
