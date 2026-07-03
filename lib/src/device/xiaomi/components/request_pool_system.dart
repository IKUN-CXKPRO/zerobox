import 'package:zerobox/src/device/xiaomi/system/xiaomi_system.dart';
import 'package:zerobox/src/protocols/generated/xiaomi/wear.pb.dart' as pb;

class XiaomiRequestPoolSystem extends XiaomiPbSystem {
  @override
  void onWearPacket(pb.WearPacket packet) {
    component.requestPool.onPacket(packet);
  }
}
