import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:fixnum/fixnum.dart';
import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/device/core/event_bus.dart';
import 'package:zerobox/src/device/xiaomi/components/info_system.dart';
import 'package:zerobox/src/device/xiaomi/components/mass_system.dart';
import 'package:zerobox/src/device/xiaomi/system/xiaomi_system.dart';
import 'package:zerobox/src/protocols/common/device_protocol.dart';
import 'package:zerobox/src/protocols/generated/xiaomi/wear.pb.dart' as pb;
import 'package:zerobox/src/protocols/generated/xiaomi/wear_common.pbenum.dart'
    as pb_common;
import 'package:zerobox/src/protocols/generated/xiaomi/wear_notification.pb.dart'
    as pb_notification;
import 'package:zerobox/src/protocols/generated/xiaomi/wear_system.pb.dart'
    as pb_system;
import 'package:zerobox/src/protocols/generated/xiaomi/wear_thirdparty_app.pb.dart'
    as pb_thirdparty;
import 'package:zerobox/src/protocols/generated/xiaomi/wear_watch_face.pb.dart'
    as pb_watchface;
import 'package:zerobox/src/protocols/xiaomi/packet/mass_packet.dart';
import 'package:zerobox/src/protocols/xiaomi/transport/mass_transfer.dart';

class XiaomiInstallSystem extends XiaomiPbSystem {
  static final _log = getLogger('XiaomiInstallSystem');
  final _inProgress = <MassDataType, Completer<void>>{};

  XiaomiMassSystem get _massSystem => entity.system<XiaomiMassSystem>()!;
  XiaomiInfoSystem get _infoSystem => entity.system<XiaomiInfoSystem>()!;

  Future<void> installApp(
    Uint8List packageBytes, {
    String? packageName,
    void Function(double progress)? onProgress,
  }) async {
    return _runInstall(
      dataType: MassDataType.thirdPartyApp,
      fileData: packageBytes,
      onProgress: onProgress,
      run: () async {
        final name = packageName ?? 'com.zerobox.unknown';
        const versionCode = 114514;

        final prepareRet = await component.requestPool.request<pb.WearPacket>(
          packet: pb.WearPacket(
            type: pb.WearPacket_Type.THIRDPARTY_APP,
            id: pb_thirdparty
                .ThirdpartyApp_ThirdpartyAppID
                .PREPARE_INSTALL_APP
                .value,
            thirdpartyApp: pb_thirdparty.ThirdpartyApp(
              installRequest: pb_thirdparty.AppInstaller_Request(
                packageName: name,
                versionCode: versionCode,
                packageSize: packageBytes.length,
              ),
            ),
          ),
          typeMatcher: (p) =>
              p.whichPayload() == pb.WearPacket_Payload.thirdpartyApp &&
              p.id ==
                  pb_thirdparty
                      .ThirdpartyApp_ThirdpartyAppID
                      .PREPARE_INSTALL_APP
                      .value,
          responseMapper: (p) => p,
        );

        final status = prepareRet.thirdpartyApp.installResponse.prepareStatus;
        if (status != pb_common.PrepareStatus.READY) {
          throw ProtocolException('App prepare not READY: $status');
        }

        final resultFuture = _waitProto(
          pb.WearPacket_Type.THIRDPARTY_APP.value,
          pb_thirdparty
              .ThirdpartyApp_ThirdpartyAppID
              .REPORT_INSTALL_RESULT
              .value,
          timeout: const Duration(seconds: 60),
        );

        await _massSystem.sendFile(
          fileData: packageBytes,
          dataType: MassDataType.thirdPartyApp,
          onProgress: (data) =>
              _emitProgress(MassDataType.thirdPartyApp, data, onProgress),
        );

        final result = await resultFuture;
        final code = result.thirdpartyApp.installResult.code;
        _log.info('[${entity.id}] app install result: $code');
        if (code != pb_thirdparty.AppInstaller_Result_Code.INSTALL_SUCCESS) {
          throw ProtocolException('App install failed: $code');
        }
      },
    );
  }

