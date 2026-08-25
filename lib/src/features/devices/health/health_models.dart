import 'dart:convert';

enum XiaomiHealthMetric {
  activity,
  activeCalories,
  heartRate,
  restingHeartRate,
  bloodOxygen,
  stress,
  vitality,
  sleep,
  workout,
}

class HealthSample {
  const HealthSample({
    required this.timestamp,
    required this.metric,
    required this.value,
  });

  final DateTime timestamp;
  final XiaomiHealthMetric metric;
  final double value;

  bool get isUsable {
    if (!value.isFinite) return false;
    return switch (metric) {
      XiaomiHealthMetric.heartRate ||
      XiaomiHealthMetric.restingHeartRate => value >= 30 && value <= 240,
      XiaomiHealthMetric.bloodOxygen => value >= 50 && value <= 100,
      XiaomiHealthMetric.stress => value > 0 && value <= 100,
      XiaomiHealthMetric.vitality => value >= 0,
      XiaomiHealthMetric.activity ||
      XiaomiHealthMetric.activeCalories => value >= 0,
      XiaomiHealthMetric.sleep || XiaomiHealthMetric.workout => false,
    };
  }

  Map<String, Object?> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'metric': metric.name,
    'value': value,
  };

  factory HealthSample.fromJson(Map<String, Object?> json) => HealthSample(
    timestamp: DateTime.parse(json['timestamp']!.toString()),
    metric: XiaomiHealthMetric.values.firstWhere(
      (value) => value.name == json['metric'],
      orElse: () => XiaomiHealthMetric.heartRate,
    ),
    value: (json['value'] as num).toDouble(),
  );
}

class HealthDailySummary {
  const HealthDailySummary({
    required this.date,
    this.steps,
    this.activeCalories,
    this.calories,
    this.distanceMeters,
    this.restingHeartRate,
    this.minHeartRate,
    this.maxHeartRate,
    this.averageHeartRate,
    this.minStress,
    this.maxStress,
    this.averageStress,
    this.standingBitmap,
    this.minBloodOxygen,
    this.maxBloodOxygen,
    this.averageBloodOxygen,
    this.vitalityIncreaseLight,
    this.vitalityIncreaseModerate,
    this.vitalityIncreaseHigh,
    this.vitalityCurrent,
  });

  final DateTime date;
  final int? steps;
  final int? activeCalories;
  final int? calories;
  final int? distanceMeters;
  final int? restingHeartRate;
  final int? minHeartRate;
  final int? maxHeartRate;
  final int? averageHeartRate;
  final int? minStress;
  final int? maxStress;
  final int? averageStress;

  /// One bit per hour, starting at 00:00, as defined by Gadgetbridge's
  /// Xiaomi daily-summary parser.
  final int? standingBitmap;

  final int? minBloodOxygen;
  final int? maxBloodOxygen;
  final int? averageBloodOxygen;
  final int? vitalityIncreaseLight;
  final int? vitalityIncreaseModerate;
  final int? vitalityIncreaseHigh;
  final int? vitalityCurrent;

  int? get standingHours {
    final value = standingBitmap;
    if (value == null) return null;
    var bits = value;
    var count = 0;
    while (bits != 0) {
      count += bits & 1;
      bits >>= 1;
    }
    return count;
  }

