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
import 'package:oronbox/src/protocols/xiaomi/packet/l2_packet.dart';
import 'package:oronbox/src/protocols/xiaomi/packet/spp_v1_packet.dart';

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

      final body = Uint8List.fromList([...fileId, 0, 0, 0, 0, 0]);
      final withCrc = Uint8List.fromList([...body, ..._crc32(body)]);
      Uint8List chunk(int number, int start, int end) {
        final value = Uint8List(end - start + 4);
        final header = ByteData.sublistView(value);
        header.setUint16(0, 2, Endian.little);
        header.setUint16(2, number, Endian.little);
        value.setRange(4, value.length, withCrc.sublist(start, end));
        return value;
      }

      await Future<void>.delayed(const Duration(milliseconds: 10));
      final codec = XiaomiSppV1Codec();
      final packets = <XiaomiSppV1Packet>[];
      for (final frame in transport.sent) {
        packets.addAll(codec.add(frame));
      }
      final protobufPackets = packets
          .where((packet) => packet.channel == XiaomiSppV1Channel.protobuf)
          .map((packet) => pb.WearPacket.fromBuffer(packet.payload))
          .toList(growable: false);
      final fileRequestIndex = protobufPackets.indexWhere(
        (packet) =>
            packet.id ==
                pb_fitness.Fitness_FitnessID.REQUEST_FITNESS_IDS.value &&
            packet.fitness.hasIds(),
      );
      final historyRequestIndex = protobufPackets.indexWhere(
        (packet) =>
            packet.id ==
            pb_fitness.Fitness_FitnessID.GET_HISTORY_FITNESS_IDS.value,
      );
      expect(fileRequestIndex, greaterThanOrEqualTo(0));
      expect(historyRequestIndex, greaterThan(fileRequestIndex));
      final fileRequests = packets
          .where((packet) => packet.channel == XiaomiSppV1Channel.protobuf)
          .map((packet) => pb.WearPacket.fromBuffer(packet.payload))
          .where(
            (packet) =>
                packet.id ==
                pb_fitness.Fitness_FitnessID.REQUEST_FITNESS_IDS.value,
          )
          .toList(growable: false);
      expect(fileRequests, hasLength(1));
      expect(fileRequests.single.fitness.hasIds(), isTrue);
      expect(fileRequests.single.fitness.ids, orderedEquals(fileId));
      expect(
        packets
            .where((packet) => packet.channel == XiaomiSppV1Channel.protobuf)
            .map((packet) => pb.WearPacket.fromBuffer(packet.payload))
            .any(
              (packet) =>
                  packet.id ==
                  pb_fitness.Fitness_FitnessID.GET_HISTORY_FITNESS_IDS.value,
            ),
        isTrue,
      );

      // The official receiver accepts only the next sequence number. Feed
      // the chunks through the real dedicated L2 channel entry point rather
      // than bypassing the transport dispatch in the test.
      system.onLayer2Packet(
        L2Channel.fileFitness,
        L2OpCode.write,
        chunk(1, 0, 8),
      );
      system.onLayer2Packet(
        L2Channel.fileFitness,
        L2OpCode.write,
        chunk(2, 8, withCrc.length),
      );

      component.requestPool.onPacket(
        pb.WearPacket(
          type: pb.WearPacket_Type.FITNESS,
          id: pb_fitness.Fitness_FitnessID.GET_HISTORY_FITNESS_IDS.value,
          fitness: pb_fitness.Fitness(ids: fileId),
        ),
      );

      final result = await sync;
      expect(result.filesReceived, 1);
      expect(transport.sent, isNotEmpty);
      await entity.dispose();
      eventBus.dispose();
    },
  );

  test(
    'buffers an activity file emitted before its request future is waiting',
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

      final fileId = Uint8List.fromList(const [2, 0, 0, 0, 0, 5, 0]);
      final body = Uint8List.fromList([...fileId, 0, 0, 0, 0, 0]);
      final withCrc = Uint8List.fromList([...body, ..._crc32(body)]);
      Uint8List chunk(int number, int start, int end) {
        final value = Uint8List(end - start + 4);
        final header = ByteData.sublistView(value);
        header.setUint16(0, 2, Endian.little);
        header.setUint16(2, number, Endian.little);
        value.setRange(4, value.length, withCrc.sublist(start, end));
        return value;
      }

      // This is the interval that used to be logged as "unsolicited" and
      // discarded. The dedicated channel still carries a complete, valid
      // file, so it can be retained until today's ID list identifies it.
      system.onLayer2Packet(
        L2Channel.fileFitness,
        L2OpCode.write,
        chunk(1, 0, 8),
      );
      system.onLayer2Packet(
        L2Channel.fileFitness,
        L2OpCode.write,
        chunk(2, 8, withCrc.length),
      );

      final sync = system.syncActivityFiles();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      component.requestPool.onPacket(
        pb.WearPacket(
          type: pb.WearPacket_Type.FITNESS,
          id: pb_fitness.Fitness_FitnessID.GET_TODAY_FITNESS_IDS.value,
          fitness: pb_fitness.Fitness(ids: fileId),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final codec = XiaomiSppV1Codec();
      final packets = <XiaomiSppV1Packet>[];
      for (final frame in transport.sent) {
        packets.addAll(codec.add(frame));
      }
      final fileRequests = packets
          .where((packet) => packet.channel == XiaomiSppV1Channel.protobuf)
          .map((packet) => pb.WearPacket.fromBuffer(packet.payload))
          .where(
            (packet) =>
                packet.id ==
                    pb_fitness.Fitness_FitnessID.REQUEST_FITNESS_IDS.value &&
                packet.fitness.hasIds(),
          )
          .toList(growable: false);
      expect(fileRequests, isEmpty);

      component.requestPool.onPacket(
        pb.WearPacket(
          type: pb.WearPacket_Type.FITNESS,
          id: pb_fitness.Fitness_FitnessID.GET_HISTORY_FITNESS_IDS.value,
          fitness: pb_fitness.Fitness(ids: Uint8List(0)),
        ),
      );
      final result = await sync;
      expect(result.filesReceived, 1);
      await entity.dispose();
      eventBus.dispose();
    },
  );

  test(
    'continues with later activity files after a file exhausts its retries',
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

      final failedId = Uint8List.fromList(const [3, 0, 0, 0, 0, 5, 0]);
      final goodId = Uint8List.fromList(const [4, 0, 0, 0, 0, 5, 0]);
      final sync = system.syncActivityFiles();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      component.requestPool.onPacket(
        pb.WearPacket(
          type: pb.WearPacket_Type.FITNESS,
          id: pb_fitness.Fitness_FitnessID.GET_TODAY_FITNESS_IDS.value,
          fitness: pb_fitness.Fitness(
            ids: Uint8List.fromList([...failedId, ...goodId]),
          ),
        ),
      );

      await _waitFor(() => _activityFileRequestCount(transport) == 1);
      await _waitFor(
        () => _hasFitnessRequest(
          transport,
          pb_fitness.Fitness_FitnessID.GET_HISTORY_FITNESS_IDS.value,
        ),
      );
      component.requestPool.onPacket(
        pb.WearPacket(
          type: pb.WearPacket_Type.FITNESS,
          id: pb_fitness.Fitness_FitnessID.GET_HISTORY_FITNESS_IDS.value,
          fitness: pb_fitness.Fitness(ids: Uint8List(0)),
        ),
      );

      // A bad sequence number fails the active transfer immediately. The
      // synchronizer should retry this file once, then move to goodId.
      system.onLayer2Packet(
        L2Channel.fileFitness,
        L2OpCode.write,
        _invalidActivityChunk(),
      );
      await _waitFor(() => _activityFileRequestCount(transport) == 2);
      system.onLayer2Packet(
        L2Channel.fileFitness,
        L2OpCode.write,
        _invalidActivityChunk(),
      );
      await _waitFor(() => _activityFileRequestCount(transport) == 3);

      for (final chunk in _validActivityFileChunks(goodId)) {
        system.onLayer2Packet(L2Channel.fileFitness, L2OpCode.write, chunk);
      }

      final result = await sync;
      expect(result.filesReceived, 1);
      expect(result.failedFiles, hasLength(1));
      expect(result.failedFiles.single.id, '03000000000500');
      expect(result.failedFiles.single.attempts, 2);
      expect(result.filesSkipped, 0);
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

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 150; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue, reason: 'condition did not become true');
}

