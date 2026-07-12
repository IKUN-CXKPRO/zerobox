import 'dart:io';

String get daemonRuntimeDirectory {
  final environment = Platform.environment;
  if (Platform.isWindows) {
    final base = environment['LOCALAPPDATA'] ?? Directory.systemTemp.path;
    return '$base${Platform.pathSeparator}ZeroBox${Platform.pathSeparator}run';
  }
  if (Platform.isMacOS) {
    final home = environment['HOME'] ?? Directory.systemTemp.path;
    return '$home/Library/Application Support/ZeroBox/run';
  }
  final runtime = environment['XDG_RUNTIME_DIR'];
  if (runtime?.isNotEmpty == true) return '$runtime/zerobox';
  final home = environment['HOME'] ?? Directory.systemTemp.path;
  return '$home/.local/share/zerobox/run';
}

String get daemonSocketPath => '$daemonRuntimeDirectory/daemon.sock';

String get legacyDaemonSocketPath {
  final user =
      Platform.environment['USER'] ??
      Platform.environment['USERNAME'] ??
      'user';
  return '${Directory.systemTemp.path}/zerobox-$user.sock';
}

const daemonWindowsPort = 47832;
String get daemonWindowsTokenPath =>
    '$daemonRuntimeDirectory${Platform.pathSeparator}daemon.token';