  Map<String, Object?> toJson() => {
    'date': date.toIso8601String(),
    if (steps != null) 'steps': steps,
    if (activeCalories != null) 'activeCalories': activeCalories,
    if (calories != null) 'calories': calories,
    if (distanceMeters != null) 'distanceMeters': distanceMeters,
    if (restingHeartRate != null) 'restingHeartRate': restingHeartRate,
    if (minHeartRate != null) 'minHeartRate': minHeartRate,
    if (maxHeartRate != null) 'maxHeartRate': maxHeartRate,
    if (averageHeartRate != null) 'averageHeartRate': averageHeartRate,
    if (minStress != null) 'minStress': minStress,
    if (maxStress != null) 'maxStress': maxStress,
    if (averageStress != null) 'averageStress': averageStress,
    if (standingBitmap != null) 'standingBitmap': standingBitmap,
    if (minBloodOxygen != null) 'minBloodOxygen': minBloodOxygen,
    if (maxBloodOxygen != null) 'maxBloodOxygen': maxBloodOxygen,
    if (averageBloodOxygen != null) 'averageBloodOxygen': averageBloodOxygen,
    if (vitalityIncreaseLight != null)
      'vitalityIncreaseLight': vitalityIncreaseLight,
    if (vitalityIncreaseModerate != null)
      'vitalityIncreaseModerate': vitalityIncreaseModerate,
    if (vitalityIncreaseHigh != null)
      'vitalityIncreaseHigh': vitalityIncreaseHigh,
    if (vitalityCurrent != null) 'vitalityCurrent': vitalityCurrent,
  };

  factory HealthDailySummary.fromJson(Map<String, Object?> json) =>
      HealthDailySummary(
        date: DateTime.parse(json['date']!.toString()),
        steps: _int(json['steps']),
        activeCalories: _int(json['activeCalories']),
        calories: _int(json['calories']),
        distanceMeters: _int(json['distanceMeters']),
        restingHeartRate: _int(json['restingHeartRate']),
        minHeartRate: _int(json['minHeartRate']),
        maxHeartRate: _int(json['maxHeartRate']),
        averageHeartRate: _int(json['averageHeartRate']),
        minStress: _int(json['minStress']),
        maxStress: _int(json['maxStress']),
        averageStress: _int(json['averageStress']),
        standingBitmap: _int(json['standingBitmap']),
        minBloodOxygen: _int(json['minBloodOxygen']),
        maxBloodOxygen: _int(json['maxBloodOxygen']),
        averageBloodOxygen: _int(json['averageBloodOxygen']),
        vitalityIncreaseLight: _int(json['vitalityIncreaseLight']),
        vitalityIncreaseModerate: _int(json['vitalityIncreaseModerate']),
        vitalityIncreaseHigh: _int(json['vitalityIncreaseHigh']),
        vitalityCurrent: _int(json['vitalityCurrent']),
      );
}

enum HealthAbnormalHealthKind {
  highHeartRate,
  lowHeartRate,
  lowBloodOxygen,
  highStress,
  irregularHeartbeat,
}

class HealthAbnormalHealthRecord {
  const HealthAbnormalHealthRecord({
    required this.timestamp,
    required this.kind,
    this.value,
    this.threshold,
    this.startedAt,
    this.endedAt,
  });

  final DateTime timestamp;
  final HealthAbnormalHealthKind kind;
  final int? value;
  final int? threshold;
  final DateTime? startedAt;
  final DateTime? endedAt;

  Map<String, Object?> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'kind': kind.name,
    if (value != null) 'value': value,
    if (threshold != null) 'threshold': threshold,
    if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
    if (endedAt != null) 'endedAt': endedAt!.toIso8601String(),
  };

  factory HealthAbnormalHealthRecord.fromJson(Map<String, Object?> json) =>
      HealthAbnormalHealthRecord(
        timestamp: DateTime.parse(json['timestamp']!.toString()),
        kind: HealthAbnormalHealthKind.values.firstWhere(
          (value) => value.name == json['kind'],
          orElse: () => HealthAbnormalHealthKind.irregularHeartbeat,
        ),
        value: _int(json['value']),
        threshold: _int(json['threshold']),
        startedAt: _dateTime(json['startedAt']),
        endedAt: _dateTime(json['endedAt']),
      );
}

/// Compatibility model for callers that only consume high/low heart-rate
/// alerts. New code should use [HealthAbnormalHealthRecord].
enum HealthAbnormalHeartRateKind { high, low, unknown }

class HealthAbnormalHeartRateRecord {
  const HealthAbnormalHeartRateRecord({
    required this.timestamp,
    required this.value,
    required this.kind,
    required this.threshold,
    this.startedAt,
    this.endedAt,
  });

  final DateTime timestamp;
  final int value;
  final HealthAbnormalHeartRateKind kind;
  final int threshold;
  final DateTime? startedAt;
  final DateTime? endedAt;

