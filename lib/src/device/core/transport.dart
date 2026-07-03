import 'dart:async';
import 'dart:typed_data';

abstract class Transport {
  String get deviceId;
  String get deviceName;
  Stream<Uint8List> get incomingData;
  Stream<bool> get connectionState;
  Future<void> send(Uint8List data);
  Future<void> dispose();
}

class TransportException implements Exception {
  const TransportException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null ? message : '$message (caused by $cause)';
}
