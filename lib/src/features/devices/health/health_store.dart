import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';

/// Local store for the rewritten Xiaomi health data model.
///
/// This intentionally uses a new key namespace. The previous health model is
/// not migrated: its entry is removed when this store is first opened for a
/// device.
class HealthStore {
  // v2 was written while activity timestamps were incorrectly treated as
  // UTC. Drop it so the first sync after this fix cannot mix shifted and
  // corrected records.
  static const _keyPrefix = 'health_data_v3_';
  static const _legacyKeyPrefixes = ['health_data_v1_', 'health_data_v2_'];
  static const _maxDailyRecords = 90;
  static const _maxSampleRecords = 30 * 24 * 60;
  static const _maxSleepRecords = 90;
  static const _maxWorkoutRecords = 90;

  final _prefs = SharedPrefsService.instance;

  Future<XiaomiHealthData> read(String deviceId) async {
    for (final prefix in _legacyKeyPrefixes) {
      await _prefs.remove(_keyFor(prefix, deviceId));
    }
    final value = _prefs.getString(_key(deviceId));
    if (value == null || value.isEmpty) return const XiaomiHealthData();
    try {
      return XiaomiHealthData.decode(value);
    } catch (_) {
      return const XiaomiHealthData();
    }
  }

  Future<void> write(String deviceId, XiaomiHealthData data) async {
    final daily = [...data.daily]..sort((a, b) => b.date.compareTo(a.date));
    final samples = [...data.samples]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final sleep = [...data.sleep]
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final workouts = [...data.workouts]
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final normalized = XiaomiHealthData(
      daily: _deduplicateDaily(daily).take(_maxDailyRecords).toList(),
      samples: _deduplicateSamples(samples).take(_maxSampleRecords).toList(),
      sleep: _deduplicateSleep(sleep).take(_maxSleepRecords).toList(),
      workouts: _deduplicateWorkouts(
        workouts,
      ).take(_maxWorkoutRecords).toList(),
      capabilities: data.capabilities,
      lastSyncedAt: data.lastSyncedAt,
    );
    final ok = await _prefs.setString(_key(deviceId), normalized.encode());
    if (!ok) throw StateError('Unable to persist health data');
  }

  String _key(String deviceId) =>
      '$_keyPrefix${sha1.convert(utf8.encode(deviceId)).toString()}';

  String _keyFor(String prefix, String deviceId) =>
      '$prefix${sha1.convert(utf8.encode(deviceId)).toString()}';

  List<HealthDailySummary> _deduplicateDaily(List<HealthDailySummary> values) {
    final result = <String, HealthDailySummary>{};
    for (final value in values) {
      result[_dateKey(value.date)] ??= value;
    }
    return result.values.toList(growable: false);
  }

  List<HealthSample> _deduplicateSamples(List<HealthSample> values) {
    final result = <String, HealthSample>{};
    for (final value in values) {
      result['${value.metric.name}|${value.timestamp.toIso8601String()}'] ??=
          value;
    }
    return result.values.toList(growable: false);
  }

  List<HealthSleepSummary> _deduplicateSleep(List<HealthSleepSummary> values) {
    final result = <String, HealthSleepSummary>{};
    for (final value in values) {
      final key =
          '${value.startedAt.toIso8601String()}|${value.endedAt.toIso8601String()}';
      final existing = result[key];
      if (existing == null || value.stages.length > existing.stages.length) {
        result[key] = value;
      }
    }
    return result.values.toList(growable: false);
  }

  List<HealthWorkoutSummary> _deduplicateWorkouts(
    List<HealthWorkoutSummary> values,
  ) {
    final result = <String, HealthWorkoutSummary>{};
    for (final value in values) {
      result['${value.startedAt.toIso8601String()}|${value.activityType}'] ??=
          value;
    }
    return result.values.toList(growable: false);
  }

  String _dateKey(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}