  Map<String, Object?> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'value': value,
    'kind': kind.name,
    'threshold': threshold,
    if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
    if (endedAt != null) 'endedAt': endedAt!.toIso8601String(),
  };

  factory HealthAbnormalHeartRateRecord.fromJson(Map<String, Object?> json) =>
      HealthAbnormalHeartRateRecord(
        timestamp: DateTime.parse(json['timestamp']!.toString()),
        value: (json['value'] as num).toInt(),
        kind: HealthAbnormalHeartRateKind.values.firstWhere(
          (value) => value.name == json['kind'],
          orElse: () => HealthAbnormalHeartRateKind.unknown,
        ),
        threshold: (json['threshold'] as num?)?.toInt() ?? 0,
        startedAt: _dateTime(json['startedAt']),
        endedAt: _dateTime(json['endedAt']),
      );
}

class HealthSleepSummary {
  const HealthSleepSummary({
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    this.averageHeartRate,
    this.averageBloodOxygen,
    this.minimumHeartRate,
    this.maximumHeartRate,
    this.minimumBloodOxygen,
    this.maximumBloodOxygen,
    this.quality,
    this.sleepEfficiency,
    this.bedDurationSeconds,
    this.goBedAt,
    this.leaveBedAt,
    this.awakeDurationSeconds,
    this.lightSleepDurationSeconds,
    this.deepSleepDurationSeconds,
    this.remSleepDurationSeconds,
    this.averageHrv,
    this.hrvMin,
    this.hrvMax,
    this.hrvBaselineMin,
    this.hrvBaselineMax,
    this.hrvStandardDeviation,
    this.hrvMedian,
    this.hrvLowerQuantile,
    this.hrvMiddleQuantile,
    this.hrvUpperQuantile,
    this.hrvTimestamp,
    this.sleepIndex,
    this.wakeCount,
    this.hasRem,
    this.hasStage,
    this.sleepScoreVersion,
    this.hrvPoints = const [],
    this.stages = const [],
  });

  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSeconds;
  final int? averageHeartRate;
  final int? averageBloodOxygen;
  final int? minimumHeartRate;
  final int? maximumHeartRate;
  final int? minimumBloodOxygen;
  final int? maximumBloodOxygen;
  final int? quality;
  final int? sleepEfficiency;
  final int? bedDurationSeconds;
  final DateTime? goBedAt;
  final DateTime? leaveBedAt;
  final int? awakeDurationSeconds;
  final int? lightSleepDurationSeconds;
  final int? deepSleepDurationSeconds;
  final int? remSleepDurationSeconds;
  final int? averageHrv;
  final int? hrvMin;
  final int? hrvMax;
  final int? hrvBaselineMin;
  final int? hrvBaselineMax;
  final int? hrvStandardDeviation;
  final int? hrvMedian;
  final int? hrvLowerQuantile;
  final int? hrvMiddleQuantile;
  final int? hrvUpperQuantile;
  final DateTime? hrvTimestamp;
  final int? sleepIndex;
  final int? wakeCount;
  final bool? hasRem;
  final bool? hasStage;
  final int? sleepScoreVersion;
  final List<HealthSleepHrvPoint> hrvPoints;
  final List<HealthSleepStageSegment> stages;

