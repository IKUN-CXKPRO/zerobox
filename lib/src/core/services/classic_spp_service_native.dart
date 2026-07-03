import 'dart:async';

import 'package:flutter/services.dart';
import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/core/services/classic_spp_service.dart';

class NativeClassicSppConnection implements ClassicSppConnection {
  NativeClassicSppConnection({
    required this.deviceId,
    required this.deviceName,
    required this._service,
  });

  @override
  final String deviceId;

  @override
  final String deviceName;

  final NativeClassicSppService _service;
  final _connectionController = StreamController<bool>.broadcast();
  bool _disposed = false;

  @override
  Stream<Uint8List> get incomingData => _service.incomingData;

  @override
  Stream<bool> get connectionState => _connectionController.stream;

  @override
  Future<void> start() async {
    _connectionController.add(true);
  }

  @override
  Future<void> send(Uint8List data) => _service.send(data);

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _service.disconnect();
    if (!_connectionController.isClosed) {
      await _connectionController.close();
    }
  }
}

class NativeClassicSppService implements ClassicSppService {
  NativeClassicSppService() : _log = getLogger('ClassicSppService');

  static const _method = MethodChannel('zerobox/classic_spp');
  static const _events = EventChannel('zerobox/classic_spp/events');

  final Logger _log;
  Stream<Uint8List>? _incomingData;

  Stream<Uint8List> get incomingData {
    return _incomingData ??= _events.receiveBroadcastStream().map((event) {
      if (event is Uint8List) return event;
      if (event is List<int>) return Uint8List.fromList(event);
      throw StateError('Unexpected SPP event: ${event.runtimeType}');
    });
  }

  @override
  Future<ClassicSppConnection> connect(
    String deviceId,
    String deviceName,
  ) async {
    _log.info('[$deviceId] initiating SPP connection');
    final result = await _method.invokeMapMethod<String, Object?>('connect', {
      'addr': deviceId,
    });
    _log.info('[$deviceId] SPP connected on channel ${result?['channel']}');
    final connection = NativeClassicSppConnection(
      deviceId: deviceId,
      deviceName: deviceName,
      service: this,
    );
    await connection.start();
    return connection;
  }

  @override
  Future<void> send(Uint8List data) async {
    await _method.invokeMethod<void>('send', {'data': data});
  }

  @override
  Future<void> disconnect() async {
    await _method.invokeMethod<void>('disconnect');
  }
}

ClassicSppService createClassicSppService() => NativeClassicSppService();
ClassicSppConnection createClassicSppConnection({
  required String deviceId,
  required String deviceName,
  required ClassicSppService service,
}) => NativeClassicSppConnection(
  deviceId: deviceId,
  deviceName: deviceName,
  service: service as NativeClassicSppService,
);
