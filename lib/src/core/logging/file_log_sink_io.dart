import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

const _androidLogsChannel = MethodChannel('zerobox/logs');

IOSink? _sink;
Directory? _logDirectory;

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
  _sink = file.openWrite(mode: FileMode.append);
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
  final sink = _sink;
  if (sink == null) return;
  sink.writeln(line);
  unawaited(sink.flush());
}

Future<void> closeFileLogSink() async {
  await _sink?.flush();
  await _sink?.close();
  _sink = null;
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