  Map<String, Object?> toJson() => {
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
    'durationSeconds': durationSeconds,
    if (averageHeartRate != null) 'averageHeartRate': averageHeartRate,
    if (averageBloodOxygen != null) 'averageBloodOxygen': averageBloodOxygen,
    if (minimumHeartRate != null) 'minimumHeartRate': minimumHeartRate,
    if (maximumHeartRate != null) 'maximumHeartRate': maximumHeartRate,
    if (minimumBloodOxygen != null) 'minimumBloodOxygen': minimumBloodOxygen,
    if (maximumBloodOxygen != null) 'maximumBloodOxygen': maximumBloodOxygen,
    if (quality != null) 'quality': quality,
    if (sleepEfficiency != null) 'sleepEfficiency': sleepEfficiency,
    if (bedDurationSeconds != null) 'bedDurationSeconds': bedDurationSeconds,
    if (goBedAt != null) 'goBedAt': goBedAt!.toIso8601String(),
    if (leaveBedAt != null) 'leaveBedAt': leaveBedAt!.toIso8601String(),
    if (awakeDurationSeconds != null)
      'awakeDurationSeconds': awakeDurationSeconds,
    if (lightSleepDurationSeconds != null)
      'lightSleepDurationSeconds': lightSleepDurationSeconds,
    if (deepSleepDurationSeconds != null)
      'deepSleepDurationSeconds': deepSleepDurationSeconds,
    if (remSleepDurationSeconds != null)
      'remSleepDurationSeconds': remSleepDurationSeconds,
    if (averageHrv != null) 'averageHrv': averageHrv,
    if (hrvMin != null) 'hrvMin': hrvMin,
    if (hrvMax != null) 'hrvMax': hrvMax,
    if (hrvBaselineMin != null) 'hrvBaselineMin': hrvBaselineMin,
    if (hrvBaselineMax != null) 'hrvBaselineMax': hrvBaselineMax,
    if (hrvStandardDeviation != null)
      'hrvStandardDeviation': hrvStandardDeviation,
    if (hrvMedian != null) 'hrvMedian': hrvMedian,
    if (hrvLowerQuantile != null) 'hrvLowerQuantile': hrvLowerQuantile,
    if (hrvMiddleQuantile != null) 'hrvMiddleQuantile': hrvMiddleQuantile,
    if (hrvUpperQuantile != null) 'hrvUpperQuantile': hrvUpperQuantile,
    if (hrvTimestamp != null) 'hrvTimestamp': hrvTimestamp!.toIso8601String(),
    if (sleepIndex != null) 'sleepIndex': sleepIndex,
    if (wakeCount != null) 'wakeCount': wakeCount,
    if (hasRem != null) 'hasRem': hasRem,
    if (hasStage != null) 'hasStage': hasStage,
    if (sleepScoreVersion != null) 'sleepScoreVersion': sleepScoreVersion,
    'hrvPoints': hrvPoints
        .map((value) => value.toJson())
        .toList(growable: false),
    'stages': stages.map((value) => value.toJson()).toList(growable: false),
  };

  factory HealthSleepSummary.fromJson(Map<String, Object?> json) =>
      HealthSleepSummary(
        startedAt: DateTime.parse(json['startedAt']!.toString()),
        endedAt: DateTime.parse(json['endedAt']!.toString()),
        durationSeconds: (json['durationSeconds'] as num).toInt(),
        averageHeartRate: _int(json['averageHeartRate']),
        averageBloodOxygen: _int(json['averageBloodOxygen']),
        minimumHeartRate: _int(json['minimumHeartRate']),
        maximumHeartRate: _int(json['maximumHeartRate']),
        minimumBloodOxygen: _int(json['minimumBloodOxygen']),
        maximumBloodOxygen: _int(json['maximumBloodOxygen']),
        quality: _int(json['quality']),
        sleepEfficiency: _int(json['sleepEfficiency']),
        bedDurationSeconds: _int(json['bedDurationSeconds']),
        goBedAt: _dateTime(json['goBedAt']),
        leaveBedAt: _dateTime(json['leaveBedAt']),
        awakeDurationSeconds: _int(json['awakeDurationSeconds']),
        lightSleepDurationSeconds: _int(json['lightSleepDurationSeconds']),
        deepSleepDurationSeconds: _int(json['deepSleepDurationSeconds']),
        remSleepDurationSeconds: _int(json['remSleepDurationSeconds']),
        averageHrv: _int(json['averageHrv']),
        hrvMin: _int(json['hrvMin']),
        hrvMax: _int(json['hrvMax']),
        hrvBaselineMin: _int(json['hrvBaselineMin']),
        hrvBaselineMax: _int(json['hrvBaselineMax']),
        hrvStandardDeviation: _int(json['hrvStandardDeviation']),
        hrvMedian: _int(json['hrvMedian']),
        hrvLowerQuantile: _int(json['hrvLowerQuantile']),
        hrvMiddleQuantile: _int(json['hrvMiddleQuantile']),
        hrvUpperQuantile: _int(json['hrvUpperQuantile']),
        hrvTimestamp: _dateTime(json['hrvTimestamp']),
        sleepIndex: _int(json['sleepIndex']),
        wakeCount: _int(json['wakeCount']),
        hasRem: _bool(json['hasRem']),
        hasStage: _bool(json['hasStage']),
        sleepScoreVersion: _int(json['sleepScoreVersion']),
        hrvPoints: _list(json['hrvPoints'], HealthSleepHrvPoint.fromJson),
        stages: _list(json['stages'], HealthSleepStageSegment.fromJson),
      );
}