  Future<void> installWatchface(
    Uint8List watchfaceBytes, {
    required String watchfaceId,
    void Function(double progress)? onProgress,
  }) async {
    return _runInstall(
      dataType: MassDataType.watchface,
      fileData: watchfaceBytes,
      onProgress: onProgress,
      run: () async {
        final fileData = Uint8List.fromList(watchfaceBytes);
        final effectiveWatchfaceId = _normalizeWatchfaceId(watchfaceId, fileData);
        final idBytes = Uint8List.fromList(effectiveWatchfaceId.codeUnits);
        final paddedIdBytes = Uint8List(12);
        for (var i = 0; i < 12 && i < idBytes.length; i++) {
          paddedIdBytes[i] = idBytes[i];
        }
        for (var i = 0; i < 12; i++) {
          fileData[0x28 + i] = paddedIdBytes[i];
        }

        final prepareRet = await component.requestPool.request<pb.WearPacket>(
          packet: pb.WearPacket(
            type: pb.WearPacket_Type.WATCH_FACE,
            id: pb_watchface
                .WatchFace_WatchFaceID
                .PREPARE_INSTALL_WATCH_FACE
                .value,
            watchFace: pb_watchface.WatchFace(
              prepareInfo: pb_watchface.PrepareInfo(
                id: effectiveWatchfaceId,
                size: fileData.length,
                versionCode: Int64(65536),
              ),
            ),
          ),
          typeMatcher: (p) =>
              p.whichPayload() == pb.WearPacket_Payload.watchFace &&
              p.id ==
                  pb_watchface
                      .WatchFace_WatchFaceID
                      .PREPARE_INSTALL_WATCH_FACE
                      .value,
          responseMapper: (p) => p,
        );

        final status = prepareRet.watchFace.prepareStatus;
        if (status != pb_common.PrepareStatus.READY) {
          throw ProtocolException('Watchface prepare not READY: $status');
        }

        final resultFuture = _waitProto(
          pb.WearPacket_Type.WATCH_FACE.value,
          pb_watchface.WatchFace_WatchFaceID.REPORT_INSTALL_RESULT.value,
          timeout: const Duration(seconds: 30),
        );

        await _massSystem.sendFile(
          fileData: fileData,
          dataType: MassDataType.watchface,
          onProgress: (data) =>
              _emitProgress(MassDataType.watchface, data, onProgress),
        );

        final result = await resultFuture;
        final code = result.watchFace.installResult.code;
        _log.info('[${entity.id}] watchface install result: $code');
        if (code != pb_watchface.InstallResult_Code.INSTALL_SUCCESS &&
            code != pb_watchface.InstallResult_Code.INSTALL_USED) {
          throw ProtocolException('Watchface install failed: $code');
        }
      },
    );
  }

  Future<void> installFirmware(
    Uint8List firmwareBytes, {
    void Function(double progress)? onProgress,
  }) async {
    return _runInstall(
      dataType: MassDataType.firmware,
      fileData: firmwareBytes,
      onProgress: onProgress,
      run: () async {
        final fileMd5 = _calcMd5(firmwareBytes);

        final prepareRet = await component.requestPool.request<pb.WearPacket>(
          packet: pb.WearPacket(
            type: pb.WearPacket_Type.SYSTEM,
            id: pb_system.System_SystemID.PREPARE_OTA.value,
            system: pb_system.System(
              prepareOtaRequest: pb_system.PrepareOta_Request(
                force: true,
                type: pb_system.PrepareOta_Type.ALL,
                firmwareVersion: '99.99.99',
                fileMd5: _toHexString(fileMd5),
                changeLog: 'ZeroBox Firmware Update',
                fileUrl: '',
              ),
            ),
          ),
          typeMatcher: (p) =>
              p.whichPayload() == pb.WearPacket_Payload.system &&
              p.id == pb_system.System_SystemID.PREPARE_OTA.value,
          responseMapper: (p) => p,
        );

        final status = prepareRet.system.prepareOtaResponse.prepareStatus;
        if (status != pb_common.PrepareStatus.READY) {
          throw ProtocolException('Firmware prepare not READY: $status');
        }

        final resultFuture = _waitProto(
          pb.WearPacket_Type.SYSTEM.value,
          pb_system.System_SystemID.PREPARE_OTA.value,
          timeout: const Duration(seconds: 30),
        );

        await _massSystem.sendFile(
          fileData: firmwareBytes,
          dataType: MassDataType.firmware,
          onProgress: (data) =>
              _emitProgress(MassDataType.firmware, data, onProgress),
        );

        try {
          final result = await resultFuture;
          final resp = result.system.prepareOtaResponse;
          final resultStatus = resp.prepareStatus;
          _log.info('[${entity.id}] firmware install result: $resultStatus');
          if (resultStatus != pb_common.PrepareStatus.READY) {
            throw ProtocolException('Firmware install failed: $resultStatus');
          }
        } on TimeoutException {
          _log.info(
            '[${entity.id}] firmware payload sent; install result message missing because the device may be rebooting',
          );
        }
      },
    );
  }

  Future<void> installNotificationIcon(
    Uint8List iconBytes, {
    required String packageName,
    void Function(double progress)? onProgress,
  }) async {
    return _runInstall(
      dataType: MassDataType.notificationIcon,
      fileData: iconBytes,
      onProgress: onProgress,
      run: () async {
        final prepareRet = await component.requestPool
            .request<pb_notification.Notification>(
          packet: pb.WearPacket(
            type: pb.WearPacket_Type.NOTIFICATION,
            id: pb_notification.Notification_NotificationID.PREPARE_APP_ICON.value,
            notification: pb_notification.Notification(
              appIconRequest: pb_notification.PrepareAppIcon_Request(
                packageName: packageName,
              ),
            ),
          ),
          typeMatcher: (p) =>
              p.whichPayload() == pb.WearPacket_Payload.notification &&
              p.id ==
                  pb_notification.Notification_NotificationID.PREPARE_APP_ICON
                      .value,
          responseMapper: (p) => p.notification,
        );

        final status = prepareRet.appIconResponse.prepareStatus;
        if (status != pb_common.PrepareStatus.READY) {
          throw ProtocolException('Notification icon prepare not READY: $status');
        }

        final expectedSliceLength = prepareRet.appIconResponse.hasExpectedSliceLength()
            ? prepareRet.appIconResponse.expectedSliceLength
            : null;

        await _massSystem.sendFile(
          fileData: iconBytes,
          dataType: MassDataType.notificationIcon,
          expectedSliceLength: expectedSliceLength,
          onProgress: (data) =>
              _emitProgress(MassDataType.notificationIcon, data, onProgress),
        );
      },
    );
  }

