import 'dart:async';
import 'dart:typed_data';

import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/core/services/classic_spp_service.dart';
import 'package:zerobox/src/device/core/transport.dart';

class SppTransport implements Transport {
  SppTransport.xiaomi(ClassicSppConnection connection)
    : _connection = connection;

  static final _log = getLogger('SppTransport');
  final ClassicSppConnection _connection;

  final _incomingController = StreamController<Uint8List>.broadcast();
  StreamSubscription<Uint8List>? _dataSubscription;
  StreamSubscription<bool>? _connectionSubscription;

  @override
  String get deviceId => _connection.deviceId;

  @override
  String get deviceName => _connection.deviceName;

  @override
  Stream<Uint8List> get incomingData => _incomingController.stream;

  @override
  Stream<bool> get connectionState => _connection.connectionState;

  Future<void> start() async {
    _log.info('[$deviceId] starting SPP transport');
    _dataSubscription = _connection.incomingData.listen(
      _incomingController.add,
      onError: (Object e) =>
          _log.warning('[$deviceId] SPP data stream error', e),
      onDone: () {
        if (!_incomingController.isClosed) {
          _incomingController.close();
        }
      },
    );
    _connectionSubscription = _connection.connectionState.listen(
      (connected) {
        _log.info('[$deviceId] SPP connection state: $connected');
        if (!connected && !_incomingController.isClosed) {
          _incomingController.close();
        }
      },
      onError: (Object e) =>
          _log.warning('[$deviceId] connection stream error', e),
    );
  }

  @override
  Future<void> send(Uint8List data) async {
    _log.fine('[$deviceId] sending ${data.length} bytes over SPP');
    await _connection.send(data);
  }

  @override
  Future<void> dispose() async {
    _log.info('[$deviceId] disposing SPP transport');
    await _dataSubscription?.cancel();
    _dataSubscription = null;
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    if (!_incomingController.isClosed) {
      await _incomingController.close();
    }
    await _connection.dispose();
  }
}
