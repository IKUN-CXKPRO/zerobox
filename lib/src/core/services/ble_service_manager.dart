import 'dart:async';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';
import 'package:zerobox/src/core/logging/logging_service.dart';

enum ConnectType { spp, ble }

class ScannedBTDevice {
  const ScannedBTDevice({
    required this.name,
    required this.addr,
    required this.connectType,
    this.rssi,
  });

  final String name;
  final String addr;
  final ConnectType connectType;
  final int? rssi;

  ScannedBTDevice copyWith({
    String? name,
    String? addr,
    ConnectType? connectType,
    int? rssi,
  }) {
    return ScannedBTDevice(
      name: name ?? this.name,
      addr: addr ?? this.addr,
      connectType: connectType ?? this.connectType,
      rssi: rssi ?? this.rssi,
    );
  }
}

class BleConnection {
  BleConnection({
    required this.deviceId,
    required this.deviceName,
    this.mtu = 23,
  });

  static final _log = getLogger('BleConnection');

  final String deviceId;
  final String deviceName;
  int mtu;
  List<BleService> services = [];
  final _connectionController = StreamController<bool>.broadcast();
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<Uint8List>? _valueSubscription;
  bool _disposed = false;

  Stream<bool> get connectionState => _connectionController.stream;

  Future<void> start() async {
    _log.info('[$deviceId] starting connection state listener');
    _connectionSubscription = UniversalBle.connectionStream(deviceId).listen(
      _onConnectionStateChanged,
      onError: (Object e) =>
          _log.warning('[$deviceId] connection stream error', e),
    );
  }

  void _onConnectionStateChanged(bool connected) {
    if (_disposed) return;
    _log.info('[$deviceId] connection state changed: connected=$connected');
    _connectionController.add(connected);
  }

  BleCharacteristic? findCharacteristic(String serviceUuid, String charUuid) {
    final targetService = BleUuidParser.stringOrNull(serviceUuid);
    final targetChar = BleUuidParser.stringOrNull(charUuid);
    if (targetService == null || targetChar == null) return null;

    for (final service in services) {
      if (!BleUuidParser.compareStrings(service.uuid, targetService)) continue;
      for (final characteristic in service.characteristics) {
        if (BleUuidParser.compareStrings(characteristic.uuid, targetChar)) {
          return characteristic;
        }
      }
    }
    return null;
  }

  Future<void> discoverServices() async {
    _log.info('[$deviceId] discovering services');
    services = await UniversalBle.discoverServices(deviceId);
    _log.info('[$deviceId] discovered ${services.length} services');
    for (final service in services) {
      _log.fine(
        '[$deviceId] service ${service.uuid} with ${service.characteristics.length} characteristics',
      );
      for (final char in service.characteristics) {
        _log.fine(
          '[$deviceId]   char ${char.uuid} properties=${char.properties}',
        );
      }
    }
  }

  Future<StreamSubscription<Uint8List>> subscribe(
    String serviceUuid,
    String charUuid,
    void Function(Uint8List data) onData,
  ) async {
    final characteristic = findCharacteristic(serviceUuid, charUuid);
    if (characteristic == null) {
      _log.severe('[$deviceId] characteristic $charUuid not found');
      throw StateError('Characteristic $charUuid not found');
    }
    _log.info('[$deviceId] subscribing to $charUuid');
    await characteristic.notifications.subscribe();
    return characteristic.onValueReceived.listen(
      (data) {
        _log.fine('[$deviceId] received ${data.length} bytes from $charUuid');
        onData(data);
      },
      onError: (Object e) =>
          _log.warning('[$deviceId] notification stream error', e),
    );
  }

  Future<void> write(
    String serviceUuid,
    String charUuid,
    Uint8List data, {
    bool withResponse = false,
  }) async {
    final characteristic = findCharacteristic(serviceUuid, charUuid);
    if (characteristic == null) {
      _log.severe('[$deviceId] characteristic $charUuid not found');
      throw StateError('Characteristic $charUuid not found');
    }
    _log.fine('[$deviceId] writing ${data.length} bytes to $charUuid');
    await characteristic.write(data, withResponse: withResponse);
  }

  Future<int> requestMtu(int desiredMtu) async {
    try {
      _log.info('[$deviceId] requesting MTU $desiredMtu');
      mtu = await UniversalBle.requestMtu(deviceId, desiredMtu);
      _log.info('[$deviceId] MTU granted: $mtu');
    } catch (e) {
      _log.warning('[$deviceId] MTU request failed, keeping $mtu', e);
    }
    return mtu;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _log.info('[$deviceId] disposing');
    await _valueSubscription?.cancel();
    _valueSubscription = null;
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    if (!_connectionController.isClosed) {
      await _connectionController.close();
    }
    try {
      await UniversalBle.disconnect(deviceId);
    } catch (e) {
      _log.warning('[$deviceId] disconnect error', e);
    }
  }
}

