import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:oronbox/src/device/xiaomi/system/xiaomi_system.dart';
import 'package:oronbox/src/protocols/common/device_protocol.dart';
import 'package:oronbox/src/protocols/generated/xiaomi/wear.pb.dart' as pb;
import 'package:oronbox/src/protocols/generated/xiaomi/wear_common.pbenum.dart'
    as pb_common;
import 'package:oronbox/src/protocols/generated/xiaomi/wear_mass.pb.dart';
import 'package:oronbox/src/protocols/xiaomi/packet/l2_packet.dart';
import 'package:oronbox/src/protocols/xiaomi/packet/mass_packet.dart';
import 'package:oronbox/src/protocols/xiaomi/transport/mass_transfer.dart';

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
    if (component.sppV1) {
      return _sendSppV1File(
        fileData: fileData,
        dataType: dataType,
        expectedSliceLength: expectedSliceLength,
        onProgress: onProgress,
      );
    }
    return _transfer.sendFileWithKnownSliceLength(
      fileData: fileData,
      dataType: dataType,
      expectedSliceLength: expectedSliceLength,
      onProgress: onProgress,
    );
  }

  Future<void> _sendSppV1File({
    required Uint8List fileData,
    required MassDataType dataType,
    int? expectedSliceLength,
    void Function(SendMassCallbackData data)? onProgress,
  }) async {
    final md5 = Uint8List.fromList(crypto.md5.convert(fileData).bytes);
    final response = await component.requestPool.request<PrepareResponse>(
      packet: pb.WearPacket(
        type: pb.WearPacket_Type.MASS,
        id: Mass_MassID.PREPARE.value,
        mass: Mass(
          prepareRequest: PrepareRequest(
            dataType: dataType.value,
            dataId: md5,
            dataLength: fileData.length,
          ),
        ),
      ),
      typeMatcher: (packet) =>
          packet.whichPayload() == pb.WearPacket_Payload.mass &&
          packet.id == Mass_MassID.PREPARE.value,
      responseMapper: (packet) => packet.mass.prepareResponse,
      timeout: const Duration(seconds: 10),
    );
    if (response.prepareStatus != pb_common.PrepareStatus.READY) {
      throw ProtocolException('SPP v1 mass prepare not READY');
    }
    final resume = response.hasRemainedDataLength()
        ? response.remainedDataLength.clamp(0, fileData.length)
        : 0;
    final chunkSize =
        expectedSliceLength ??
        (response.hasExpectedSliceLength()
            ? response.expectedSliceLength
            : 2048);
    final payload = MassPacket.build(
      fileData,
      dataType,
    ).encodeWithCrc32(sentLength: resume, preserveOriginalLength: true);
    final partSize = chunkSize - 4;
    if (partSize <= 0) throw ProtocolException('Invalid SPP v1 chunk size');
    final total = (payload.length / partSize).ceil();
    for (var index = 0; index < total; index++) {
      final current = index + 1;
      final start = index * partSize;
      final end = (start + partSize).clamp(0, payload.length);
      final chunk = BytesBuilder()
        ..addByte(total & 0xff)
        ..addByte((total >> 8) & 0xff)
        ..addByte(current & 0xff)
        ..addByte((current >> 8) & 0xff)
        ..add(Uint8List.sublistView(payload, start, end));
      await component.sendSppV1MassChunk(chunk.toBytes());
      onProgress?.call(
        SendMassCallbackData(
          progress: current / total,
          totalParts: total,
          currentPartNum: current,
          actualDataPayloadLen: end - start,
        ),
      );
    }
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

  void cancelReverseMassReceive(L2Channel channel) {
    _transfer.cancelReverseMassReceive(channel);
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