List<pb.WearPacket> _protobufPackets(_RecordingTransport transport) {
  final codec = XiaomiSppV1Codec();
  final packets = <XiaomiSppV1Packet>[];
  for (final frame in transport.sent) {
    packets.addAll(codec.add(frame));
  }
  return packets
      .where((packet) => packet.channel == XiaomiSppV1Channel.protobuf)
      .map((packet) => pb.WearPacket.fromBuffer(packet.payload))
      .toList(growable: false);
}

int _activityFileRequestCount(_RecordingTransport transport) =>
    _protobufPackets(transport)
        .where(
          (packet) =>
              packet.id ==
                  pb_fitness.Fitness_FitnessID.REQUEST_FITNESS_IDS.value &&
              packet.fitness.hasIds() &&
              packet.fitness.ids.length == 7,
        )
        .length;

bool _hasFitnessRequest(_RecordingTransport transport, int id) =>
    _protobufPackets(transport).any((packet) => packet.id == id);

Uint8List _invalidActivityChunk() {
  final value = Uint8List(4);
  final header = ByteData.sublistView(value);
  header.setUint16(0, 2, Endian.little);
  header.setUint16(2, 2, Endian.little);
  return value;
}

List<Uint8List> _validActivityFileChunks(Uint8List id) {
  final body = Uint8List.fromList([...id, 0, 0, 0, 0, 0]);
  final data = Uint8List.fromList([...body, ..._crc32(body)]);

  Uint8List chunk(int number, int start, int end) {
    final value = Uint8List(end - start + 4);
    final header = ByteData.sublistView(value);
    header.setUint16(0, 2, Endian.little);
    header.setUint16(2, number, Endian.little);
    value.setRange(4, value.length, data.sublist(start, end));
    return value;
  }

  return [chunk(1, 0, 8), chunk(2, 8, data.length)];
}
