import 'dart:typed_data';

import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/device/core/system.dart';
import 'package:oronbox/src/device/xiaomi/components/xiaomi_device_component.dart';
import 'package:oronbox/src/device/xiaomi/system/xiaomi_system.dart';
import 'package:oronbox/src/protocols/xiaomi/packet/l1_packet.dart';
import 'package:oronbox/src/protocols/xiaomi/packet/l2_packet.dart';
import 'package:oronbox/src/protocols/xiaomi/packet/spp_v1_packet.dart';
import 'package:oronbox/src/protocols/generated/xiaomi/wear.pb.dart' as pb;

class XiaomiDispatcher extends Dispatcher {
  XiaomiDispatcher(this._component) : _log = getLogger('XiaomiDispatcher');

  final XiaomiDeviceComponent _component;
  final Logger _log;
  final _systems = <XiaomiSystem>[];
  Uint8List _l1Buffer = Uint8List(0);

  @override
  void register(System system) {
    if (system is XiaomiSystem) {
      _systems.add(system);
    }
    super.register(system);
  }

  @override
  void dispatch(Uint8List data) {
    if (_component.sppV1) {
      for (final packet in _component.decodeSppV1(data)) {
        switch (packet.channel) {
          case XiaomiSppV1Channel.version:
            _component.completeSppV1Hello();
          case XiaomiSppV1Channel.protobuf:
            onL2Payload(
              L2Packet(
                channel: L2Channel.pb,
                opcode: L2OpCode.write,
                payload: packet.payload,
              ).toBytes(),
            );
          case XiaomiSppV1Channel.data:
            onL2Payload(
              L2Packet(
                channel: L2Channel.mass,
                opcode: L2OpCode.write,
                payload: packet.payload,
              ).toBytes(),
            );
          case XiaomiSppV1Channel.activity:
            _component.onActivityPayload?.call(packet.payload);
            break;
        }
      }
      return;
    }
    if (_component.handleSppHello(data)) {
      return;
    }
    _l1Buffer = Uint8List.fromList([..._l1Buffer, ...data]);
    _drainL1Buffer();
  }

  void _drainL1Buffer() {
    var offset = 0;
    while (true) {
      final remaining = _l1Buffer.length - offset;
      if (remaining < 8) break;

      final magicOffset = _findL1Magic(_l1Buffer, offset);
      if (magicOffset < 0) {
        offset = _l1Buffer.length - 1;
        break;
      }
      if (magicOffset > offset) {
        _log.warning('dropping ${magicOffset - offset} bytes before L1 magic');
        offset = magicOffset;
      }

      if (_l1Buffer.length - offset < 8) break;
      final payloadLength =
          _l1Buffer[offset + 4] | (_l1Buffer[offset + 5] << 8);
      final frameLength = 8 + payloadLength;
      if (_l1Buffer.length - offset < frameLength) break;

      final frame = Uint8List.sublistView(
        _l1Buffer,
        offset,
        offset + frameLength,
      );
      _dispatchL1Frame(frame);
      offset += frameLength;
    }

    _l1Buffer = Uint8List.sublistView(_l1Buffer, offset);
  }

  int _findL1Magic(Uint8List data, int start) {
    for (var i = start; i + 1 < data.length; i++) {
      if (data[i] == 0xa5 && data[i + 1] == 0xa5) {
        return i;
      }
    }
    return -1;
  }

  void _dispatchL1Frame(Uint8List data) {
    final L1Packet l1;
    try {
      l1 = L1Packet.fromBytes(data);
    } catch (e) {
      _log.warning('L1 parse error (${data.length} bytes)', e);
      return;
    }
    _log.fine('L1 type=${l1.pktType} seq=${l1.seq} len=${l1.payload.length}');
    _component.sar.onL1Packet(l1);
  }

  void onL2Payload(Uint8List l2Bytes) {
    final L2Packet l2;
    try {
      l2 = L2Packet.fromBytes(l2Bytes, cipher: _component.authKeys?.cipher);
    } catch (e) {
      _log.warning('L2 parse error (${l2Bytes.length} bytes)', e);
      return;
    }
    _log.fine(
      'L2 channel=${l2.channel} opcode=${l2.opcode} len=${l2.payload.length}',
    );
    if (l2.channel == L2Channel.pb) {
      try {
        final packet = pb.WearPacket.fromBuffer(l2.payload);
        if (packet.whichPayload() == pb.WearPacket_Payload.notSet) {
          _log.warning(
            'unhandled Xiaomi protobuf packet id=${packet.id} '
            'type=${packet.type} len=${l2.payload.length}',
          );
        }
      } catch (e) {
        _log.warning(
          'unsupported Xiaomi protobuf packet len=${l2.payload.length}',
          e,
        );
      }
    }
    for (final system in _systems) {
      try {
        system.onLayer2Packet(l2.channel, l2.opcode, l2.payload);
      } catch (e, st) {
        _log.warning('system ${system.runtimeType} error', e, st);
      }
    }
  }
}
