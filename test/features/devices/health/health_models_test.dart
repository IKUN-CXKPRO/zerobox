import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/device/xiaomi/components/health_system.dart';
import 'package:oronbox/src/features/devices/health/health_store.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';
import 'package:oronbox/src/features/devices/health/xiaomi_health_sync_service.dart';
import 'package:oronbox/src/protocols/generated/xiaomi/wear_fitness.pb.dart'
    as pb_fitness;

void main() {
  test('health data survives local serialization', () {
    final data = XiaomiHealthData(
      daily: [
        HealthDailySummary(
          date: DateTime(2026, 8, 15),
          steps: 1234,
          calories: 321,
          distanceMeters: 987,
          heartRate: 78,
          intensity: 12,
          validStand: 8,
        ),
      ],
      sleep: [
        HealthSleepSummary(
          startedAt: DateTime(2026, 8, 14, 23),
          endedAt: DateTime(2026, 8, 15, 7),
          durationSeconds: 8 * 60 * 60,
          averageHeartRate: 61,
          averageBloodOxygen: 97,
          quality: 4,
        ),
      ],
      lastSyncedAt: DateTime(2026, 8, 15, 8),
    );

    final decoded = XiaomiHealthData.decode(data.encode());

    expect(decoded.latestDay?.steps, 1234);
    expect(decoded.latestDay?.distanceMeters, 987);
    expect(decoded.latestSleep?.durationSeconds, 8 * 60 * 60);
    expect(decoded.latestSleep?.averageBloodOxygen, 97);
    expect(decoded.lastSyncedAt, DateTime(2026, 8, 15, 8));
  });

  test(
    'preserves existing daily fields when the device returns a partial row',
    () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final store = _MemoryHealthStore(
        XiaomiHealthData(
          daily: [
            HealthDailySummary(
              date: today,
              steps: 1200,
              calories: 300,
              distanceMeters: 900,
              heartRate: 72,
              intensity: 10,
              validStand: 6,
            ),
          ],
        ),
      );
      final service = XiaomiHealthSyncService(
        system: _FakeHealthSystem(pb_fitness.BasicData(steps: 1500)),
        deviceId: 'test-device',
        store: store,
      );

      final result = await service.sync();

      expect(result.data.latestDay?.steps, 1500);
      expect(result.data.latestDay?.calories, 300);
      expect(result.data.latestDay?.distanceMeters, 900);
      expect(result.data.latestDay?.heartRate, 72);
      expect(result.data.latestDay?.intensity, 10);
      expect(result.data.latestDay?.validStand, 6);
    },
  );
}

class _MemoryHealthStore extends HealthStore {
  _MemoryHealthStore(this.value);

  XiaomiHealthData value;

  @override
  Future<XiaomiHealthData> read(String deviceId) async => value;

  @override
  Future<void> write(String deviceId, XiaomiHealthData data) async {
    final daily = <String, HealthDailySummary>{
      for (final item in data.daily) item.date.toIso8601String(): item,
    };
    value = XiaomiHealthData(
      daily: daily.values.toList(growable: false),
      sleep: data.sleep,
      lastSyncedAt: data.lastSyncedAt,
    );
  }
}

class _FakeHealthSystem extends XiaomiHealthSystem {
  _FakeHealthSystem(this.basic);

  final pb_fitness.BasicData basic;

  @override
  Future<pb_fitness.BasicData> fetchBasicData() async => basic;

  @override
  Future<pb_fitness.SleepResult> fetchSleepResult() async =>
      pb_fitness.SleepResult();
}
