import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/device/xiaomi/components/health_system.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';
import 'package:oronbox/src/features/devices/health/health_store.dart';
import 'package:oronbox/src/features/devices/health/xiaomi_health_sync_service.dart';

void main() {
  test('Xiaomi activity timestamps stay in local wall-clock semantics', () {
    final timestamp = xiaomiActivityTimestamp(1_787_472_000);

    expect(timestamp.isUtc, isFalse);
    expect(timestamp.millisecondsSinceEpoch, 1_787_472_000 * 1000);
  });

  test('health data survives the rewritten local serialization', () {
    final data = XiaomiHealthData(
      daily: [
        HealthDailySummary(
          date: DateTime(2026, 8, 15),
          steps: 1234,
          activeCalories: 321,
          averageHeartRate: 78,
          averageStress: 24,
          averageBloodOxygen: 97,
          standingBitmap: 0x15,
          vitalityCurrent: 42,
        ),
      ],
      samples: [
        HealthSample(
          timestamp: DateTime(2026, 8, 15, 8),
          metric: XiaomiHealthMetric.heartRate,
          value: 78,
        ),
      ],
      sleep: [
        HealthSleepSummary(
          startedAt: DateTime(2026, 8, 14, 23),
          endedAt: DateTime(2026, 8, 15, 7),
          durationSeconds: 8 * 60 * 60,
          averageHeartRate: 61,
          averageBloodOxygen: 97,
          stages: [
            HealthSleepStageSegment(
              startedAt: DateTime(2026, 8, 15, 0),
              endedAt: DateTime(2026, 8, 15, 1),
              kind: HealthSleepStageKind.deep,
            ),
          ],
        ),
      ],
      capabilities: const XiaomiHealthCapabilities(
        heartRate: true,
        bloodOxygen: true,
        stress: true,
        vitality: true,
        sleep: true,
      ),
      lastSyncedAt: DateTime(2026, 8, 15, 8),
    );

    final decoded = XiaomiHealthData.decode(data.encode());

    expect(decoded.latestDay?.steps, 1234);
    expect(decoded.latestDay?.standingHours, 3);
    expect(decoded.samplesFor(XiaomiHealthMetric.heartRate), hasLength(1));
    expect(decoded.latestSleep?.durationSeconds, 8 * 60 * 60);
    expect(decoded.latestSleep?.stages.single.kind, HealthSleepStageKind.deep);
    expect(decoded.capabilities.vitality, isTrue);
    expect(decoded.lastSyncedAt, DateTime(2026, 8, 15, 8));
  });

  test(
    'uses recent valid measurements and fills activity from detail samples',
    () {
      final data = XiaomiHealthData(
        samples: [
          HealthSample(
            timestamp: DateTime(2026, 8, 21, 8),
            metric: XiaomiHealthMetric.activity,
            value: 100,
          ),
          HealthSample(
            timestamp: DateTime(2026, 8, 21, 10),
            metric: XiaomiHealthMetric.activity,
            value: 200,
          ),
          HealthSample(
            timestamp: DateTime(2026, 8, 21, 8),
            metric: XiaomiHealthMetric.activeCalories,
            value: 20,
          ),
          HealthSample(
            timestamp: DateTime(2026, 8, 21, 10),
            metric: XiaomiHealthMetric.activeCalories,
            value: 50,
          ),
          HealthSample(
            timestamp: DateTime(2026, 8, 21, 9),
            metric: XiaomiHealthMetric.heartRate,
            value: 255,
          ),
          HealthSample(
            timestamp: DateTime(2026, 8, 21, 10),
            metric: XiaomiHealthMetric.heartRate,
            value: 79,
          ),
        ],
      );

      expect(data.latestSample(XiaomiHealthMetric.heartRate)?.value, 79);
      expect(data.activitySummary?.steps, 300);
      expect(data.activitySummary?.activeCalories, 70);
      expect(data.activitySummary?.standingHours, 2);
    },
  );

  test(
    'sync stores Gadgetbridge-style summary and timestamped samples',
    () async {
      final store = _MemoryHealthStore(const XiaomiHealthData());
      final service = XiaomiHealthSyncService(
        system: _FakeHealthSystem(
          XiaomiActivityFileSyncResult(
            daily: [
              XiaomiActivityDailyRecord(
                date: DateTime(2026, 8, 15),
                steps: 1500,
                activeCalories: 300,
                averageHeartRate: 72,
                averageStress: 18,
                averageBloodOxygen: 97,
                vitalityCurrent: 36,
              ),
            ],
            samples: [
              XiaomiActivitySampleRecord(
                timestamp: DateTime(2026, 8, 15, 10),
                heartRate: 72,
                bloodOxygen: 97,
                stress: 18,
                activeCalories: 12,
              ),
            ],
            sleep: const [],
            workouts: const [],
            filesReceived: 2,
          ),
        ),
        deviceId: 'test-device',
        store: store,
      );

      final result = await service.sync();

      expect(result.updatedDaily, isTrue);
      expect(result.updatedSamples, isTrue);
      expect(result.data.latestDay?.steps, 1500);
      expect(result.data.samplesFor(XiaomiHealthMetric.stress), hasLength(1));
      expect(
        result.data.samplesFor(XiaomiHealthMetric.activeCalories),
        hasLength(1),
      );
      expect(result.data.capabilities.vitality, isTrue);
      expect(result.data.capabilities.sleep, isFalse);
      expect(result.data.capabilities.workouts, isFalse);
    },
  );

  test(
    'does not infer health capabilities from an empty activity file',
    () async {
      final store = _MemoryHealthStore(const XiaomiHealthData());
      final service = XiaomiHealthSyncService(
        system: _FakeHealthSystem(
          const XiaomiActivityFileSyncResult(
            daily: [],
            samples: [],
            sleep: [],
            workouts: [],
            filesReceived: 1,
          ),
        ),
        deviceId: 'test-device',
        store: store,
      );

      final result = await service.sync();

      expect(result.data.capabilities.heartRate, isFalse);
      expect(result.data.capabilities.bloodOxygen, isFalse);
      expect(result.data.capabilities.stress, isFalse);
      expect(result.data.capabilities.vitality, isFalse);
      expect(result.data.capabilities.sleep, isFalse);
      expect(result.data.capabilities.workouts, isFalse);
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
    value = data;
  }
}

class _FakeHealthSystem extends XiaomiHealthSystem {
  _FakeHealthSystem(this.result);

  final XiaomiActivityFileSyncResult result;

  @override
  Future<XiaomiActivityFileSyncResult> syncActivityFiles() async => result;
}
