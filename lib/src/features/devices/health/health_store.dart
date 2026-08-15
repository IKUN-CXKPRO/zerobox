import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';

/// Persistent local store for the first health-data slice.
///
/// The interface is deliberately independent of the backing store so the
/// capped JSON representation can later migrate to SQLite without changing
/// the device adapter or UI. Data is keyed by the stable OronBox device
/// address and never leaves the local application.
class HealthStore {
  static const _keyPrefix = 'health_data_v1_';
  static const _maxDailyRecords = 90;
  static const _maxSleepRecords = 90;

  final _prefs = SharedPrefsService.instance;

  Future<XiaomiHealthData> read(String deviceId) async {
    final value = _prefs.getString(_key(deviceId));
    if (value == null || value.isEmpty) return const XiaomiHealthData();
    try {
      return XiaomiHealthData.decode(value);
    } catch (_) {
      return const XiaomiHealthData();
    }
  }

  Future<void> write(String deviceId, XiaomiHealthData data) async {
    final dailyByDate = <String, HealthDailySummary>{
      for (final value in data.daily) _dateKey(value.date): value,
    };
    final sleepByStart = <String, HealthSleepSummary>{
      for (final value in data.sleep) _sleepKey(value): value,
    };
    final daily = dailyByDate.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final sleep = sleepByStart.values.toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final normalized = XiaomiHealthData(
      daily: daily.take(_maxDailyRecords).toList(growable: false),
      sleep: sleep.take(_maxSleepRecords).toList(growable: false),
      lastSyncedAt: data.lastSyncedAt,
    );
    final ok = await _prefs.setString(_key(deviceId), normalized.encode());
    if (!ok) throw StateError('Unable to persist health data');
  }

  String _key(String deviceId) =>
      '$_keyPrefix${sha1.convert(utf8.encode(deviceId)).toString()}';

  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String _sleepKey(HealthSleepSummary value) =>
      '${value.startedAt.toIso8601String()}|${value.endedAt.toIso8601String()}';
}
