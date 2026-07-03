import 'dart:async';
import 'dart:typed_data';

import 'package:zerobox/src/device/xiaomi/system/xiaomi_system.dart';
import 'package:zerobox/src/protocols/xiaomi/packet/l2_packet.dart';
import 'package:zerobox/src/protocols/xiaomi/packet/mass_packet.dart';
import 'package:zerobox/src/protocols/xiaomi/transport/mass_transfer.dart';

class XiaomiMassSystem extends XiaomiSystem {
  late final MassTransfer _transfer = MassTransfer(
    sendPbPacket: component.sendPbPacket,
    sar: component.sar,
    requestPool: component.requestPool,
    deviceAddr: entity.id,
  );

  Future<void> sendFile({
    required Uint8List fileData,
    required MassDataType dataType,
    int? expectedSliceLength,
    void Function(SendMassCallbackData data)? onProgress,
  }) async {
    return _transfer.sendFileWithKnownSliceLength(
      fileData: fileData,
      dataType: dataType,
      expectedSliceLength: expectedSliceLength,
      onProgress: onProgress,
    );
  }

  Future<ReverseMassReceiveResult> beginReverseMassReceive(
    L2Channel channel, {
    required void Function(ReceiveMassCallbackData) progressCb,
  }) {
    return _transfer.beginReverseMassReceive(channel, progressCb: progressCb);
  }

  Future<ReverseMassReceiveResult> beginReverseMassReceiveMulti(
    List<L2Channel> channels, {
    required void Function(ReceiveMassCallbackData) progressCb,
  }) {
    return _transfer.beginReverseMassReceiveMulti(
      channels,
      progressCb: progressCb,
    );
  }

  void clearReverseMassWait(L2Channel channel) {
    _transfer.clearReverseMassWait(channel);
  }

  @override
  void onLayer2Packet(L2Channel channel, L2OpCode opcode, Uint8List payload) {
    if (channel == L2Channel.pb) {
      return;
    }
    if (_transfer.reverseMassWaits.containsKey(channel.value)) {
      _transfer.handleReverseMassPayload(channel, payload);
    }
  }
}
