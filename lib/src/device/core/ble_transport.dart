import 'dart:async';
import 'dart:typed_data';

import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/core/services/ble_service_manager.dart';
import 'package:zerobox/src/device/core/transport.dart';

class BleTransport implements Transport {
  BleTransport.xiaomi(BleConnection connection)
      : _connection = connection,
        _serviceUuid = _xiaomiServiceUuid,
        _recvCharUuid = _xiaomiRecvCharUuid,
        _sentCharUuid = _xiaomiSentCharUuid;

  BleTransport.zepp(BleConnection connection)
      : _connection = connection,
        _serviceUuid = _zeppServiceUuid,
        _recvCharUuid = _zeppRecvCharUuid,
        _sentCharUuid = _zeppSentCharUuid;

  static final _log = getLogger('BleTransport');
  final BleConnection _connection;
  final String _serviceUuid;
  final String _recvCharUuid;
  final String _sentCharUuid;

  final _incomingController = StreamController<Uint8List>.broadcast();
  StreamSubscription<Uint8List>? _valueSubscription;
  StreamSubscription<bool>? _connectionSubscription;

  static const String _xiaomiServiceUuid =
      '0000fe95-0000-1000-8000-00805f9b34fb';
  static const String _xiaomiRecvCharUuid =
      '0000005e-0000-1000-8000-00805f9b34fb';
  static const String _xiaomiSentCharUuid =
      '0000005f-0000-1000-8000-00805f9b34fb';

  static const String _zeppServiceUuid =
      '0000fe00-0000-1000-8000-00805f9b34fb';
  static const String _zeppRecvCharUuid =
      '0000ff01-0000-1000-8000-00805f9b34fb';
  static const String _zeppSentCharUuid =
      '0000ff02-0000-1000-8000-00805f9b34fb';

  @override
  String get deviceId => _connection.deviceId;

  @override
  String get deviceName => _connection.deviceName;

  @override
  Stream<Uint8List> get incomingData => _incomingController.stream;

  @override
  Stream<bool> get connectionState => _connection.connectionState;

  Future<void> start() async {
    _log.info('[$deviceId] starting transport on recv=$_recvCharUuid');
    _valueSubscription = await _connection.subscribe(
      _serviceUuid,
      _recvCharUuid,
      _incomingController.add,
    );
    _connectionSubscription = _connection.connectionState.listen(
      (connected) {
        _log.info('[$deviceId] transport connection state: $connected');
        if (!connected && !_incomingController.isClosed) {
          _incomingController.close();
        }
      },
      onError: (Object e) => _log.warning('[$deviceId] connection stream error', e),
    );
  }

  @override
  Future<void> send(Uint8List data) async {
    _log.fine('[$deviceId] sending ${data.length} bytes');
    await _connection.write(
      _serviceUuid,
      _sentCharUuid,
      data,
      withResponse: false,
    );
  }

  @override
  Future<void> dispose() async {
    _log.info('[$deviceId] disposing transport');
    await _valueSubscription?.cancel();
    _valueSubscription = null;
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    if (!_incomingController.isClosed) {
      await _incomingController.close();
    }
    await _connection.dispose();
  }
}
