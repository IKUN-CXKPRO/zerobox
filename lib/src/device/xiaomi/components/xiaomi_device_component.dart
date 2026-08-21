import 'dart:async';
import 'dart:typed_data';

import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/device/core/transport.dart';
import 'package:oronbox/src/protocols/generated/xiaomi/wear.pb.dart' as pb;
import 'package:oronbox/src/protocols/xiaomi/commands/xiaomi_request_pool.dart';
import 'package:oronbox/src/protocols/xiaomi/packet/l2_packet.dart';
import 'package:oronbox/src/protocols/xiaomi/packet/spp_v1_packet.dart';
import 'package:oronbox/src/protocols/xiaomi/transport/xiaomi_sar_controller.dart';
import 'package:oronbox/src/device/xiaomi/utils/auth_utils.dart';

class _Mutex {
  Completer<void>? _last;

  Future<void> acquire() async {
    final previous = _last;
    final completer = Completer<void>();
    _last = completer;
    if (previous != null) {
      await previous.future;
    }
  }

  void release() {
    final current = _last;
    if (current != null && !current.isCompleted) {
      current.complete();
    }
  }
}

class XiaomiDeviceComponent {
  XiaomiDeviceComponent({required this.transport, required this.sppV1})
    : _log = getLogger('XiaomiDeviceComponent');

  final Transport transport;
  final bool sppV1;
  final Logger _log;

  XiaomiAuthKeys? authKeys;
  void Function(Uint8List l2Payload)? onL2Payload;

  /// Activity/fitness files use a dedicated transport channel rather than
  /// protobuf.  Keep that channel separate from [onL2Payload] so a complete
  /// file can be assembled by the health system without pretending it is a
  /// protobuf packet.
  void Function(Uint8List payload)? onActivityPayload;
  void Function(Uint8List frame)? onRawOutgoing;
  void Function(Object error, StackTrace stackTrace)? onTransportFailure;
  Completer<void>? _sppHelloCompleter;
  final XiaomiSppV1Codec _sppV1Codec = XiaomiSppV1Codec();
  final _massSendLock = _Mutex();

  static final Uint8List _sppHelloPacket = Uint8List.fromList([
    0xba,
    0xdc,
    0xfe,
    0x00,
    0xc0,
    0x03,
    0x00,
    0x00,
    0x01,
    0x00,
    0xef,
  ]);

  late final XiaomiSarController sar = XiaomiSarController(
    onSend: _onSarSend,
    onData: (data) => onL2Payload?.call(data),
    onSendError: _onSarSendError,
  );

  late final XiaomiRequestPool requestPool = XiaomiRequestPool(
    sendPacket: sendPbPacket,
  );

  Future<void> _onSarSend(Uint8List data) async {
    _log.fine('SAR sending ${data.length} bytes');
    onRawOutgoing?.call(Uint8List.fromList(data));
    await transport.send(data);
  }

  void _onSarSendError(Object error, StackTrace stackTrace) {
    _log.warning('SAR send failed, marking transport disconnected', error);
    sar.abortPendingTransmissions(error);
    requestPool.clear();
    onTransportFailure?.call(error, stackTrace);
  }

  Future<void> startSession({required bool spp}) async {
    if (spp) {
      _log.info('starting SPP hello');
      _sppHelloCompleter = Completer<void>();
      final hello = sppV1 ? _sppV1Codec.versionRequest() : _sppHelloPacket;
      onRawOutgoing?.call(Uint8List.fromList(hello));
      await transport.send(hello);
      await _sppHelloCompleter!.future.timeout(const Duration(seconds: 10));
      _sppHelloCompleter = null;
      _log.info('SPP hello completed');
    }
    if (!sppV1) sar.start();
  }

  bool handleSppHello(Uint8List data) {
    if (sppV1) return false;
    if (data.length < 3 ||
        data[0] != 0xba ||
        data[1] != 0xdc ||
        data[2] != 0xfe) {
      return false;
    }
    _log.fine('received SPP hello response (${data.length} bytes)');
    if (_sppHelloCompleter != null && !_sppHelloCompleter!.isCompleted) {
      _sppHelloCompleter!.complete();
    }
    return true;
  }

  void completeSppV1Hello() {
    final completer = _sppHelloCompleter;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  Future<void> sendPbPacket(
    pb.WearPacket packet, {
    bool waitForAck = false,
  }) async {
    final encrypted = authKeys != null;
    _log.fine(
      'sending PB packet type=${packet.type} id=${packet.id} encrypted=$encrypted',
    );
    if (sppV1) {
      _sppV1Codec.authKeys = authKeys;
      final data = _sppV1Codec.encodeProtobuf(
        packet.writeToBuffer(),
        authenticate: false,
      );
      onRawOutgoing?.call(Uint8List.fromList(data));
      await transport.send(data);
      return;
    }
    final l2 = encrypted
        ? L2Packet.pbWriteEnc(packet, authKeys!.cipher)
        : L2Packet.pbWrite(packet);
    if (waitForAck) {
      await sar.sendDataRegisterAck(l2.toBytes()).ack;
    } else {
      await sar.sendData(l2.toBytes());
    }
  }

  Future<void> sendPbPacketUnencrypted(pb.WearPacket packet) async {
    _log.fine(
      'sending unencrypted PB packet type=${packet.type} id=${packet.id}',
    );
    if (sppV1) {
      _sppV1Codec.authKeys = authKeys;
      final data = _sppV1Codec.encodeProtobuf(
        packet.writeToBuffer(),
        authenticate: true,
      );
      onRawOutgoing?.call(Uint8List.fromList(data));
      await transport.send(data);
      return;
    }
    final l2 = L2Packet.pbWrite(packet);
    await sar.sendData(l2.toBytes());
  }

  Future<void> sendSppV1MassChunk(Uint8List payload) async {
    _sppV1Codec.authKeys = authKeys;
    final data = _sppV1Codec.encodeData(payload);
    onRawOutgoing?.call(Uint8List.fromList(data));
    await transport.send(data);
  }

  List<XiaomiSppV1Packet> decodeSppV1(Uint8List data) {
    _sppV1Codec.authKeys = authKeys;
    return _sppV1Codec.add(data);
  }

  Future<void> sendL2MassData(Uint8List l2Payload) async {
    final l2 = L2Packet(
      channel: L2Channel.mass,
      opcode: L2OpCode.write,
      payload: l2Payload,
    );
    await sar.sendData(l2.toBytes());
  }

  Future<void> sendL2NetworkData(Uint8List l2Payload) async {
    final l2 = L2Packet(
      channel: L2Channel.network,
      opcode: L2OpCode.write,
      payload: l2Payload,
    );
    await sar.sendData(l2.toBytes());
  }

  Future<RegisteredAck> sendL2MassDataRegisterAck(
    Uint8List l2Payload, {
    Duration? timeout,
  }) async {
    await _massSendLock.acquire();
    try {
      final l2 = L2Packet(
        channel: L2Channel.mass,
        opcode: L2OpCode.write,
        payload: l2Payload,
      );
      return sar.sendDataRegisterAck(l2.toBytes(), timeout: timeout);
    } finally {
      _massSendLock.release();
    }
  }

  Future<void> dispose() async {
    _log.info('disposing component');
    sar.stop();
    requestPool.clear();
  }
}