  Future<void> _runInstall({
    required MassDataType dataType,
    required Uint8List fileData,
    required void Function(double progress)? onProgress,
    required Future<void> Function() run,
  }) async {
    if (_inProgress.containsKey(dataType)) {
      throw StateError('install already in progress for $dataType');
    }
    final completer = Completer<void>();
    _inProgress[dataType] = completer;

    _log.info(
      '[${entity.id}] start install $dataType, ${fileData.length} bytes',
    );
    entity.emit(InstallPrepared(deviceId: entity.id));

    try {
      await run();
      _log.info('[${entity.id}] install $dataType completed');
      entity.emit(InstallCompleted(deviceId: entity.id));
      completer.complete();
      await _refreshPostInstallState(dataType);
    } catch (e, st) {
      _log.severe('[${entity.id}] install $dataType failed', e, st);
      entity.emit(InstallFailed(deviceId: entity.id, error: e.toString()));
      completer.completeError(e);
      rethrow;
    } finally {
      _inProgress.remove(dataType);
    }

    return completer.future;
  }

  static String _normalizeWatchfaceId(String watchfaceId, Uint8List fileData) {
    final extracted = _extractWatchfaceIdFromBin(fileData);
    if (extracted != null && _isValidWatchfaceId(extracted)) {
      return extracted;
    }
    if (_isValidWatchfaceId(watchfaceId)) {
      return watchfaceId;
    }
    return _generateWatchfaceId();
  }

  static String? _extractWatchfaceIdFromBin(Uint8List bytes) {
    const idOffset = 0x28;
    const idLength = 12;
    if (bytes.length < idOffset + idLength) return null;
    final raw = bytes.sublist(idOffset, idOffset + idLength);
    final trimmed = raw
        .takeWhile((b) => b != 0)
        .map((b) => String.fromCharCode(b))
        .join();
    return trimmed.isEmpty ? null : trimmed;
  }

  static bool _isValidWatchfaceId(String id) {
    if (id.isEmpty || id.length > 12) return false;
    if (RegExp(r'^[0]+$').hasMatch(id)) return false;
    return RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id);
  }

  static String _generateWatchfaceId() {
    final random = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < 12; i++) {
      buffer.write(random.nextInt(10));
    }
    return buffer.toString();
  }

  @override
  void onWearPacket(pb.WearPacket packet) {
    // Install results are waited via _waitProto; nothing to handle here.
  }

  Future<void> _refreshPostInstallState(MassDataType dataType) async {
    try {
      switch (dataType) {
        case MassDataType.watchface:
          await _infoSystem.fetchInstalledWatchfaces();
        case MassDataType.thirdPartyApp:
          await _infoSystem.fetchInstalledApps();
        case MassDataType.firmware:
        case MassDataType.notificationIcon:
        case MassDataType.music:
        case MassDataType.watchfaceImage:
        case MassDataType.watchfaceFont:
          break;
      }
    } catch (e, st) {
      _log.warning('[${entity.id}] post-install refresh failed', e, st);
    }
  }

  void _emitProgress(
    MassDataType dataType,
    SendMassCallbackData data,
    void Function(double progress)? onProgress,
  ) {
    _log.fine(
      '[${entity.id}] install progress ${data.currentPartNum}/${data.totalParts}',
    );
    entity.emit(
      InstallProgress(
        deviceId: entity.id,
        progress: data.progress,
        totalParts: data.totalParts,
        currentPart: data.currentPartNum,
      ),
    );
    onProgress?.call(data.progress);
  }

  Future<pb.WearPacket> _waitProto(
    int expectType,
    int expectId, {
    required Duration timeout,
  }) async {
    final completer = Completer<pb.WearPacket>();

    void onPacket(pb.WearPacket packet) {
      if (packet.type.value == expectType && packet.id == expectId) {
        if (!completer.isCompleted) {
          completer.complete(packet);
        }
      }
    }

    component.requestPool.onPacketListeners.add(onPacket);
    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      throw TimeoutException(
        'Timeout waiting for proto type=$expectType id=$expectId',
        timeout,
      );
    } finally {
      component.requestPool.onPacketListeners.remove(onPacket);
    }
  }

  static Uint8List _calcMd5(Uint8List data) {
    return Uint8List.fromList(crypto.md5.convert(data).bytes);
  }

  static String _toHexString(Uint8List data) {
    return data.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
