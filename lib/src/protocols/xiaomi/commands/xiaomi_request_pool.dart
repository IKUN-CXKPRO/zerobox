import 'dart:async';

import 'package:zerobox/src/protocols/common/device_protocol.dart';
import 'package:zerobox/src/protocols/generated/xiaomi/wear.pb.dart' as pb;
import 'package:zerobox/src/protocols/generated/xiaomi/wear_system.pb.dart'
    as pb_system;

class XiaomiRequestSlot<T> {
  XiaomiRequestSlot({
    required this.requestId,
    required this.typeMatcher,
    required this.responseMapper,
    this.timeout = const Duration(seconds: 10),
  });

  final int requestId;
  final bool Function(pb.WearPacket packet) typeMatcher;
  final T Function(pb.WearPacket packet) responseMapper;
  final Duration timeout;

  final _completer = Completer<T>();
  Timer? _timer;

  Future<T> get future => _completer.future;

  void startTimeout() {
    _timer = Timer(timeout, () {
      if (!_completer.isCompleted) {
        _completer.completeError(
          ProtocolException('Request $requestId timed out'),
        );
      }
    });
  }

  bool tryComplete(pb.WearPacket packet) {
    if (_completer.isCompleted) return false;
    if (!typeMatcher(packet)) return false;
    _timer?.cancel();
    try {
      final result = responseMapper(packet);
      _completer.complete(result);
      return true;
    } catch (e) {
      _completer.completeError(e);
      return true;
    }
  }
}

class XiaomiRequestPool {
  XiaomiRequestPool({
    required this.sendPacket,
    this.defaultTimeout = const Duration(seconds: 10),
  });

  final Future<void> Function(pb.WearPacket packet) sendPacket;
  final Duration defaultTimeout;
  final _slots = <XiaomiRequestSlot<Object?>>[];
  final _packetListeners = <void Function(pb.WearPacket packet)>[];

  List<void Function(pb.WearPacket packet)> get onPacketListeners =>
      _packetListeners;

  Future<T> request<T>({
    required pb.WearPacket packet,
    required bool Function(pb.WearPacket packet) typeMatcher,
    required T Function(pb.WearPacket packet) responseMapper,
    Duration? timeout,
  }) async {
    final slot = XiaomiRequestSlot<T>(
      requestId: packet.id,
      typeMatcher: typeMatcher,
      responseMapper: responseMapper,
      timeout: timeout ?? defaultTimeout,
    );
    _slots.add(slot as XiaomiRequestSlot<Object?>);
    slot.startTimeout();
    await sendPacket(packet);
    try {
      final result = await slot.future;
      _slots.remove(slot);
      return result;
    } catch (e) {
      _slots.remove(slot);
      rethrow;
    }
  }

  void onPacket(pb.WearPacket packet) {
    for (final listener in _packetListeners.toList()) {
      listener(packet);
    }
    _slots.removeWhere((slot) => slot.tryComplete(packet));
  }

  void clear() {
    for (final slot in _slots) {
      if (!slot._completer.isCompleted) {
        slot._completer.completeError(ProtocolException('Pool cleared'));
      }
      slot._timer?.cancel();
    }
    _slots.clear();
  }
}

pb.WearPacket buildSystemPacket(pb_system.System_SystemID id) {
  return pb.WearPacket(
    type: pb.WearPacket_Type.SYSTEM,
    id: id.value,
    system: pb_system.System(),
  );
}
