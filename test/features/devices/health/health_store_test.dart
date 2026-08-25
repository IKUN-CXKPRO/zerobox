import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';
import 'package:oronbox/src/features/devices/health/health_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.instance.init();
    await SharedPrefsService.instance.reload();
  });

  test(
    'persists abnormal health records and prefers refreshed equal keys',
    () async {
      final store = HealthStore();
      const deviceId = 'health-store-regression';
      final day = DateTime(2026, 8, 25);
      final sampleTime = DateTime(2026, 8, 25, 8);
      final abnormalTime = DateTime(2026, 8, 25, 9);
      final abnormalStart = DateTime(2026, 8, 25, 8, 55);
      final abnormalEnd = DateTime(2026, 8, 25, 9, 5);

      await store.write(
        deviceId,
        XiaomiHealthData(
          daily: [HealthDailySummary(date: day, steps: 100)],
          samples: [
            HealthSample(
              timestamp: sampleTime,
              metric: XiaomiHealthMetric.heartRate,
              value: 70,
            ),
          ],
          abnormalHealthRecords: [
            HealthAbnormalHealthRecord(
              timestamp: abnormalTime,
              kind: HealthAbnormalHealthKind.highHeartRate,
              value: 125,
              threshold: 120,
              startedAt: abnormalStart,
              endedAt: abnormalEnd,
            ),
          ],
          lastSyncedAt: DateTime(2026, 8, 25, 10),
        ),
      );

      await store.write(
        deviceId,
        XiaomiHealthData(
          daily: [
            HealthDailySummary(date: day, steps: 250),
            HealthDailySummary(date: day, steps: 100),
          ],
          samples: [
            HealthSample(
              timestamp: sampleTime,
              metric: XiaomiHealthMetric.heartRate,
              value: 82,
            ),
            HealthSample(
              timestamp: sampleTime,
              metric: XiaomiHealthMetric.heartRate,
              value: 70,
            ),
          ],
          abnormalHealthRecords: [
            HealthAbnormalHealthRecord(
              timestamp: abnormalTime,
              kind: HealthAbnormalHealthKind.highHeartRate,
              value: 132,
              threshold: 120,
              startedAt: abnormalStart,
              endedAt: abnormalEnd,
            ),
            HealthAbnormalHealthRecord(
              timestamp: abnormalTime,
              kind: HealthAbnormalHealthKind.highHeartRate,
              value: 125,
              threshold: 120,
              startedAt: abnormalStart,
              endedAt: abnormalEnd,
            ),
          ],
          lastSyncedAt: DateTime(2026, 8, 25, 11),
        ),
      );

      final saved = await store.read(deviceId);
      expect(saved.daily.single.steps, 250);
      expect(saved.latestSample(XiaomiHealthMetric.heartRate)?.value, 82);
      expect(saved.abnormalHealthRecords, hasLength(1));
      expect(saved.abnormalHealthRecords.single.value, 132);
    },
  );
}
