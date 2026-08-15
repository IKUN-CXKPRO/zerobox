import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/device/xiaomi/components/health_system.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';
import 'package:oronbox/src/features/devices/health/health_store.dart';

/// Xiaomi VelaOS health adapter for the first sync slice.
///
/// It fetches non-destructive daily and sleep summaries, commits the merged
/// result to the local store, and only then reports success to its caller.
class XiaomiHealthSyncService {
  factory XiaomiHealthSyncService({
    required XiaomiHealthSystem system,
    required String deviceId,
    HealthStore? store,
  }) => XiaomiHealthSyncService._(
    system: system,
    deviceId: deviceId,
    store: store,
  );

  XiaomiHealthSyncService._({
    required this._system,
    required this._deviceId,
    HealthStore? store,
  }) : _store = store ?? HealthStore(),
       _log = getLogger('XiaomiHealthSyncService');

  final XiaomiHealthSystem _system;
  final String _deviceId;
  final HealthStore _store;
  final Logger _log;

  Future<XiaomiHealthData> read() => _store.read(_deviceId);

  Future<XiaomiHealthSyncResult> sync() async {
    final previous = await _store.read(_deviceId);
    HealthDailySummary? daily;
    List<HealthSleepSummary>? sleep;
    String? warning;

    try {
      final basic = await _system.fetchBasicData();
      final now = DateTime.now();
      final date = DateTime(now.year, now.month, now.day);
      final previousDay = previous.daily
          .where((value) => _sameDay(value.date, date))
          .firstOrNull;
      final hasDailyValue =
          basic.hasSteps() ||
          basic.hasCalories() ||
          basic.hasDistance() ||
          basic.hasHeartRate() ||
          basic.hasIntensity() ||
          basic.hasValidStand();
      if (hasDailyValue) {
        daily = HealthDailySummary(
          date: date,
          steps: basic.hasSteps() ? basic.steps : previousDay?.steps ?? 0,
          calories: basic.hasCalories()
              ? basic.calories
              : previousDay?.calories ?? 0,
          distanceMeters: basic.hasDistance()
              ? basic.distance
              : previousDay?.distanceMeters ?? 0,
          heartRate: basic.hasHeartRate()
              ? basic.heartRate
              : previousDay?.heartRate ?? 0,
          intensity: basic.hasIntensity()
              ? basic.intensity
              : previousDay?.intensity ?? 0,
          validStand: basic.hasValidStand()
              ? basic.validStand
              : previousDay?.validStand,
        );
      } else {
        warning = 'daily:empty';
      }
    } catch (error, stackTrace) {
      _log.warning(
        'daily health sync failed for $_deviceId',
        error,
        stackTrace,
      );
      warning = 'daily:$error';
    }

    try {
      final result = await _system.fetchSleepResult();
      final parsedSleep = result.sectionList
          .where(
            (section) =>
                section.hasSleepTimestamp() && section.hasWakeupTimestamp(),
          )
          .map(
            (section) => HealthSleepSummary(
              startedAt: _timestamp(section.sleepTimestamp),
              endedAt: _timestamp(section.wakeupTimestamp),
              durationSeconds: section.hasValidSleepTime()
                  ? section.validSleepTime * 60
                  : section.wakeupTimestamp - section.sleepTimestamp,
              averageHeartRate: section.hasAverageHeartRate()
                  ? section.averageHeartRate
                  : null,
              averageBloodOxygen: section.hasAverageBloodOxygen()
                  ? section.averageBloodOxygen
                  : null,
              quality:
                  section.hasExtraData() && section.extraData.hasSleepQuality()
                  ? section.extraData.sleepQuality
                  : null,
            ),
          )
          .toList(growable: false);
      if (parsedSleep.isEmpty) {
        warning = warning == null ? 'sleep:empty' : '$warning;sleep:empty';
      } else {
        sleep = parsedSleep;
      }
    } catch (error, stackTrace) {
      _log.warning(
        'sleep health sync failed for $_deviceId',
        error,
        stackTrace,
      );
      warning = warning == null ? 'sleep:$error' : '$warning;sleep:$error';
    }

    if (daily == null && sleep == null) {
      throw StateError(warning ?? 'Health synchronization failed');
    }

    final merged = XiaomiHealthData(
      daily: [...previous.daily, if (daily != null) daily],
      sleep: [...previous.sleep, if (sleep != null) ...sleep],
      lastSyncedAt: DateTime.now(),
    );
    await _store.write(_deviceId, merged);
    final saved = await _store.read(_deviceId);
    return XiaomiHealthSyncResult(
      data: saved,
      updatedDaily: daily != null,
      updatedSleep: sleep != null,
      warning: warning,
    );
  }

  DateTime _timestamp(int value) {
    // Xiaomi timestamps are seconds. Values outside the normal epoch range
    // are left as milliseconds for firmware variants that use milliseconds.
    return DateTime.fromMillisecondsSinceEpoch(
      value > 100000000000 ? value : value * 1000,
    );
  }

  bool _sameDay(DateTime? left, DateTime right) =>
      left != null &&
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}
