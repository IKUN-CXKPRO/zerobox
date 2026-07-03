import 'dart:async';

import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/device/xiaomi/system/xiaomi_system.dart';
import 'package:zerobox/src/protocols/generated/xiaomi/wear.pb.dart' as pb;
import 'package:zerobox/src/protocols/generated/xiaomi/wear_system.pb.dart'
    as pb_system;

class XiaomiReportSystem extends XiaomiPbSystem {
  static final _log = getLogger('XiaomiReportSystem');

  Completer<pb_system.ReportData_Result>? _deviceLogWaiter;

  Future<pb_system.ReportData_Result> requestDeviceLogExport() async {
    _log.info('[${entity.id}] requesting device log export');
    if (_deviceLogWaiter != null) {
      throw StateError('device log export already in progress');
    }
    final completer = Completer<pb_system.ReportData_Result>();
    _deviceLogWaiter = completer;
    await component.sendPbPacket(
      _buildReportDataPacket(pb_system.ReportData_Type.DEVICE_LOG),
    );
    return completer.future.timeout(const Duration(seconds: 30));
  }

  void clearDeviceLogWait() {
    _deviceLogWaiter = null;
  }

  @override
  void onWearPacket(pb.WearPacket packet) {
    if (packet.whichPayload() != pb.WearPacket_Payload.system) return;
    final system = packet.system;
    if (system.whichPayload() != pb_system.System_Payload.reportDataResult) {
      return;
    }
    final result = system.reportDataResult;
    if (result.type != pb_system.ReportData_Type.DEVICE_LOG) return;

    final waiter = _deviceLogWaiter;
    if (waiter != null && !waiter.isCompleted) {
      waiter.complete(result);
    }
    _deviceLogWaiter = null;
  }
}

pb.WearPacket _buildReportDataPacket(pb_system.ReportData_Type reportType) {
  final reportData = pb_system.ReportData(type: reportType);
  final packetPayload = pb_system.System(reportData: reportData);

  return pb.WearPacket(
    type: pb.WearPacket_Type.SYSTEM,
    id: pb_system.System_SystemID.REPORT_DATA.value,
    system: packetPayload,
  );
}