class BleServiceManager {
  BleServiceManager() : _log = getLogger('BleServiceManager');

  final Logger _log;
  StreamSubscription<BleDevice>? _scanSubscription;
  final _scanController = StreamController<ScannedBTDevice>.broadcast();

  Stream<ScannedBTDevice> get scanStream => _scanController.stream;

  static const String xiaomiServiceUuid =
      '0000fe95-0000-1000-8000-00805f9b34fb';
  static const String xiaomiRecvCharUuid =
      '0000005e-0000-1000-8000-00805f9b34fb';
  static const String xiaomiSentCharUuid =
      '0000005f-0000-1000-8000-00805f9b34fb';

  Future<bool> isAvailable() async {
    final state = await UniversalBle.getBluetoothAvailabilityState();
    _log.info('bluetooth availability state: $state');
    return state == AvailabilityState.poweredOn;
  }

  Future<void> requestPermissions() async {
    _log.info('requesting bluetooth permissions');
    await UniversalBle.requestPermissions(withAndroidFineLocation: false);
  }

  Future<void> startScan({
    List<String>? withServices,
    List<String>? withNamePrefixes,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    await stopScan();
    _log.info('starting BLE scan');

    _scanSubscription = UniversalBle.scanStream.listen((device) {
      final name = device.name?.trim() ?? '';
      if (withNamePrefixes != null && withNamePrefixes.isNotEmpty) {
        final matches = withNamePrefixes.any(
          (prefix) => name.toLowerCase().startsWith(prefix.toLowerCase()),
        );
        if (!matches) return;
      }
      _log.fine(
        'scanned device: $name @ ${device.deviceId} rssi=${device.rssi}',
      );
      _scanController.add(
        ScannedBTDevice(
          name: name.isEmpty ? 'Unknown device' : name,
          addr: device.deviceId,
          connectType: ConnectType.ble,
          rssi: device.rssi,
        ),
      );
    }, onError: (Object e) => _log.warning('scan stream error', e));

    await UniversalBle.startScan(
      scanFilter: ScanFilter(withServices: withServices ?? []),
    );

    Future.delayed(timeout, stopScan);
  }

  Future<void> stopScan() async {
    _log.info('stopping BLE scan');
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    if (await UniversalBle.isScanning()) {
      await UniversalBle.stopScan();
    }
  }

  Future<BleConnection> connect(String deviceId, String deviceName) async {
    await stopScan();
    _log.info('[$deviceId] initiating BLE connection');
    try {
      await UniversalBle.connect(deviceId).timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          throw TimeoutException('UniversalBle.connect timed out');
        },
      );
    } catch (e) {
      _log.severe('[$deviceId] UniversalBle.connect failed', e);
      rethrow;
    }
    _log.info('[$deviceId] UniversalBle.connect returned');

    final connection = BleConnection(
      deviceId: deviceId,
      deviceName: deviceName,
    );
    await connection.start();

    final connected = await _waitForConnectionState(
      connection.connectionState,
      timeout: const Duration(seconds: 5),
    );
    if (!connected) {
      _log.severe('[$deviceId] device did not report connected in time');
      await connection.dispose();
      throw StateError('BLE device did not report connected in time');
    }
    _log.info('[$deviceId] controller reports connected');

    try {
      _log.info('[$deviceId] attempting pair');
      await UniversalBle.pair(deviceId);
      _log.info('[$deviceId] pair succeeded or not needed');
    } catch (e) {
      _log.warning('[$deviceId] pair failed (ignored)', e);
    }

    try {
      await connection.discoverServices();
    } catch (e) {
      _log.severe('[$deviceId] service discovery failed', e);
      await connection.dispose();
      rethrow;
    }

    final hasRecv =
        connection.findCharacteristic(xiaomiServiceUuid, xiaomiRecvCharUuid) !=
        null;
    final hasSent =
        connection.findCharacteristic(xiaomiServiceUuid, xiaomiSentCharUuid) !=
        null;
    if (!hasRecv || !hasSent) {
      _log.severe(
        '[$deviceId] missing Xiaomi characteristics: recv=$hasRecv sent=$hasSent',
      );
      await connection.dispose();
      throw StateError('Required Xiaomi BLE characteristics not found');
    }
    _log.info('[$deviceId] Xiaomi characteristics found');

    try {
      connection.mtu = await connection.requestMtu(517);
    } catch (e) {
      _log.warning('[$deviceId] MTU request failed, keeping default', e);
    }

    _log.info('[$deviceId] BLE connection ready');
    return connection;
  }

  Future<bool> _waitForConnectionState(
    Stream<bool> stream, {
    required Duration timeout,
  }) async {
    try {
      await stream.firstWhere((connected) => connected).timeout(timeout);
      return true;
    } on TimeoutException catch (_) {
      return false;
    }
  }

  Future<void> dispose() async {
    _log.info('disposing BleServiceManager');
    await stopScan();
    await _scanController.close();
  }
}
