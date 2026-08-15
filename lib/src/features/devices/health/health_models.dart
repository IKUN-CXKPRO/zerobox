import 'dart:convert';

class HealthDailySummary {
  const HealthDailySummary({
    required this.date,
    required this.steps,
    required this.calories,
    required this.distanceMeters,
    required this.heartRate,
    required this.intensity,
    this.validStand,
  });

  final DateTime date;
  final int steps;
  final int calories;
  final int distanceMeters;
  final int heartRate;
  final int intensity;
  final int? validStand;

  Map<String, Object?> toJson() => {
    'date': date.toIso8601String(),
    'steps': steps,
    'calories': calories,
    'distanceMeters': distanceMeters,
    'heartRate': heartRate,
    'intensity': intensity,
    'validStand': validStand,
  };

  factory HealthDailySummary.fromJson(Map<String, Object?> json) =>
      HealthDailySummary(
        date: DateTime.parse(json['date']!.toString()),
        steps: (json['steps'] as num?)?.toInt() ?? 0,
        calories: (json['calories'] as num?)?.toInt() ?? 0,
        distanceMeters: (json['distanceMeters'] as num?)?.toInt() ?? 0,
        heartRate: (json['heartRate'] as num?)?.toInt() ?? 0,
        intensity: (json['intensity'] as num?)?.toInt() ?? 0,
        validStand: (json['validStand'] as num?)?.toInt(),
      );
}

class HealthSleepSummary {
  const HealthSleepSummary({
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    this.averageHeartRate,
    this.averageBloodOxygen,
    this.quality,
  });

  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSeconds;
  final int? averageHeartRate;
  final int? averageBloodOxygen;
  final int? quality;

  Map<String, Object?> toJson() => {
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
    'durationSeconds': durationSeconds,
    'averageHeartRate': averageHeartRate,
    'averageBloodOxygen': averageBloodOxygen,
    'quality': quality,
  };

  factory HealthSleepSummary.fromJson(Map<String, Object?> json) =>
      HealthSleepSummary(
        startedAt: DateTime.parse(json['startedAt']!.toString()),
        endedAt: DateTime.parse(json['endedAt']!.toString()),
        durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
        averageHeartRate: (json['averageHeartRate'] as num?)?.toInt(),
        averageBloodOxygen: (json['averageBloodOxygen'] as num?)?.toInt(),
        quality: (json['quality'] as num?)?.toInt(),
      );
}

class XiaomiHealthData {
  const XiaomiHealthData({
    this.daily = const [],
    this.sleep = const [],
    this.lastSyncedAt,
  });

  final List<HealthDailySummary> daily;
  final List<HealthSleepSummary> sleep;
  final DateTime? lastSyncedAt;

  HealthDailySummary? get latestDay => daily.isEmpty ? null : daily.first;
  HealthSleepSummary? get latestSleep => sleep.isEmpty ? null : sleep.first;

  Map<String, Object?> toJson() => {
    'daily': daily.map((value) => value.toJson()).toList(growable: false),
    'sleep': sleep.map((value) => value.toJson()).toList(growable: false),
    'lastSyncedAt': lastSyncedAt?.toIso8601String(),
  };

  String encode() => jsonEncode(toJson());

  factory XiaomiHealthData.fromJson(Map<String, Object?> json) =>
      XiaomiHealthData(
        daily: (json['daily'] as List? ?? const [])
            .whereType<Map>()
            .map((value) => HealthDailySummary.fromJson(value.cast()))
            .toList(growable: false),
        sleep: (json['sleep'] as List? ?? const [])
            .whereType<Map>()
            .map((value) => HealthSleepSummary.fromJson(value.cast()))
            .toList(growable: false),
        lastSyncedAt: json['lastSyncedAt'] == null
            ? null
            : DateTime.parse(json['lastSyncedAt']!.toString()),
      );

  factory XiaomiHealthData.decode(String value) =>
      XiaomiHealthData.fromJson((jsonDecode(value) as Map).cast());
}

class XiaomiHealthSyncResult {
  const XiaomiHealthSyncResult({
    required this.data,
    required this.updatedDaily,
    required this.updatedSleep,
    this.warning,
  });

  final XiaomiHealthData data;
  final bool updatedDaily;
  final bool updatedSleep;
  final String? warning;

  Map<String, Object?> toJson() => {
    'data': data.toJson(),
    'updatedDaily': updatedDaily,
    'updatedSleep': updatedSleep,
    if (warning != null) 'warning': warning,
  };

  factory XiaomiHealthSyncResult.fromJson(Map<String, Object?> json) =>
      XiaomiHealthSyncResult(
        data: XiaomiHealthData.fromJson((json['data'] as Map).cast()),
        updatedDaily: json['updatedDaily'] == true,
        updatedSleep: json['updatedSleep'] == true,
        warning: json['warning']?.toString(),
      );
}