class HealthSleepHrvPoint {
  const HealthSleepHrvPoint({required this.timestamp, required this.value});

  final DateTime timestamp;
  final int value;

  Map<String, Object?> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'value': value,
  };

  factory HealthSleepHrvPoint.fromJson(Map<String, Object?> json) =>
      HealthSleepHrvPoint(
        timestamp: DateTime.parse(json['timestamp']!.toString()),
        value: (json['value'] as num).toInt(),
      );
}

enum HealthSleepStageKind { awake, light, deep, rem, unknown }

class HealthSleepStageSegment {
  const HealthSleepStageSegment({
    required this.startedAt,
    required this.endedAt,
    required this.kind,
  });

  final DateTime startedAt;
  final DateTime endedAt;
  final HealthSleepStageKind kind;

  int get durationSeconds => endedAt.difference(startedAt).inSeconds;

  Map<String, Object?> toJson() => {
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
    'kind': kind.name,
  };

  factory HealthSleepStageSegment.fromJson(Map<String, Object?> json) =>
      HealthSleepStageSegment(
        startedAt: DateTime.parse(json['startedAt']!.toString()),
        endedAt: DateTime.parse(json['endedAt']!.toString()),
        kind: HealthSleepStageKind.values.firstWhere(
          (value) => value.name == json['kind'],
          orElse: () => HealthSleepStageKind.unknown,
        ),
      );
}

class HealthWorkoutSummary {
  const HealthWorkoutSummary({
    required this.startedAt,
    required this.endedAt,
    required this.activityType,
    this.distanceMeters,
    this.calories,
  });

  final DateTime startedAt;
  final DateTime endedAt;
  final int activityType;
  final int? distanceMeters;
  final int? calories;

  Map<String, Object?> toJson() => {
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
    'activityType': activityType,
    if (distanceMeters != null) 'distanceMeters': distanceMeters,
    if (calories != null) 'calories': calories,
  };

  factory HealthWorkoutSummary.fromJson(Map<String, Object?> json) =>
      HealthWorkoutSummary(
        startedAt: DateTime.parse(json['startedAt']!.toString()),
        endedAt: DateTime.parse(json['endedAt']!.toString()),
        activityType: (json['activityType'] as num).toInt(),
        distanceMeters: _int(json['distanceMeters']),
        calories: _int(json['calories']),
      );
}

class XiaomiHealthCapabilities {
  const XiaomiHealthCapabilities({
    this.heartRate = false,
    this.bloodOxygen = false,
    this.stress = false,
    this.vitality = false,
    this.sleep = false,
    this.workouts = false,
  });

  final bool heartRate;
  final bool bloodOxygen;
  final bool stress;
  final bool vitality;
  final bool sleep;
  final bool workouts;

  Map<String, Object?> toJson() => {
    'heartRate': heartRate,
    'bloodOxygen': bloodOxygen,
    'stress': stress,
    'vitality': vitality,
    'sleep': sleep,
    'workouts': workouts,
  };

  factory XiaomiHealthCapabilities.fromJson(Map<String, Object?> json) =>
      XiaomiHealthCapabilities(
        heartRate: json['heartRate'] == true,
        bloodOxygen: json['bloodOxygen'] == true,
        stress: json['stress'] == true,
        vitality: json['vitality'] == true,
        sleep: json['sleep'] == true,
        workouts: json['workouts'] == true,
      );
}

