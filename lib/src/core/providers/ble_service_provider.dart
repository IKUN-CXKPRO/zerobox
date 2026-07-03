import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/core/services/ble_service_manager.dart';
import 'package:zerobox/src/core/services/classic_spp_service.dart';

final bleServiceManagerProvider = Provider<BleServiceManager>((ref) {
  final manager = BleServiceManager();
  ref.onDispose(manager.dispose);
  return manager;
});

final classicSppServiceProvider = Provider<ClassicSppService>((ref) {
  return createClassicSppService();
});
