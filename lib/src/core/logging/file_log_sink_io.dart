import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

const _androidLogsChannel = MethodChannel('zerobox/logs');

Directory? _logDirectory;
SerialFileLogWriter? _writer;

class SerialFileLogWriter {
  SerialFileLogWriter(this._sink);

  final IOSink _sink;
  Future<void> _pending = Future<void>.value();
  bool _closed = false;

  void writeLine(String line) {
    if (_closed) return;
    _pending = _pending
        .then((_) async {
          _sink.writeln(line);
          await _sink.flush();
        })
        .catchError((Object _) {
          // Logging must never crash the application. A later line can still
          // retry after a transient sink failure.
        });
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _pending;
    await _sink.flush();
    await _sink.close();
  }
}

Future<void> initializeFileLogSink() async {
  final support = await getApplicationSupportDirectory();
  final directory = Directory('${support.path}${Platform.pathSeparator}logs');
  await directory.create(recursive: true);
  _logDirectory = directory;
  await _removeExpiredLogs(directory);
  final now = DateTime.now();
  final date =
      '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
  final file = File(
    '${directory.path}${Platform.pathSeparator}zerobox-$date.log',
  );
  await _writer?.close();
  _writer = SerialFileLogWriter(file.openWrite(mode: FileMode.append));
}

Future<void> _removeExpiredLogs(Directory directory) async {
  final cutoff = DateTime.now().subtract(const Duration(days: 7));
  await for (final entity in directory.list()) {
    if (entity is! File || !entity.path.endsWith('.log')) continue;
    try {
      final modified = await entity.lastModified();
      if (modified.isBefore(cutoff)) await entity.delete();
    } catch (_) {}
  }
}

void writeFileLogLine(String line) {
  _writer?.writeLine(line);
}

Future<void> closeFileLogSink() async {
  final writer = _writer;
  _writer = null;
  await writer?.close();
}

Future<String?> getLogDirectoryPath() async {
  if (_logDirectory == null) await initializeFileLogSink();
  return _logDirectory?.path;
}

Future<bool> openLogDirectory() async {
  if (Platform.isAndroid) {
    try {
      return await _androidLogsChannel.invokeMethod<bool>('open') ?? false;
    } catch (_) {
      return false;
    }
  }
  final path = await getLogDirectoryPath();
  if (path == null) return false;
  try {
    final result = Platform.isWindows
        ? await Process.run('explorer.exe', [path])
        : Platform.isMacOS
        ? await Process.run('open', [path])
        : Platform.isLinux
        ? await Process.run('xdg-open', [path])
        : null;
    return result?.exitCode == 0;
  } catch (_) {
    return false;
  }
}
