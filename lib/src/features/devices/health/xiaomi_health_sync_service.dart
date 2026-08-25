import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/device/xiaomi/components/health_system.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';
import 'package:oronbox/src/features/devices/health/health_store.dart';
import 'package:oronbox/src/protocols/generated/xiaomi/wear_fitness.pb.dart'
    as pb_fitness;

/// Xiaomi health synchronizer based on Xiaomi's activity-file protocol.
///
/// Activity files remain the primary source because they carry the detailed
/// samples and the v5/v6 sleep report. Some VelaOS devices expose only the
/// summary response for sleep, however, so the protocol-level sleep result is
/// used as a narrow fallback for start/end time and summary values.
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
    _log.info('Xiaomi health synchronization started for $_deviceId');
    final previous = await _store.read(_deviceId);
    // Do not turn an activity-file transport failure into a second, unrelated
    // sleep request. The file transfer is the source for all health metrics;
    // its error must reach the caller so the UI can report the actual failure.
    final files = await _system.syncActivityFiles();
    _log.info(
      'Xiaomi health activity files received for $_deviceId: '
      'files=${files.filesReceived}, skipped=${files.filesSkipped}, '
      'failed=${files.failedFiles.length}',
    );

    var sleepResult = pb_fitness.SleepResult();
    if (files.sleep.isEmpty) {
      _log.fine(
        'Xiaomi activity files contained no sleep summary; '
        'requesting protocol sleep fallback for $_deviceId',
      );
      try {
        sleepResult = await _system.fetchSleepResult(
          timeout: const Duration(seconds: 4),
        );
        _log.fine(
          'Xiaomi protocol sleep fallback received for $_deviceId: '
          'sections=${sleepResult.sectionList.length}',
        );
      } catch (error, stackTrace) {
        _log.fine(
          'Xiaomi protocol sleep fallback failed for $_deviceId',
          error,
          stackTrace,
        );
      }
    }

    final daily = files.daily.map(_daily).toList(growable: false);
    final samples = files.samples.expand(_samples).toList(growable: false);
    final fileSleep = files.sleep
        .map(
          (value) => HealthSleepSummary(
            startedAt: value.startedAt,
            endedAt: value.endedAt,
            durationSeconds: value.durationSeconds,
            averageHeartRate: value.averageHeartRate,
            averageBloodOxygen: value.averageBloodOxygen,
            minimumHeartRate: value.minimumHeartRate,
            maximumHeartRate: value.maximumHeartRate,
            minimumBloodOxygen: value.minimumBloodOxygen,
            maximumBloodOxygen: value.maximumBloodOxygen,
            quality: value.quality,
            sleepEfficiency: value.sleepEfficiency,
            bedDurationSeconds: value.bedDurationSeconds,
            goBedAt: value.goBedAt,
            leaveBedAt: value.leaveBedAt,
            awakeDurationSeconds: value.awakeDurationSeconds,
            lightSleepDurationSeconds: value.lightSleepDurationSeconds,
            deepSleepDurationSeconds: value.deepSleepDurationSeconds,
            remSleepDurationSeconds: value.remSleepDurationSeconds,
            averageHrv: value.averageHrv,
            hrvMin: value.hrvMin,
            hrvMax: value.hrvMax,
            hrvBaselineMin: value.hrvBaselineMin,
            hrvBaselineMax: value.hrvBaselineMax,
            hrvStandardDeviation: value.hrvStandardDeviation,
            hrvMedian: value.hrvMedian,
            hrvLowerQuantile: value.hrvLowerQuantile,
            hrvMiddleQuantile: value.hrvMiddleQuantile,
            hrvUpperQuantile: value.hrvUpperQuantile,
            hrvTimestamp: value.hrvTimestamp,
            sleepIndex: value.sleepIndex,
            wakeCount: value.wakeCount,
            hasRem: value.hasRem,
            hasStage: value.hasStage,
            sleepScoreVersion: value.sleepScoreVersion,
            hrvPoints: value.hrvPoints
                .map(
                  (point) => HealthSleepHrvPoint(
                    timestamp: point.timestamp,
                    value: point.value,
                  ),
                )
                .toList(growable: false),
            stages: _stages(value),
          ),
        )
        .toList(growable: false);
    final sleep = [...fileSleep, ..._sleepResultSummaries(sleepResult)];
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
    final abnormalHealthRecords = files.abnormalHealthRecords
        .map(
          (value) => HealthAbnormalHealthRecord(
            timestamp: value.timestamp,
            value: value.value,
            kind: switch (value.kind) {
              XiaomiActivityAbnormalHealthKind.highHeartRate =>
                HealthAbnormalHealthKind.highHeartRate,
              XiaomiActivityAbnormalHealthKind.lowHeartRate =>
                HealthAbnormalHealthKind.lowHeartRate,
              XiaomiActivityAbnormalHealthKind.lowBloodOxygen =>
                HealthAbnormalHealthKind.lowBloodOxygen,
              XiaomiActivityAbnormalHealthKind.highStress =>
                HealthAbnormalHealthKind.highStress,
              XiaomiActivityAbnormalHealthKind.irregularHeartbeat =>
                HealthAbnormalHealthKind.irregularHeartbeat,
            },
            threshold: value.threshold,
            startedAt: value.startedAt,
            endedAt: value.endedAt,
          ),
        )
        .toList(growable: false);

    if (files.filesReceived == 0 &&
        daily.isEmpty &&
        samples.isEmpty &&
        sleep.isEmpty &&
        workouts.isEmpty &&
        abnormalHealthRecords.isEmpty) {
      final failed = files.failedFiles.length;
      throw StateError(
        failed == 0
            ? 'No Xiaomi health activity files returned'
            : 'No Xiaomi health activity files could be synchronized '
                  '($failed failed after retries)',
      );
    }

    final warning = files.failedFiles.isEmpty
        ? null
        : 'Xiaomi health sync completed with '
              '${files.failedFiles.length} failed activity file(s)';

    final data = XiaomiHealthData(
      // Put this sync's records first. HealthStore de-duplicates equal keys
      // using first-wins semantics, so repeated syncs must prefer the newly
      // downloaded values over the cached snapshot.
      daily: [...daily, ...previous.daily],
      samples: [...samples, ...previous.samples],
      sleep: [...sleep, ...previous.sleep],
      workouts: [...workouts, ...previous.workouts],
      abnormalHealthRecords: [
        ...abnormalHealthRecords,
        ...previous.abnormalHealthRecords,
      ],
      capabilities: _capabilities(
        previous,
        daily,
        samples,
        sleep,
        workouts,
        abnormalHealthRecords,
      ),
      lastSyncedAt: DateTime.now(),
    );
    await _store.write(_deviceId, data);
    final saved = await _store.read(_deviceId);

    _log.info(
      'Xiaomi health synchronization saved for $_deviceId: '
      'files=${files.filesReceived}, daily=${daily.length}, '
      'samples=${samples.length}, sleep=${sleep.length}, '
      'workouts=${workouts.length}, abnormalHealth=${abnormalHealthRecords.length}, '
      'failed=${files.failedFiles.length}, '
      'skipped=${files.filesSkipped}',
    );
    return XiaomiHealthSyncResult(
      data: saved,
      updatedDaily: daily.isNotEmpty,
      updatedSamples: samples.isNotEmpty,
      updatedSleep: sleep.isNotEmpty,
      updatedWorkouts: workouts.isNotEmpty,
      warning: warning,
    );
  }

  /// Converts the device's summary-only sleep response into the same model as
  /// the activity-file parser. This response does not contain stage packets or
  /// HRV series, so it must never replace a detailed activity-file record.
  List<HealthSleepSummary> _sleepResultSummaries(
    pb_fitness.SleepResult result,
  ) {
    final summaries = <HealthSleepSummary>[];
    for (final section in result.sectionList) {
      if (!section.hasSleepTimestamp() || !section.hasWakeupTimestamp()) {
        continue;
      }
      final startedSeconds = section.sleepTimestamp;
      final endedSeconds = section.wakeupTimestamp;
      if (startedSeconds <= 0 || endedSeconds <= startedSeconds) continue;

      final elapsedSeconds = endedSeconds - startedSeconds;
      final reportedDuration = section.hasValidSleepTime()
          ? section.validSleepTime
          : 0;
      final durationSeconds =
          reportedDuration > 0 && reportedDuration <= elapsedSeconds
          ? reportedDuration
          : elapsedSeconds;
      if (durationSeconds <= 0) continue;

      final extra = section.hasExtraData() ? section.extraData : null;
      summaries.add(
        HealthSleepSummary(
          startedAt: xiaomiActivityTimestamp(startedSeconds),
          endedAt: xiaomiActivityTimestamp(endedSeconds),
          durationSeconds: durationSeconds,
          averageHeartRate: section.hasAverageHeartRate()
              ? section.averageHeartRate
              : null,
          averageBloodOxygen: section.hasAverageBloodOxygen()
              ? section.averageBloodOxygen
              : null,
          quality: extra?.hasSleepQuality() == true
              ? extra!.sleepQuality
              : null,
          sleepEfficiency: extra?.hasSleepEfficiency() == true
              ? extra!.sleepEfficiency
              : null,
        ),
      );
    }
    return summaries;
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
    List<HealthAbnormalHealthRecord> abnormalHealthRecords,
  ) {
    bool has(XiaomiHealthMetric metric) =>
        samples.any((value) => value.metric == metric);
    final latest = daily.isEmpty
        ? null
        : daily.reduce(
            (left, right) => left.date.isAfter(right.date) ? left : right,
          );
    return XiaomiHealthCapabilities(
      heartRate:
          previous.capabilities.heartRate ||
          has(XiaomiHealthMetric.heartRate) ||
          latest?.averageHeartRate != null ||
          latest?.restingHeartRate != null ||
          abnormalHealthRecords.any(
            (record) =>
                record.kind == HealthAbnormalHealthKind.highHeartRate ||
                record.kind == HealthAbnormalHealthKind.lowHeartRate ||
                record.kind == HealthAbnormalHealthKind.irregularHeartbeat,
          ),
      bloodOxygen:
          previous.capabilities.bloodOxygen ||
          has(XiaomiHealthMetric.bloodOxygen) ||
          latest?.averageBloodOxygen != null ||
          abnormalHealthRecords.any(
            (record) => record.kind == HealthAbnormalHealthKind.lowBloodOxygen,
          ),
      stress:
          previous.capabilities.stress ||
          has(XiaomiHealthMetric.stress) ||
          latest?.averageStress != null ||
          abnormalHealthRecords.any(
            (record) => record.kind == HealthAbnormalHealthKind.highStress,
          ),
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
      final pointEnd = point.endedAt ?? next;
      final endedAt = pointEnd.isAfter(value.endedAt)
          ? value.endedAt
          : pointEnd;
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
