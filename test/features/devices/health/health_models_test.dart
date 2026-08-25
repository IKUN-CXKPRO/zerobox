import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/device/xiaomi/components/health_system.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';
import 'package:oronbox/src/features/devices/health/health_store.dart';
import 'package:oronbox/src/features/devices/health/xiaomi_health_sync_service.dart';
import 'package:oronbox/src/protocols/generated/xiaomi/wear_fitness.pb.dart'
    as pb_fitness;

void main() {
  test('Xiaomi activity timestamps stay in local wall-clock semantics', () {
    const encodedSeconds = 1_787_472_000;
    final timestamp = xiaomiActivityTimestamp(encodedSeconds);
    final encodedWallClock = DateTime.fromMillisecondsSinceEpoch(
      encodedSeconds * 1000,
      isUtc: true,
    );

    expect(timestamp.isUtc, isFalse);
    expect(
      timestamp,
      DateTime(
        encodedWallClock.year,
        encodedWallClock.month,
        encodedWallClock.day,
        encodedWallClock.hour,
        encodedWallClock.minute,
        encodedWallClock.second,
      ),
    );
  });

  test('parses Vela daily-type-9 high and low heart-rate records', () {
    const startedSeconds = 1_787_472_000;
    const endedSeconds = startedSeconds + 5 * 60;
    final body = BytesBuilder();

    void u8(int value) => body.addByte(value);
    void u16(int value) {
      final bytes = ByteData(2)..setUint16(0, value, Endian.little);
      body.add(bytes.buffer.asUint8List());
    }

    void u32(int value) => body.add(_u32(value));

    u32(startedSeconds);
    u32(endedSeconds);
    u8(1); // HR_HIGH
    u16(120); // configured threshold
    u16(2); // two samples in this segment
    u32(startedSeconds + 60);
    u8(125);
    u32(startedSeconds + 120);
    u8(121);

    u32(startedSeconds + 10 * 60);
    u32(startedSeconds + 15 * 60);
    u8(2); // HR_LOW
    u16(45);
    u16(1);
    u32(startedSeconds + 11 * 60);
    u8(42);

    u32(startedSeconds + 20 * 60);
    u32(startedSeconds + 25 * 60);
    u8(3); // SPO2_LOW
    u16(90);
    u16(1);
    u32(startedSeconds + 21 * 60);
    u8(88);

    u32(startedSeconds + 30 * 60);
    u32(startedSeconds + 35 * 60);
    u8(4); // STRESS_HIGH
    u16(80);
    u16(1);
    u32(startedSeconds + 31 * 60);
    u8(82);

    u32(startedSeconds + 40 * 60);
    u32(startedSeconds + 45 * 60);
    u8(5); // ABNORMAL_FIB / heart-health irregular heartbeat
    u16(0);
    u16(1);
    u32(startedSeconds + 41 * 60);
    u8(0);

    // dailyType=9, v1: the native parser has a zero-byte validity header, so
    // the first abnormal record starts immediately after the 7-byte ID.
    final prefix = <int>[
      ..._u32(startedSeconds),
      0,
      1,
      9 << 2,
      ...body.toBytes(),
    ];
    final crc = _crc32(Uint8List.fromList(prefix));
    final file = Uint8List.fromList([...prefix, ..._u32(crc)]);
    final records = XiaomiHealthSystem()
        .parseActivityAbnormalHeartRateFileForTesting(file);

    expect(records, hasLength(3));
    expect(records[0].kind, XiaomiActivityAbnormalHeartRateKind.high);
    expect(records[0].threshold, 120);
    expect(records[0].value, 125);
    expect(records[0].timestamp, xiaomiActivityTimestamp(startedSeconds + 60));
    expect(records[0].startedAt, xiaomiActivityTimestamp(startedSeconds));
    expect(records[2].kind, XiaomiActivityAbnormalHeartRateKind.low);
    expect(records[2].threshold, 45);
    expect(records[2].value, 42);

    final abnormalHealthRecords = XiaomiHealthSystem()
        .parseActivityAbnormalHealthFileForTesting(file);
    expect(abnormalHealthRecords, hasLength(6));
    expect(
      abnormalHealthRecords[3].kind,
      XiaomiActivityAbnormalHealthKind.lowBloodOxygen,
    );
    expect(abnormalHealthRecords[3].value, 88);
    expect(abnormalHealthRecords[3].threshold, 90);
    expect(
      abnormalHealthRecords[4].kind,
      XiaomiActivityAbnormalHealthKind.highStress,
    );
    expect(abnormalHealthRecords[4].value, 82);
    expect(
      abnormalHealthRecords[5].kind,
      XiaomiActivityAbnormalHealthKind.irregularHeartbeat,
    );
    expect(abnormalHealthRecords[5].value, isNull);
    expect(
      abnormalHealthRecords[5].startedAt,
      xiaomiActivityTimestamp(startedSeconds + 40 * 60),
    );
    expect(
      abnormalHealthRecords[5].endedAt,
      xiaomiActivityTimestamp(startedSeconds + 45 * 60),
    );
  });

  test('parses the Mi Fitness v5 sleep record and stage packets', () {
    const startedSeconds = 1_787_472_000;
    const endedSeconds = startedSeconds + 7 * 60 * 60;
    final body = BytesBuilder();

    void u8(int value) => body.addByte(value);
    void u16(int value) {
      final bytes = ByteData(2)..setUint16(0, value, Endian.little);
      body.add(bytes.buffer.asUint8List());
    }

    void u32(int value) {
      final bytes = ByteData(4)..setUint32(0, value, Endian.little);
      body.add(bytes.buffer.asUint8List());
    }

    u8(1); // sleepFull
    u32(startedSeconds);
    u32(endedSeconds);
    u8(82); // sleep quality
    u8(91); // sleep efficiency
    u32(7 * 60 * 60); // asleep duration
    u32(8 * 60 * 60); // in-bed duration
    u32(startedSeconds - 15 * 60);
    u32(endedSeconds + 15 * 60);

    u16(60); // heart-rate interval, seconds
    u16(2);
    u32(startedSeconds);
    u8(60);
    u8(70);
    u16(60); // blood-oxygen interval, seconds
    u16(2);
    u32(startedSeconds);
    u8(96);
    u8(97);

    u16(300); // snore interval, seconds
    u16(0); // no snore samples in this fixture

    void packetHeader({
      required int timestamp,
      required int type,
      required int dataLength,
    }) {
      body.add(const [0xfb, 0xfa, 0xfc, 0xff]);
      u8(17);
      final timestampBytes = ByteData(8)
        ..setUint64(0, timestamp, Endian.little);
      body.add(timestampBytes.buffer.asUint8List());
      u8(0); // parity
      u8(type);
      final lengthBytes = ByteData(2)..setUint16(0, dataLength, Endian.big);
      body.add(lengthBytes.buffer.asUint8List());
    }

    packetHeader(timestamp: startedSeconds, type: 16, dataLength: 13);
    u8(0x11); // sleep index and wake count
    void packetU16(int value) {
      final bytes = ByteData(2)..setUint16(0, value, Endian.big);
      body.add(bytes.buffer.asUint8List());
    }

    packetU16(420); // total sleep minutes
    packetU16(30); // awake minutes
    packetU16(120); // light minutes
    packetU16(90); // REM minutes
    packetU16(180); // deep minutes
    u8(0x14); // has REM and device stages
    u8(0); // reserved duration

    packetHeader(
      timestamp: startedSeconds + (420 + 30) * 60,
      type: 16,
      dataLength: 13,
    );
    u8(0x20); // a second, indexed sleep summary
    packetU16(30); // total sleep minutes
    packetU16(5); // awake minutes
    packetU16(20); // light minutes
    packetU16(0); // REM minutes
    packetU16(10); // deep minutes
    u8(0x04); // device stages, no REM
    u8(0); // reserved duration

    packetHeader(timestamp: startedSeconds, type: 17, dataLength: 4);
    packetU16(0x203c); // deep, next change in 60 minutes
    packetU16(0x303c); // light, next change in 60 minutes

    final prefix = <int>[
      ..._u32(startedSeconds),
      0, // reserved byte after the seven-byte file id
      5, // v5
      8 << 2, // all-day sleep report
      0, // no encryption/compression
      0xff,
      0xe0, // v5 validity: fixed fields, HR, SpO2 and snore
      ...body.toBytes(),
    ];
    final crc = _crc32(Uint8List.fromList(prefix));
    final file = Uint8List.fromList([...prefix, ..._u32(crc)]);
    final system = XiaomiHealthSystem();
    final records = system.parseActivitySleepFilesForTesting(file);
    final parsed = system.parseActivitySleepFileForTesting(file);

    expect(parsed, isNotNull);
    expect(records, hasLength(2));
    expect(records.first.sleepIndex, 1);
    expect(records.last.sleepIndex, 2);
    expect(parsed!.durationSeconds, 7 * 60 * 60);
    expect(parsed.startedAt, xiaomiActivityTimestamp(startedSeconds));
    // The device type-16 summary includes the 30-minute awake interval in
    // the report end, while durationSeconds remains sleep duration.
    expect(
      parsed.endedAt,
      xiaomiActivityTimestamp(startedSeconds + (420 + 30) * 60),
    );
    expect(parsed.sleepEfficiency, 91);
    expect(parsed.bedDurationSeconds, 8 * 60 * 60);
    expect(parsed.averageHeartRate, 65);
    expect(parsed.averageBloodOxygen, 97);
    expect(parsed.minimumHeartRate, 60);
    expect(parsed.maximumHeartRate, 70);
    expect(parsed.minimumBloodOxygen, 96);
    expect(parsed.maximumBloodOxygen, 97);
    expect(parsed.averageHrv, isNull);
    expect(parsed.hrvPoints, isEmpty);
    expect(parsed.durationSeconds, 420 * 60);
    expect(parsed.awakeDurationSeconds, 30 * 60);
    expect(parsed.lightSleepDurationSeconds, 120 * 60);
    expect(parsed.deepSleepDurationSeconds, 180 * 60);
    expect(parsed.remSleepDurationSeconds, 90 * 60);
    expect(parsed.sleepIndex, 1);
    expect(parsed.wakeCount, 1);
    expect(parsed.hasRem, true);
    expect(parsed.hasStage, true);
    expect(parsed.stages, hasLength(2));
    expect(parsed.stages.first.stage, 2);
    expect(parsed.stages.last.stage, 4);
    expect(
      parsed.stages.first.endedAt,
      xiaomiActivityTimestamp(startedSeconds + 60 * 60),
    );
    expect(
      parsed.stages.last.timestamp,
      xiaomiActivityTimestamp(startedSeconds + 60 * 60),
    );
    expect(
      parsed.stages.last.endedAt,
      xiaomiActivityTimestamp(startedSeconds + 120 * 60),
    );
  });

  test('parses the Mi Fitness v6 HRV summary and sample series', () {
    const startedSeconds = 1_787_472_000;
    final body = BytesBuilder();

    void u8(int value) => body.addByte(value);

    void u16(int value) {
      final bytes = ByteData(2)..setUint16(0, value, Endian.little);
      body.add(bytes.buffer.asUint8List());
    }

    void u16be(int value) {
      final bytes = ByteData(2)..setUint16(0, value, Endian.big);
      body.add(bytes.buffer.asUint8List());
    }

    void u32(int value) {
      final bytes = ByteData(4)..setUint32(0, value, Endian.little);
      body.add(bytes.buffer.asUint8List());
    }

    void packetHeader({
      required int timestamp,
      required int type,
      required int dataLength,
    }) {
      body.add(const [0xfb, 0xfa, 0xfc, 0xff]);
      u8(17);
      final timestampBytes = ByteData(8)
        ..setUint64(0, timestamp, Endian.little);
      body.add(timestampBytes.buffer.asUint8List());
      u8(0);
      u8(type);
      final lengthBytes = ByteData(2)..setUint16(0, dataLength, Endian.big);
      body.add(lengthBytes.buffer.asUint8List());
    }

    u8(1); // sleepFull
    u32(startedSeconds);
    u32(startedSeconds + 7 * 60 * 60);
    u8(82); // sleep quality
    u8(91); // sleep efficiency
    u32(7 * 60 * 60); // asleep duration
    u32(8 * 60 * 60); // in-bed duration
    u32(startedSeconds - 15 * 60);
    u32(startedSeconds + 7 * 60 * 60 + 15 * 60);

    // v6 HRV summary fields from full_day_sleep_report_v6.json.
    u16(42); // average
    u16(8); // standard deviation
    u16(40); // median
    u16(24); // lower percentile
    u16(62); // upper percentile
    u16(39); // middle percentile
    u32(startedSeconds + 60 * 60); // HRV summary timestamp
    u16(70); // max
    u16(18); // min
    u16(55); // baseline max
    u16(25); // baseline min

    u16(60); // heart-rate interval
    u16(2);
    u32(startedSeconds);
    u8(60);
    u8(70);
    u16(60); // blood-oxygen interval
    u16(2);
    u32(startedSeconds);
    u8(96);
    u8(97);
    u16(300); // HRV interval
    u16(3);
    u32(startedSeconds + 5 * 60);
    u16(40);
    u16(44);
    u16(48);
    u16(300); // snore interval
    u16(0);

    // Two summaries in one type-16 payload exercise the native gap walk.
    packetHeader(timestamp: startedSeconds, type: 16, dataLength: 26);
    u8(0x11); // sleep index 1, one wake
    u16be(420); // sleep minutes
    u16be(30); // awake minutes
    u16be(120); // light minutes
    u16be(90); // REM minutes
    u16be(180); // deep minutes
    u8(0x14); // has REM and device stages
    u8(5); // gap before the next summary
    u8(0x20); // sleep index 2, no wakes
    u16be(30);
    u16be(5);
    u16be(20);
    u16be(0);
    u16be(10);
    u8(0x04); // device stages, no REM
    u8(0);

    final prefix = <int>[
      ..._u32(startedSeconds),
      0,
      6, // v6
      8 << 2, // all-day sleep report
      0,
      0xff,
      0xff,
      0xfe, // all v6 fields except the reserved validity bit
      ...body.toBytes(),
    ];
    final crc = _crc32(Uint8List.fromList(prefix));
    final file = Uint8List.fromList([...prefix, ..._u32(crc)]);
    final system = XiaomiHealthSystem();
    final records = system.parseActivitySleepFilesForTesting(file);
    final parsed = system.parseActivitySleepFileForTesting(file);

    expect(records, hasLength(2));
    expect(parsed, isNotNull);
    expect(parsed!.averageHrv, 42);
    expect(parsed.hrvStandardDeviation, 8);
    expect(parsed.hrvMedian, 40);
    expect(parsed.hrvLowerQuantile, 24);
    expect(parsed.hrvMiddleQuantile, 39);
    expect(parsed.hrvUpperQuantile, 62);
    expect(
      parsed.hrvTimestamp,
      xiaomiActivityTimestamp(startedSeconds + 60 * 60),
    );
    expect(parsed.hrvMax, 70);
    expect(parsed.hrvMin, 18);
    expect(parsed.hrvBaselineMax, 55);
    expect(parsed.hrvBaselineMin, 25);
    expect(parsed.hrvPoints, hasLength(3));
    expect(parsed.hrvPoints.first.value, 40);
    expect(
      parsed.hrvPoints.first.timestamp,
      xiaomiActivityTimestamp(startedSeconds + 5 * 60),
    );
    expect(records.last.hrvPoints, isEmpty);
    expect(parsed.averageHeartRate, 65);
    expect(parsed.averageBloodOxygen, 97);
    expect(parsed.sleepIndex, 1);
    expect(parsed.awakeDurationSeconds, 30 * 60);
  });

  test('uses the v6 validity positions for heart rate without HRV', () {
    const startedSeconds = 1_787_472_000;
    final body = BytesBuilder();

    void u8(int value) => body.addByte(value);

    void u16(int value) {
      final bytes = ByteData(2)..setUint16(0, value, Endian.little);
      body.add(bytes.buffer.asUint8List());
    }

    void u32(int value) {
      final bytes = ByteData(4)..setUint32(0, value, Endian.little);
      body.add(bytes.buffer.asUint8List());
    }

    u8(1);
    u32(startedSeconds);
    u32(startedSeconds + 7 * 60 * 60);
    u8(82);
    u8(91);
    u32(7 * 60 * 60);
    u32(8 * 60 * 60);
    u32(startedSeconds - 15 * 60);
    u32(startedSeconds + 7 * 60 * 60 + 15 * 60);

    // The v6 fixed HRV summary block is present in the body even when all
    // eleven HRV summary validity bits are clear.
    for (var index = 0; index < 6; index++) {
      u16(0);
    }
    u32(0);
    for (var index = 0; index < 4; index++) {
      u16(0);
    }

    u16(60);
    u16(2);
    u32(startedSeconds);
    u8(60);
    u8(70);
    u16(60);
    u16(2);
    u32(startedSeconds);
    u8(96);
    u8(97);
    u16(300); // snore block is valid, but has no records
    u16(0);

    final prefix = <int>[
      ..._u32(startedSeconds),
      0,
      6,
      8 << 2,
      0,
      0xff, // fixed fields
      0,
      0x1a, // heart rate, blood oxygen, and snore only
      ...body.toBytes(),
    ];
    final crc = _crc32(Uint8List.fromList(prefix));
    final file = Uint8List.fromList([...prefix, ..._u32(crc)]);
    final parsed = XiaomiHealthSystem().parseActivitySleepFileForTesting(file);

    expect(parsed, isNotNull);
    expect(parsed!.averageHeartRate, 65);
    expect(parsed.averageBloodOxygen, 97);
    expect(parsed.averageHrv, isNull);
    expect(parsed.hrvPoints, isEmpty);
  });

  test('parses the v2 device sleep-stage file and its stage totals', () {
    const startedSeconds = 1_787_472_000;
    const endedSeconds = startedSeconds + 8 * 60 * 60;
    final body = BytesBuilder();

    void u16(int value) {
      final bytes = ByteData(2)..setUint16(0, value, Endian.little);
      body.add(bytes.buffer.asUint8List());
    }

    body.add(const [0, 0, 0, 0, 0, 0, 0]); // reserved file prefix
    u16(480); // total sleep minutes
    body.add(_u32(startedSeconds));
    body.add(_u32(endedSeconds));
    body.add(const [0, 0, 0]); // reserved
    u16(180); // deep
    u16(210); // light
    u16(60); // REM
    u16(30); // awake
    body.addByte(0); // reserved
    body.add(_u32(startedSeconds));
    body.addByte(2); // deep
    body.add(_u32(startedSeconds + 180 * 60));
    body.addByte(3); // light

    final prefix = <int>[..._u32(startedSeconds), 0, 2, 3 << 2, 0];
    prefix.addAll(body.toBytes());
    final crc = _crc32(Uint8List.fromList(prefix));
    final file = Uint8List.fromList([...prefix, ..._u32(crc)]);
    final parsed = XiaomiHealthSystem().parseActivitySleepFileForTesting(file);

    expect(parsed, isNotNull);
    expect(parsed!.durationSeconds, 480 * 60);
    expect(parsed.awakeDurationSeconds, 30 * 60);
    expect(parsed.lightSleepDurationSeconds, 210 * 60);
    expect(parsed.deepSleepDurationSeconds, 180 * 60);
    expect(parsed.remSleepDurationSeconds, 60 * 60);
    expect(parsed.stages, hasLength(2));
    expect(parsed.stages.first.stage, 2);
    expect(parsed.stages.last.stage, 3);
  });

  test('health data survives the rewritten local serialization', () {
    final data = XiaomiHealthData(
      daily: [
        HealthDailySummary(
          date: DateTime(2026, 8, 15),
          steps: 1234,
          activeCalories: 321,
          restingHeartRate: 55,
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
          awakeDurationSeconds: 20 * 60,
          lightSleepDurationSeconds: 4 * 60 * 60,
          deepSleepDurationSeconds: 2 * 60 * 60,
          remSleepDurationSeconds: 1 * 60 * 60,
          averageHrv: 42,
          hrvMin: 18,
          hrvMax: 70,
          hrvPoints: [
            HealthSleepHrvPoint(timestamp: DateTime(2026, 8, 15, 1), value: 42),
          ],
          stages: [
            HealthSleepStageSegment(
              startedAt: DateTime(2026, 8, 15, 0),
              endedAt: DateTime(2026, 8, 15, 1),
              kind: HealthSleepStageKind.deep,
            ),
          ],
        ),
      ],
      abnormalHealthRecords: [
        HealthAbnormalHealthRecord(
          timestamp: DateTime(2026, 8, 15, 9),
          value: 126,
          kind: HealthAbnormalHealthKind.highHeartRate,
          threshold: 120,
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
    expect(decoded.latestDay?.restingHeartRate, 55);
    expect(decoded.latestDay?.standingHours, 3);
    expect(decoded.samplesFor(XiaomiHealthMetric.heartRate), hasLength(1));
    expect(decoded.latestSleep?.durationSeconds, 8 * 60 * 60);
    expect(decoded.latestSleep?.deepSleepDurationSeconds, 2 * 60 * 60);
    expect(decoded.latestSleep?.averageHrv, 42);
    expect(decoded.latestSleep?.hrvPoints.single.value, 42);
    expect(decoded.latestSleep?.stages.single.kind, HealthSleepStageKind.deep);
    expect(decoded.abnormalHealthRecords.single.value, 126);
    expect(
      decoded.abnormalHealthRecords.single.kind,
      HealthAbnormalHealthKind.highHeartRate,
    );
    expect(decoded.abnormalHeartRates.single.value, 126);
    expect(decoded.capabilities.vitality, isTrue);
    expect(decoded.lastSyncedAt, DateTime(2026, 8, 15, 8));
  });

  test('latest sleep is selected by end time', () {
    final data = XiaomiHealthData(
      sleep: [
        HealthSleepSummary(
          startedAt: DateTime(2026, 8, 24, 23),
          endedAt: DateTime(2026, 8, 26, 8),
          durationSeconds: 9 * 60 * 60,
        ),
        HealthSleepSummary(
          startedAt: DateTime(2026, 8, 25, 12),
          endedAt: DateTime(2026, 8, 25, 14),
          durationSeconds: 2 * 60 * 60,
        ),
      ],
    );

    expect(data.latestSleep?.endedAt, DateTime(2026, 8, 26, 8));
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

  test('persists successful health files when another file fails', () async {
    final store = _MemoryHealthStore(const XiaomiHealthData());
    final service = XiaomiHealthSyncService(
      system: _FakeHealthSystem(
        XiaomiActivityFileSyncResult(
          daily: [
            XiaomiActivityDailyRecord(date: DateTime(2026, 8, 15), steps: 42),
          ],
          samples: const [],
          sleep: const [],
          workouts: const [],
          filesReceived: 1,
          failedFiles: const [
            XiaomiActivityFileFailure(
              id: '03000000000500',
              attempts: 2,
              error: 'ProtocolException: timed out',
            ),
          ],
        ),
      ),
      deviceId: 'test-device',
      store: store,
    );

    final result = await service.sync();

    expect(result.data.latestDay?.steps, 42);
    expect(result.warning, contains('1 failed activity file'));
    expect(store.value.latestDay?.steps, 42);
  });

  test(
    'does not turn a missing activity file into a successful no-op',
    () async {
      final previous = XiaomiHealthData(
        sleep: [
          HealthSleepSummary(
            startedAt: DateTime(2026, 8, 14, 23),
            endedAt: DateTime(2026, 8, 15, 7),
            durationSeconds: 8 * 60 * 60,
          ),
        ],
        lastSyncedAt: DateTime(2026, 8, 15, 8),
      );
      final store = _MemoryHealthStore(previous);
      final service = XiaomiHealthSyncService(
        system: _FakeHealthSystem(
          const XiaomiActivityFileSyncResult(
            daily: [],
            samples: [],
            sleep: [],
            workouts: [],
            filesReceived: 0,
          ),
        ),
        deviceId: 'test-device',
        store: store,
      );

      await expectLater(service.sync(), throwsA(isA<StateError>()));
      expect(store.value, previous);
    },
  );

  test(
    'propagates activity-file failures without requesting sleep again',
    () async {
      final store = _MemoryHealthStore(const XiaomiHealthData());
      final system = _FakeHealthSystem(
        const XiaomiActivityFileSyncResult(
          daily: [],
          samples: [],
          sleep: [],
          workouts: [],
          filesReceived: 0,
        ),
        activityError: StateError('activity transfer failed'),
      );
      final service = XiaomiHealthSyncService(
        system: system,
        deviceId: 'test-device',
        store: store,
      );

      await expectLater(service.sync(), throwsA(isA<StateError>()));
      expect(system.sleepRequests, 0);
      expect(store.value, const XiaomiHealthData());
    },
  );

  test(
    'uses the protocol sleep summary when no sleep activity file exists',
    () async {
      const startedSeconds = 1_787_472_000;
      const endedSeconds = startedSeconds + 8 * 60 * 60;
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
          sleepResult: pb_fitness.SleepResult(
            sectionList: [
              pb_fitness.SleepResult_Section(
                sleepTimestamp: startedSeconds,
                wakeupTimestamp: endedSeconds,
                validSleepTime: 7 * 60 * 60,
                averageHeartRate: 61,
                averageBloodOxygen: 96,
                extraData: pb_fitness.SleepResult_ExtraData(
                  sleepQuality: 82,
                  sleepEfficiency: 91,
                ),
              ),
            ],
          ),
        ),
        deviceId: 'test-device',
        store: store,
      );

      final result = await service.sync();
      final sleep = result.data.latestSleep;

      expect(sleep, isNotNull);
      expect(sleep!.startedAt, xiaomiActivityTimestamp(startedSeconds));
      expect(sleep.endedAt, xiaomiActivityTimestamp(endedSeconds));
      expect(sleep.durationSeconds, 7 * 60 * 60);
      expect(sleep.averageHeartRate, 61);
      expect(sleep.averageBloodOxygen, 96);
      expect(sleep.quality, 82);
      expect(sleep.sleepEfficiency, 91);
      expect(sleep.stages, isEmpty);
      expect(sleep.hrvPoints, isEmpty);
    },
  );
}

List<int> _u32(int value) {
  final bytes = ByteData(4)..setUint32(0, value, Endian.little);
  return bytes.buffer.asUint8List();
}

int _crc32(Uint8List data) {
  var crc = 0xffffffff;
  for (final byte in data) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
    }
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
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
  _FakeHealthSystem(this.result, {this.sleepResult, this.activityError});

  final XiaomiActivityFileSyncResult result;
  final pb_fitness.SleepResult? sleepResult;
  final Object? activityError;
  var sleepRequests = 0;

  @override
  Future<XiaomiActivityFileSyncResult> syncActivityFiles() async {
    if (activityError != null) throw activityError!;
    return result;
  }

  @override
  Future<pb_fitness.SleepResult> fetchSleepResult({Duration? timeout}) async {
    sleepRequests++;
    return sleepResult ?? pb_fitness.SleepResult();
  }
}
