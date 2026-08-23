import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/device/xiaomi/components/health_system.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';
import 'package:oronbox/src/features/devices/health/health_store.dart';

/// Xiaomi health synchronizer based on the activity-file protocol used by
/// Gadgetbridge. The old aggregate/basic-data fallback is intentionally not
/// part of this implementation.
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
    final files = await _system.syncActivityFiles();

    final daily = files.daily.map(_daily).toList(growable: false);
    final samples = files.samples.expand(_samples).toList(growable: false);
    final sleep = files.sleep
        .map(
          (value) => HealthSleepSummary(
            startedAt: value.startedAt,
            endedAt: value.endedAt,
            durationSeconds: value.durationSeconds,
            averageHeartRate: value.averageHeartRate,
            averageBloodOxygen: value.averageBloodOxygen,
            quality: value.quality,
            stages: _stages(value),
          ),
        )
        .toList(growable: false);
    final workouts = files.workouts
        .map(
          (value) => HealthWorkoutSummary(
            startedAt: value.startedAt,
            endedAt: value.endedAt,
            activityType: value.activityType,
            distanceMeters: value.distanceMeters,
            calories: value.calories,
          ),
        )
        .toList(growable: false);

    if (files.filesReceived == 0 &&
        daily.isEmpty &&
        samples.isEmpty &&
        sleep.isEmpty &&
        workouts.isEmpty) {
      throw StateError('No Xiaomi health activity files returned');
    }

    final data = XiaomiHealthData(
      daily: [...previous.daily, ...daily],
      samples: [...previous.samples, ...samples],
      sleep: [...previous.sleep, ...sleep],
      workouts: [...previous.workouts, ...workouts],
      capabilities: _capabilities(previous, daily, samples, sleep, workouts),
      lastSyncedAt: DateTime.now(),
    );
    await _store.write(_deviceId, data);
    final saved = await _store.read(_deviceId);

    _log.info(
      'saved Xiaomi health files for $_deviceId: '
      'files=${files.filesReceived}, daily=${daily.length}, '
      'samples=${samples.length}, sleep=${sleep.length}, '
      'workouts=${workouts.length}',
    );
    return XiaomiHealthSyncResult(
      data: saved,
      updatedDaily: daily.isNotEmpty,
      updatedSamples: samples.isNotEmpty,
      updatedSleep: sleep.isNotEmpty,
      updatedWorkouts: workouts.isNotEmpty,
    );
  }

  HealthDailySummary _daily(XiaomiActivityDailyRecord value) =>
      HealthDailySummary(
        date: _dateOnly(value.date),
        steps: value.steps,
        activeCalories: value.activeCalories,
        calories: value.calories,
        restingHeartRate: value.restingHeartRate,
        minHeartRate: value.minHeartRate,
        maxHeartRate: value.maxHeartRate,
        averageHeartRate: value.averageHeartRate,
        minStress: value.minStress,
        maxStress: value.maxStress,
        averageStress: value.averageStress,
        standingBitmap: value.standingBitmap,
        minBloodOxygen: value.minBloodOxygen,
        maxBloodOxygen: value.maxBloodOxygen,
        averageBloodOxygen: value.averageBloodOxygen,
        vitalityIncreaseLight: value.vitalityIncreaseLight,
        vitalityIncreaseModerate: value.vitalityIncreaseModerate,
        vitalityIncreaseHigh: value.vitalityIncreaseHigh,
        vitalityCurrent: value.vitalityCurrent,
      );

  Iterable<HealthSample> _samples(XiaomiActivitySampleRecord value) sync* {
    if (value.heartRate != null) {
      yield HealthSample(
        timestamp: value.timestamp,
        metric: XiaomiHealthMetric.heartRate,
        value: value.heartRate!.toDouble(),
      );
    }
    if (value.bloodOxygen != null) {
      yield HealthSample(
        timestamp: value.timestamp,
        metric: XiaomiHealthMetric.bloodOxygen,
        value: value.bloodOxygen!.toDouble(),
      );
    }
    if (value.stress != null) {
      yield HealthSample(
        timestamp: value.timestamp,
        metric: XiaomiHealthMetric.stress,
        value: value.stress!.toDouble(),
      );
    }
    if (value.steps != null) {
      yield HealthSample(
        timestamp: value.timestamp,
        metric: XiaomiHealthMetric.activity,
        value: value.steps!.toDouble(),
      );
    }
    if (value.activeCalories != null) {
      yield HealthSample(
        timestamp: value.timestamp,
        metric: XiaomiHealthMetric.activeCalories,
        value: value.activeCalories!.toDouble(),
      );
    }
  }

  XiaomiHealthCapabilities _capabilities(
    XiaomiHealthData previous,
    List<HealthDailySummary> daily,
    List<HealthSample> samples,
    List<HealthSleepSummary> sleep,
    List<HealthWorkoutSummary> workouts,
  ) {
    bool has(XiaomiHealthMetric metric) =>
        samples.any((value) => value.metric == metric);
    final latest = daily.firstOrNull;
    return XiaomiHealthCapabilities(
      heartRate:
          previous.capabilities.heartRate ||
          has(XiaomiHealthMetric.heartRate) ||
          latest?.averageHeartRate != null,
      bloodOxygen:
          previous.capabilities.bloodOxygen ||
          has(XiaomiHealthMetric.bloodOxygen) ||
          latest?.averageBloodOxygen != null,
      stress:
          previous.capabilities.stress ||
          has(XiaomiHealthMetric.stress) ||
          latest?.averageStress != null,
      vitality:
          previous.capabilities.vitality ||
          daily.any((value) => value.vitalityCurrent != null),
      sleep: previous.capabilities.sleep || sleep.isNotEmpty,
      workouts: previous.capabilities.workouts || workouts.isNotEmpty,
    );
  }

  DateTime _dateOnly(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  List<HealthSleepStageSegment> _stages(XiaomiActivitySleepRecord value) {
    final points = [...value.stages]
      ..sort((left, right) => left.timestamp.compareTo(right.timestamp));
    final result = <HealthSleepStageSegment>[];
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final startedAt = point.timestamp.isBefore(value.startedAt)
          ? value.startedAt
          : point.timestamp;
      final next = index + 1 < points.length
          ? points[index + 1].timestamp
          : value.endedAt;
      final endedAt = next.isAfter(value.endedAt) ? value.endedAt : next;
      if (!endedAt.isAfter(startedAt)) continue;
      final kind = switch (point.stage) {
        2 => HealthSleepStageKind.deep,
        3 => HealthSleepStageKind.light,
        4 => HealthSleepStageKind.rem,
        5 => HealthSleepStageKind.awake,
        _ => HealthSleepStageKind.unknown,
      };
      if (kind == HealthSleepStageKind.unknown) continue;
      if (result.isNotEmpty &&
          result.last.kind == kind &&
          result.last.endedAt == startedAt) {
        final previous = result.removeLast();
        result.add(
          HealthSleepStageSegment(
            startedAt: previous.startedAt,
            endedAt: endedAt,
            kind: kind,
          ),
        );
      } else {
        result.add(
          HealthSleepStageSegment(
            startedAt: startedAt,
            endedAt: endedAt,
            kind: kind,
          ),
        );
      }
    }
    return result;
  }
}
