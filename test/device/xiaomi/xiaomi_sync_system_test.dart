import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/device/core/entity.dart';
import 'package:oronbox/src/device/core/event_bus.dart';
import 'package:oronbox/src/device/core/transport.dart';
import 'package:oronbox/src/device/xiaomi/components/sync_system.dart';
import 'package:oronbox/src/protocols/generated/xiaomi/wear.pb.dart' as pb;
import 'package:oronbox/src/protocols/generated/xiaomi/wear_system.pb.dart'
    as pb_system;

void main() {
  test('forwards an inbound wearable phone-finder request', () async {
    final eventBus = DeviceEventBus();
    final entity = DeviceEntity(
      id: 'device-a',
      kind: 'xiaomi',
      transport: _UnusedTransport(),
      eventBus: eventBus,
    );
    final system = XiaomiSyncSystem();
    entity.registerSystem(system);
    final event = eventBus.stream
        .where((value) => value is XiaomiFindPhoneRequested)
        .cast<XiaomiFindPhoneRequested>()
        .first;

    system.onWearPacket(
      pb.WearPacket(
        type: pb.WearPacket_Type.SYSTEM,
        id: pb_system.System_SystemID.FIND_PHONE.value,
        system: pb_system.System(findMode: pb_system.FindMode.FIND_START),
      ),
    );

    expect((await event).finding, isTrue);
    await entity.dispose();
    eventBus.dispose();
  });
}

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
