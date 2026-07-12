import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:zerobox/src/commands/command_protocol.dart';
import 'package:zerobox/src/daemon/daemon_endpoint.dart';

class ZeroBoxDaemonClient implements ZeroBoxCommandBus {
  ZeroBoxDaemonClient._(this._socket, this._token) {
    _subscription = _socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          _handleLine,
          onDone: _handleDone,
          onError: (_) => _handleDone(),
        );
  }

  final Socket _socket;
  final String? _token;
  late final StreamSubscription<String> _subscription;
  final _pending = <String, _PendingRequest>{};
  final _events = StreamController<CommandEvent>.broadcast();
  var _nextId = 0;

  static Future<ZeroBoxDaemonClient> connect({
    Duration timeout = const Duration(seconds: 1),
  }) async {
    final token = Platform.isWindows
        ? await File(daemonWindowsTokenPath).readAsString()
        : null;
    final socket = Platform.isWindows
        ? await Socket.connect(
            InternetAddress.loopbackIPv4,
            daemonWindowsPort,
            timeout: timeout,
          )
        : await _connectUnix(timeout);
    return ZeroBoxDaemonClient._(socket, token);
  }

  static Future<Socket> _connectUnix(Duration timeout) async {
    try {
      return await Socket.connect(
        InternetAddress(daemonSocketPath, type: InternetAddressType.unix),
        0,
        timeout: timeout,
      );
    } catch (_) {
      return Socket.connect(
        InternetAddress(legacyDaemonSocketPath, type: InternetAddressType.unix),
        0,
        timeout: timeout,
      );
    }
  }

  @override
  Stream<CommandEvent> get events => _events.stream;

  @override
  Future<CommandResult> execute(
    ZeroBoxCommand command, {
    Duration timeout = const Duration(minutes: 10),
  }) {
    final id = '${++_nextId}';
    final completer = Completer<CommandResult>();
    final timer = Timer(timeout, () {
      final pending = _pending.remove(id);
      pending?.completer.complete(
        CommandResult.failure(
          CommandError(
            'timeout',
            'Daemon request timed out: ${command.method}',
          ),
        ),
      );
    });
    _pending[id] = _PendingRequest(completer, timer);
    _socket.writeln(
      jsonEncode({
        'id': id,
        if (_token != null) 'token': _token,
        ...command.toJson(),
      }),
    );
    return completer.future;
  }

  void _handleLine(String line) {
    final value = jsonDecode(line) as Map<String, dynamic>;
    if (value['type'] == 'event') {
      final event = value['event']?.toString() ?? 'unknown';
      final data = Map<String, Object?>.from(value)
        ..remove('type')
        ..remove('event');
      _events.add(CommandEvent(event, data: data));
      return;
    }
    final id = value['id']?.toString() ?? '';
    final pending = _pending.remove(id);
    pending?.timer.cancel();
    pending?.completer.complete(
      CommandResult.fromJson(value.cast<String, Object?>()),
    );
  }

  void _handleDone() {
    for (final pending in _pending.values) {
      pending.timer.cancel();
      if (!pending.completer.isCompleted) {
        pending.completer.complete(
          const CommandResult.failure(
            CommandError('daemon_disconnected', 'Daemon disconnected'),
          ),
        );
      }
    }
    _pending.clear();
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await _socket.close();
    await _events.close();
  }
}

class _PendingRequest {
  _PendingRequest(this.completer, this.timer);
  final Completer<CommandResult> completer;
  final Timer timer;
}
