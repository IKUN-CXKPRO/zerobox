import 'dart:io';
import 'dart:ffi';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:oronbox/src/core/services/build_info_service.dart';

const _androidLogsChannel = MethodChannel('oronbox/logs');

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

Future<void> initializeFileLogSink({List<String> arguments = const []}) async {
  final support = await getApplicationSupportDirectory();
  final directory = Directory('${support.path}${Platform.pathSeparator}logs');
  await directory.create(recursive: true);
  _logDirectory = directory;
  await _removeExpiredLogs(directory);
  final now = DateTime.now();
  final timestamp =
      '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}_'
      '${now.hour.toString().padLeft(2, '0')}-'
      '${now.minute.toString().padLeft(2, '0')}-'
      '${now.second.toString().padLeft(2, '0')}-'
      '${now.millisecond.toString().padLeft(3, '0')}';
  final file = File(
    '${directory.path}${Platform.pathSeparator}oronbox-$timestamp-$pid.log',
  );
  await _writer?.close();
  _writer = SerialFileLogWriter(file.openWrite(mode: FileMode.write));
  final commit = await BuildInfoService.resolveCommitHash();
  _writer!.writeLine('OronBox ${BuildInfoService.appVersion} ($commit)');
  _writer!.writeLine('Builder: ${BuildInfoService.buildUser}');
  _writer!.writeLine('Started: ${now.toIso8601String()}');
  _writer!.writeLine(
    'Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
  );
  _writer!.writeLine('Architecture: ${Abi.current()}');
  _writer!.writeLine('Dart: ${Platform.version}');
  _writer!.writeLine('Process: $pid');
  _writer!.writeLine(
    'Arguments: ${arguments.length} value(s), content omitted',
  );
  _writer!.writeLine('');
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

Future<int> logDirectorySize() async {
  final path = await getLogDirectoryPath();
  if (path == null) return 0;
  var total = 0;
  await for (final entity in Directory(path).list()) {
    if (entity is File && entity.path.endsWith('.log')) {
      total += await entity.length();
    }
  }
  return total;
}

Future<int> clearLogFiles() async {
  final path = await getLogDirectoryPath();
  if (path == null) return 0;
  final files = <File>[];
  await for (final entity in Directory(path).list()) {
    if (entity is File && entity.path.endsWith('.log')) files.add(entity);
  }
  // Keep the current session's file so the live writer keeps a valid sink.
  files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
  var removed = 0;
  for (final file in files.skip(1)) {
    try {
      await file.delete();
      removed++;
    } catch (_) {}
  }
  return removed;
}

Future<String?> exportLogsZip() async {
  final path = await getLogDirectoryPath();
  if (path == null) return null;
  final archive = Archive();
  await for (final entity in Directory(path).list()) {
    if (entity is! File || !entity.path.endsWith('.log')) continue;
    final bytes = await entity.readAsBytes();
    archive.addFile(
      ArchiveFile(entity.uri.pathSegments.last, bytes.length, bytes),
    );
  }
  if (archive.isEmpty) return null;
  final zipped = ZipEncoder().encode(archive);
  final directory = await _exportDirectory();
  final now = DateTime.now();
  final timestamp =
      '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-'
      '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
  final target = File(
    '${directory.path}${Platform.pathSeparator}oronbox-logs-$timestamp.zip',
  );
  await target.writeAsBytes(zipped);
  return target.path;
}

Future<Directory> _exportDirectory() async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home != null) {
      final documents = Directory('$home${Platform.pathSeparator}Documents');
      if (await documents.exists()) return documents;
    }
  }
  return getApplicationDocumentsDirectory();
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