class XiaomiHealthData {
  const XiaomiHealthData({
    this.daily = const [],
    this.samples = const [],
    this.sleep = const [],
    this.workouts = const [],
    this.abnormalHealthRecords = const [],
    this.capabilities = const XiaomiHealthCapabilities(),
    this.lastSyncedAt,
  });

  final List<HealthDailySummary> daily;
  final List<HealthSample> samples;
  final List<HealthSleepSummary> sleep;
  final List<HealthWorkoutSummary> workouts;
  final List<HealthAbnormalHealthRecord> abnormalHealthRecords;
  final XiaomiHealthCapabilities capabilities;
  final DateTime? lastSyncedAt;

  /// Compatibility view for old callers and data consumers. New code should
  /// use [abnormalHealthRecords] so blood oxygen, stress, and heart-health
  /// events are not mislabeled as ordinary heart-rate alerts.
  List<HealthAbnormalHeartRateRecord> get abnormalHeartRates =>
      abnormalHealthRecords
          .where(
            (record) =>
                record.kind == HealthAbnormalHealthKind.highHeartRate ||
                record.kind == HealthAbnormalHealthKind.lowHeartRate,
          )
          .where((record) => record.value != null && record.threshold != null)
          .map(
            (record) => HealthAbnormalHeartRateRecord(
              timestamp: record.timestamp,
              value: record.value!,
              kind: record.kind == HealthAbnormalHealthKind.highHeartRate
                  ? HealthAbnormalHeartRateKind.high
                  : HealthAbnormalHeartRateKind.low,
              threshold: record.threshold!,
              startedAt: record.startedAt,
              endedAt: record.endedAt,
            ),
          )
          .toList(growable: false);

  HealthDailySummary? get latestDay {
    if (daily.isEmpty) return null;
    return daily.reduce(
      (left, right) => left.date.isAfter(right.date) ? left : right,
    );
  }

  HealthDailySummary? get activitySummary {
    final activitySamples = samples
        .where(
          (sample) =>
              sample.isUsable &&
              (sample.metric == XiaomiHealthMetric.activity ||
                  sample.metric == XiaomiHealthMetric.activeCalories),
        )
        .toList();
    final sampleDate = activitySamples.isEmpty
        ? null
        : _dateOnly(
            activitySamples
                .reduce(
                  (left, right) =>
                      left.timestamp.isAfter(right.timestamp) ? left : right,
                )
                .timestamp,
          );
    final day = latestDay;
    final referenceDate =
        day == null || (sampleDate != null && sampleDate.isAfter(day.date))
        ? sampleDate
        : day.date;
    if (referenceDate == null) return null;

    final daySummary = day != null && _sameDate(day.date, referenceDate)
        ? day
        : null;

    final daySamples = activitySamples.where(
      (sample) => _sameDate(sample.timestamp, referenceDate),
    );
    int? sum(XiaomiHealthMetric metric) {
      final values = daySamples
          .where((sample) => sample.metric == metric)
          .map((sample) => sample.value)
          .toList();
      if (values.isEmpty) return null;
      return values.fold<double>(0, (total, value) => total + value).round();
    }

    final steps = daySummary?.steps ?? sum(XiaomiHealthMetric.activity);
    final activeCalories =
        daySummary?.activeCalories ?? sum(XiaomiHealthMetric.activeCalories);
    final standingBitmap =
        daySummary?.standingBitmap ?? _standingBitmap(daySamples);
    if (steps == null && activeCalories == null && standingBitmap == null) {
      return day;
    }
    return HealthDailySummary(
      date: referenceDate,
      steps: steps,
      activeCalories: activeCalories,
      calories: daySummary?.calories,
      distanceMeters: daySummary?.distanceMeters,
      restingHeartRate: daySummary?.restingHeartRate,
      minHeartRate: daySummary?.minHeartRate,
      maxHeartRate: daySummary?.maxHeartRate,
      averageHeartRate: daySummary?.averageHeartRate,
      minStress: daySummary?.minStress,
      maxStress: daySummary?.maxStress,
      averageStress: daySummary?.averageStress,
      standingBitmap: standingBitmap,
      minBloodOxygen: daySummary?.minBloodOxygen,
      maxBloodOxygen: daySummary?.maxBloodOxygen,
      averageBloodOxygen: daySummary?.averageBloodOxygen,
      vitalityIncreaseLight: daySummary?.vitalityIncreaseLight,
      vitalityIncreaseModerate: daySummary?.vitalityIncreaseModerate,
      vitalityIncreaseHigh: daySummary?.vitalityIncreaseHigh,
      vitalityCurrent: daySummary?.vitalityCurrent,
    );
  }

