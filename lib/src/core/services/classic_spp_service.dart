import 'dart:async';
import 'dart:typed_data';

export 'classic_spp_service_native.dart'
    if (dart.library.html) 'classic_spp_service_web.dart';

abstract class ClassicSppConnection {
  String get deviceId;
  String get deviceName;
  Stream<Uint8List> get incomingData;
  Stream<bool> get connectionState;
  Future<void> send(Uint8List data);
  Future<void> start();
  Future<void> dispose();
}

abstract class ClassicSppService {
  Future<ClassicSppConnection> connect(String deviceId, String deviceName);
  Future<void> send(Uint8List data);
  Future<void> disconnect();
}
