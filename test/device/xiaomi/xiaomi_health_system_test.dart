import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/core/models/xiaomi_health_models.dart';
import 'package:oronbox/src/device/core/entity.dart';
import 'package:oronbox/src/device/core/event_bus.dart';
import 'package:oronbox/src/device/core/transport.dart';
import 'package:oronbox/src/device/xiaomi/components/health_system.dart';
import 'package:oronbox/src/device/xiaomi/components/request_pool_system.dart';
import 'package:oronbox/src/device/xiaomi/components/xiaomi_device_component.dart';
import 'package:oronbox/src/protocols/generated/xiaomi/wear.pb.dart' as pb;
import 'package:oronbox/src/protocols/generated/xiaomi/wear_fitness.pb.dart'
    as pb_fitness;
import 'package:oronbox/src/protocols/generated/xiaomi/wear_system.pb.dart'
    as pb_system;

void main() {
  test('health state survives daemon JSON round trip', () {
    const original = XiaomiHealthState(
      isCharging: true,
      isWearing: false,
      isSleeping: true,
      battery: 91,
      chargingStatus: 1,
      wearingStatus: 2,
      sleepingStatus: 1,
      warningStatus: 4,
      sportType: 3,
      sportState: 1,
    );
    expect(XiaomiHealthState.fromJson(original.toJson()), original);
  });

  test('maps the basic snapshot to health and battery events', () async {
    final eventBus = DeviceEventBus();
    final entity = _entity(eventBus);
    final system = XiaomiHealthSystem();
    entity.registerSystem(system);

    final healthEvent = eventBus.stream
        .where((event) => event is XiaomiHealthStateUpdated)
        .cast<XiaomiHealthStateUpdated>()
        .first;
    final batteryEvent = eventBus.stream
        .where((event) => event is BatteryUpdated)
        .cast<BatteryUpdated>()
        .first;

    system.onWearPacket(
      pb.WearPacket(
        type: pb.WearPacket_Type.SYSTEM,
        id: pb_system.System_SystemID.GET_BASIC_STATUS.value,
        system: pb_system.System(
          presentBasicStatus: pb_system.BasicStatus_Present(
            isCharging: true,
            battery: 87,
            isWearing: true,
            isSleeping: false,
          ),
        ),
      ),
    );

    final health = await healthEvent;
    final battery = await batteryEvent;
    expect(
      health.health,
      const XiaomiHealthState(
        isCharging: true,
        isWearing: true,
        isSleeping: false,
        battery: 87,
        chargingStatus: 1,
        wearingStatus: 1,
        sleepingStatus: 2,
      ),
    );
    expect(battery.battery.capacity, 87);
    eventBus.dispose();
  });

  test('maps partial reports without losing the other health states', () async {
    final eventBus = DeviceEventBus();
    final entity = _entity(eventBus);
    final system = XiaomiHealthSystem();
    entity.registerSystem(system);

    final firstEvent = eventBus.stream
        .where((event) => event is XiaomiHealthStateUpdated)
        .cast<XiaomiHealthStateUpdated>()
        .first;
    system.onWearPacket(
      pb.WearPacket(
        type: pb.WearPacket_Type.SYSTEM,
        id: pb_system.System_SystemID.GET_BASIC_STATUS.value,
        system: pb_system.System(
          presentBasicStatus: pb_system.BasicStatus_Present(
            isCharging: false,
            isWearing: true,
            isSleeping: false,
          ),
        ),
      ),
    );
    await firstEvent;
    final event = eventBus.stream
        .where((event) => event is XiaomiHealthStateUpdated)
        .cast<XiaomiHealthStateUpdated>()
        .first;
    system.onWearPacket(
      pb.WearPacket(
        type: pb.WearPacket_Type.SYSTEM,
        id: pb_system.System_SystemID.REPORT_BASIC_STATUS.value,
        system: pb_system.System(
          reportBasicStatus: pb_system.BasicStatus_Report(
            sleeping: pb_system.BasicStatus_Sleeping.IN,
          ),
        ),
      ),
    );

    final health = await event;
    expect(health.health.isWearing, true);
    expect(health.health.isSleeping, true);
    expect(health.health.sleepingStatus, 1);
    eventBus.dispose();
  });

  test('exposes typed streams for fitness payloads', () async {
    final eventBus = DeviceEventBus();
    final entity = _entity(eventBus);
    final system = XiaomiHealthSystem();
    entity.registerSystem(system);
    final basicData = system.basicDataReports.first;
    final sleepResult = system.sleepResults.first;
    final sensorData = system.sensorReports.first;
    final heartRate = system.heartRateReports.first;
    final bloodOxygen = system.bloodOxygenReports.first;

    system.onWearPacket(
      pb.WearPacket(
        type: pb.WearPacket_Type.FITNESS,
        id: pb_fitness.Fitness_FitnessID.REPORT_BASIC_DATA.value,
        fitness: pb_fitness.Fitness(
          basicData: pb_fitness.BasicData(
            steps: 1200,
            calories: 73,
            heartRate: 72,
          ),
        ),
      ),
    );
    system.onWearPacket(
      pb.WearPacket(
        type: pb.WearPacket_Type.FITNESS,
        id: pb_fitness.Fitness_FitnessID.SYNC_SLEEP_RESULT.value,
        fitness: pb_fitness.Fitness(
          sleepResult: pb_fitness.SleepResult(
            sectionList: [
              pb_fitness.SleepResult_Section(
                averageHeartRate: 61,
                averageBloodOxygen: 96,
              ),
            ],
          ),
        ),
      ),
    );
    system.onWearPacket(
      pb.WearPacket(
        type: pb.WearPacket_Type.FITNESS,
        id: pb_fitness.Fitness_FitnessID.WEAR_SENSOR_DATA.value,
        fitness: pb_fitness.Fitness(
          wearSensorData: pb_fitness.WearSensorData(),
        ),
      ),
    );

    expect((await basicData).steps, 1200);
    expect(await heartRate, 72);
    expect(await bloodOxygen, 96);
    expect(await sleepResult, isA<pb_fitness.SleepResult>());
    expect(await sensorData, isA<pb_fitness.WearSensorData>());
    await entity.dispose();
    eventBus.dispose();
  });

  test('matches fitness requests by response id', () async {
    final eventBus = DeviceEventBus();
    final transport = _UnusedTransport();
    final entity = DeviceEntity(
      id: 'device-a',
      kind: 'xiaomi',
      transport: transport,
      eventBus: eventBus,
    );
    final component = XiaomiDeviceComponent(transport: transport, sppV1: true);
    entity.set(component);
    entity.registerSystem(XiaomiRequestPoolSystem());
    final system = XiaomiHealthSystem();
    entity.registerSystem(system);

    final future = system.fetchBasicData();
    var completed = false;
    future.then((_) => completed = true);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    component.requestPool.onPacket(
      pb.WearPacket(
        type: pb.WearPacket_Type.FITNESS,
        id: pb_fitness.Fitness_FitnessID.GET_HEART_RATE_MONITOR.value,
        fitness: pb_fitness.Fitness(
          basicData: pb_fitness.BasicData(steps: 1, calories: 1),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(completed, false);

    component.requestPool.onPacket(
      pb.WearPacket(
        type: pb.WearPacket_Type.FITNESS,
        id: pb_fitness.Fitness_FitnessID.GET_BASIC_DATA.value,
        fitness: pb_fitness.Fitness(
          basicData: pb_fitness.BasicData(steps: 42, calories: 7),
        ),
      ),
    );
    expect((await future).steps, 42);
    await entity.dispose();
    eventBus.dispose();
  });

  test(
    'receives and validates an activity file on the dedicated channel',
    () async {
      final eventBus = DeviceEventBus();
      final transport = _RecordingTransport();
      final entity = DeviceEntity(
        id: 'device-a',
        kind: 'xiaomi-spp-v1',
        transport: transport,
        eventBus: eventBus,
      );
      final component = XiaomiDeviceComponent(
        transport: transport,
        sppV1: true,
      );
      entity.set(component);
      entity.registerSystem(XiaomiRequestPoolSystem());
      final system = XiaomiHealthSystem();
      entity.registerSystem(system);

      final fileId = Uint8List.fromList(const [1, 0, 0, 0, 0, 5, 0]);
      final sync = system.syncActivityFiles();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      component.requestPool.onPacket(
        pb.WearPacket(
          type: pb.WearPacket_Type.FITNESS,
          id: pb_fitness.Fitness_FitnessID.GET_TODAY_FITNESS_IDS.value,
          fitness: pb_fitness.Fitness(ids: fileId),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      component.requestPool.onPacket(
        pb.WearPacket(
          type: pb.WearPacket_Type.FITNESS,
          id: pb_fitness.Fitness_FitnessID.GET_HISTORY_FITNESS_IDS.value,
          fitness: pb_fitness.Fitness(ids: fileId),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final body = Uint8List.fromList([...fileId, 0, 0, 0, 0, 0]);
      final withCrc = Uint8List.fromList([...body, ..._crc32(body)]);
      final chunk = Uint8List(withCrc.length + 4);
      final header = ByteData.sublistView(chunk);
      header.setUint16(0, 1, Endian.little);
      header.setUint16(2, 1, Endian.little);
      chunk.setRange(4, chunk.length, withCrc);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      system.onActivityPayload(chunk);

      final result = await sync;
      expect(result.filesReceived, 1);
      expect(transport.sent, isNotEmpty);
      await entity.dispose();
      eventBus.dispose();
    },
  );
}

DeviceEntity _entity(DeviceEventBus eventBus) => DeviceEntity(
  id: 'device-a',
  kind: 'xiaomi',
  transport: _UnusedTransport(),
  eventBus: eventBus,
);

class _UnusedTransport implements Transport {
  @override
  String get deviceId => 'device-a';

  @override
  String get deviceName => 'Device A';

  @override
  Stream<Uint8List> get incomingData => const Stream.empty();

  @override
  Stream<bool> get connectionState => const Stream.empty();

  @override
  Future<void> send(Uint8List data) async {}

  @override
  Future<void> dispose() async {}
}

class _RecordingTransport extends _UnusedTransport {
  final sent = <Uint8List>[];

  @override
  Future<void> send(Uint8List data) async {
    sent.add(Uint8List.fromList(data));
  }
}

List<int> _crc32(Uint8List data) {
  var crc = 0xffffffff;
  for (final byte in data) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
    }
  }
  final value = (crc ^ 0xffffffff) & 0xffffffff;
  return [
    value & 0xff,
    (value >> 8) & 0xff,
    (value >> 16) & 0xff,
    (value >> 24) & 0xff,
  ];
}