  HealthSleepSummary? get latestSleep {
    if (sleep.isEmpty) return null;
    return sleep.reduce((left, right) {
      final endComparison = left.endedAt.compareTo(right.endedAt);
      if (endComparison != 0) {
        return endComparison > 0 ? left : right;
      }
      return left.startedAt.isAfter(right.startedAt) ? left : right;
    });
  }

  List<HealthSample> samplesFor(XiaomiHealthMetric metric) => samples
      .where((sample) => sample.metric == metric)
      .toList(growable: false);

  HealthSample? latestSample(XiaomiHealthMetric metric) {
    final values = samples
        .where((sample) => sample.metric == metric && sample.isUsable)
        .toList();
    if (values.isEmpty) return null;
    return values.reduce(
      (left, right) => left.timestamp.isAfter(right.timestamp) ? left : right,
    );
  }

  Map<String, Object?> toJson() => {
    'schema': 2,
    'daily': daily.map((value) => value.toJson()).toList(growable: false),
    'samples': samples.map((value) => value.toJson()).toList(growable: false),
    'sleep': sleep.map((value) => value.toJson()).toList(growable: false),
    'workouts': workouts.map((value) => value.toJson()).toList(growable: false),
    'abnormalHealthRecords': abnormalHealthRecords
        .map((value) => value.toJson())
        .toList(growable: false),
    'capabilities': capabilities.toJson(),
    'lastSyncedAt': lastSyncedAt?.toIso8601String(),
  };

  String encode() => jsonEncode(toJson());

  factory XiaomiHealthData.fromJson(Map<String, Object?> json) =>
      XiaomiHealthData(
        daily: _list(json['daily'], HealthDailySummary.fromJson),
        samples: _list(json['samples'], HealthSample.fromJson),
        sleep: _list(json['sleep'], HealthSleepSummary.fromJson),
        workouts: _list(json['workouts'], HealthWorkoutSummary.fromJson),
        abnormalHealthRecords: _abnormalHealthRecords(json),
        capabilities: json['capabilities'] is Map
            ? XiaomiHealthCapabilities.fromJson(
                (json['capabilities'] as Map).cast(),
              )
            : const XiaomiHealthCapabilities(),
        lastSyncedAt: json['lastSyncedAt'] == null
            ? null
            : DateTime.parse(json['lastSyncedAt']!.toString()),
      );

  factory XiaomiHealthData.decode(String value) =>
      XiaomiHealthData.fromJson((jsonDecode(value) as Map).cast());

  static bool _sameDate(DateTime left, DateTime right) {
    final localLeft = left.toLocal();
    final localRight = right.toLocal();
    return localLeft.year == localRight.year &&
        localLeft.month == localRight.month &&
        localLeft.day == localRight.day;
  }

  static DateTime _dateOnly(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static int? _standingBitmap(Iterable<HealthSample> values) {
    var bitmap = 0;
    var found = false;
    for (final sample in values) {
      if (sample.metric != XiaomiHealthMetric.activity || !sample.isUsable) {
        continue;
      }
      if (sample.value <= 0) continue;
      bitmap |= 1 << sample.timestamp.toLocal().hour;
      found = true;
    }
    return found ? bitmap : null;
  }
}

class XiaomiHealthSyncResult {
  const XiaomiHealthSyncResult({
    required this.data,
    required this.updatedDaily,
    required this.updatedSamples,
    required this.updatedSleep,
    required this.updatedWorkouts,
    this.warning,
  });

  final XiaomiHealthData data;
  final bool updatedDaily;
  final bool updatedSamples;
  final bool updatedSleep;
  final bool updatedWorkouts;
  final String? warning;

  Map<String, Object?> toJson() => {
    'data': data.toJson(),
    'updatedDaily': updatedDaily,
    'updatedSamples': updatedSamples,
    'updatedSleep': updatedSleep,
    'updatedWorkouts': updatedWorkouts,
    if (warning != null) 'warning': warning,
  };

  factory XiaomiHealthSyncResult.fromJson(Map<String, Object?> json) =>
      XiaomiHealthSyncResult(
        data: XiaomiHealthData.fromJson((json['data'] as Map).cast()),
        updatedDaily: json['updatedDaily'] == true,
        updatedSamples: json['updatedSamples'] == true,
        updatedSleep: json['updatedSleep'] == true,
        updatedWorkouts: json['updatedWorkouts'] == true,
        warning: json['warning']?.toString(),
      );
}

Map<String, Object?> healthStatusSurfaceData(XiaomiHealthData data) {
  final activity = data.activitySummary ?? data.latestDay;
  final heartRate = data.latestSample(XiaomiHealthMetric.heartRate);
  final bloodOxygen = data.latestSample(XiaomiHealthMetric.bloodOxygen);
  final stress = data.latestSample(XiaomiHealthMetric.stress);
  final sleep = data.latestSleep;
  return {
    'steps': activity?.steps ?? -1,
    'activeCalories': activity?.activeCalories ?? activity?.calories ?? -1,
    'standingHours': activity?.standingHours ?? -1,
    'heartRate': heartRate?.value.round() ?? activity?.averageHeartRate ?? -1,
    'heartRateAt': heartRate?.timestamp.millisecondsSinceEpoch ?? -1,
    'bloodOxygen':
        bloodOxygen?.value.round() ?? activity?.averageBloodOxygen ?? -1,
    'bloodOxygenAt': bloodOxygen?.timestamp.millisecondsSinceEpoch ?? -1,
    'stress': stress?.value.round() ?? activity?.averageStress ?? -1,
    'stressAt': stress?.timestamp.millisecondsSinceEpoch ?? -1,
    'vitality': activity?.vitalityCurrent ?? -1,
    'sleepDuration': sleep?.durationSeconds ?? -1,
    'sleepStart': sleep?.startedAt.millisecondsSinceEpoch ?? -1,
    'sleepEnd': sleep?.endedAt.millisecondsSinceEpoch ?? -1,
    'updatedAt':
        data.lastSyncedAt?.millisecondsSinceEpoch ??
        DateTime.now().millisecondsSinceEpoch,
  };
}

int? _int(Object? value) => (value as num?)?.toInt();

List<HealthAbnormalHealthRecord> _abnormalHealthRecords(
  Map<String, Object?> json,
) {
  final current = _list(
    json['abnormalHealthRecords'],
    HealthAbnormalHealthRecord.fromJson,
  );
  if (current.isNotEmpty || json.containsKey('abnormalHealthRecords')) {
    return current;
  }
  return _list(
        json['abnormalHeartRates'],
        HealthAbnormalHeartRateRecord.fromJson,
      )
      .map(
        (record) => HealthAbnormalHealthRecord(
          timestamp: record.timestamp,
          value: record.value,
          kind: record.kind == HealthAbnormalHeartRateKind.low
              ? HealthAbnormalHealthKind.lowHeartRate
              : HealthAbnormalHealthKind.highHeartRate,
          threshold: record.threshold,
          startedAt: record.startedAt,
          endedAt: record.endedAt,
        ),
      )
      .toList(growable: false);
}

bool? _bool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return null;
}

DateTime? _dateTime(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString());

List<T> _list<T>(Object? value, T Function(Map<String, Object?> json) decode) =>
    (value as List? ?? const [])
        .whereType<Map>()
        .map((item) => decode(item.cast()))
        .toList(growable: false);
