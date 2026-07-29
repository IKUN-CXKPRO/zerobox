import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/host/application_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.instance.init();
  });

  test(
    'clients use the same host interface for direct and queued commands',
    () async {
      final core = _RecordingBus();
      final host = ApplicationHost(core);

      final direct = await host.execute(const OronBoxCommand(method: 'echo'));
      final queued = await host.execute(
        const OronBoxCommand(
          method: 'task.enqueue',
          params: {
            'command': {
              'method': 'install.local',
              'params': <String, Object?>{},
            },
          },
        ),
      );
      final taskId = (queued.value as Map)['taskId']!.toString();
      final completed = await host.execute(
        OronBoxCommand(method: 'queue.wait', params: {'id': taskId}),
      );

      expect(direct.value, {'method': 'echo'});
      expect((completed.value as Map)['status'], 'completed');
      expect(core.methods, ['echo', 'install.local']);

      await host.close();
    },
  );

  test(
    'held GUI tasks remain in the host until a client starts them',
    () async {
      final core = _RecordingBus();
      final host = ApplicationHost(core);
      final queued = await host.execute(
        const OronBoxCommand(
          method: 'task.enqueue',
          params: {
            'held': true,
            'command': {
              'method': 'install.local',
              'params': <String, Object?>{},
            },
          },
        ),
      );
      final taskId = (queued.value as Map)['taskId']!.toString();

      await Future<void>.delayed(Duration.zero);
      final held = await host.execute(
        OronBoxCommand(method: 'queue.get', params: {'id': taskId}),
      );
      expect((held.value as Map)['status'], 'held');
      expect(core.methods, isEmpty);

      await host.execute(const OronBoxCommand(method: 'queue.start'));
      final completed = await host.execute(
        OronBoxCommand(method: 'queue.wait', params: {'id': taskId}),
      );
      expect((completed.value as Map)['status'], 'completed');
      expect(core.methods, ['install.local']);

      await host.close();
    },
  );

  test('download completion creates a host-owned install task', () async {
    final core = _ResourceBus(autoInstall: false, disableAutoClean: true);
    final host = ApplicationHost(core);
    final queued = await host.execute(
      const OronBoxCommand(
        method: 'task.enqueue',
        params: {
          'command': {
            'method': 'resource.download',
            'params': {
              'ref': 'bandbbs:1',
              'file': 'main',
              'targetDevice': 'o65m',
              'title': 'Resource',
              'queueInstall': true,
              'autoClean': true,
            },
          },
        },
      ),
    );
    final downloadId = (queued.value as Map)['taskId']!.toString();
    await host.execute(
      OronBoxCommand(method: 'queue.wait', params: {'id': downloadId}),
    );
    final listed = await host.execute(
      const OronBoxCommand(method: 'queue.list'),
    );
    final rows = (listed.value as List).whereType<Map>().toList();
    final install = rows.firstWhere(
      (row) => (row['command'] as Map)['method'] == 'install.local',
    );

    expect(install['status'], 'held');
    expect((install['command'] as Map)['params']['path'], '/tmp/resource.rpk');
    await host.close();
  });

  test('firmware file download completion creates an install task', () async {
    final core = _ResourceBus(autoInstall: false, disableAutoClean: true);
    final host = ApplicationHost(core);
    final queued = await host.execute(
      const OronBoxCommand(
        method: 'task.enqueue',
        params: {
          'command': {
            'method': 'file.download',
            'params': {
              'url': 'https://example.com/firmware.bin',
              'fileName': 'firmware.bin',
              'title': 'firmware.bin',
              'queueInstall': true,
              'installType': 'firmware',
              'autoClean': true,
            },
          },
        },
      ),
    );
    final downloadId = (queued.value as Map)['taskId']!.toString();
    await host.execute(
      OronBoxCommand(method: 'queue.wait', params: {'id': downloadId}),
    );
    final listed = await host.execute(
      const OronBoxCommand(method: 'queue.list'),
    );
    final rows = (listed.value as List).whereType<Map>().toList();
    final install = rows.firstWhere(
      (row) => (row['command'] as Map)['method'] == 'install.local',
    );

    expect(install['status'], 'held');
    expect((install['command'] as Map)['params'], {
      'type': 'firmware',
      'path': '/tmp/firmware.bin',
      'title': 'firmware.bin',
      'description': '',
      'deleteAfter': true,
      'autoClean': true,
    });
    await host.close();
  });
}

class _RecordingBus implements OronBoxCommandBus {
  final methods = <String>[];
  final _events = StreamController<CommandEvent>.broadcast();

  @override
  Stream<CommandEvent> get events => _events.stream;

  @override
  Future<CommandResult> execute(OronBoxCommand command) async {
    methods.add(command.method);
    return CommandResult.success({'method': command.method});
  }

  @override
  Future<void> close() => _events.close();
}

class _ResourceBus implements OronBoxCommandBus {
  _ResourceBus({required this.autoInstall, required this.disableAutoClean});

  final bool autoInstall;
  final bool disableAutoClean;

  @override
  Stream<CommandEvent> get events => const Stream.empty();

  @override
  Future<CommandResult> execute(OronBoxCommand command) async {
    if (command.method == 'resource.download') {
      return const CommandResult.success({
        'path': '/tmp/resource.rpk',
        'fileName': 'resource.rpk',
        'type': 'quickapp',
      });
    }
    if (command.method == 'file.download') {
      return const CommandResult.success({
        'path': '/tmp/firmware.bin',
        'fileName': 'firmware.bin',
      });
    }
    if (command.method == 'settings.get') {
      final key = command.params['key'];
      return CommandResult.success({
        'key': key,
        'value': key == 'auto_install' ? autoInstall : disableAutoClean,
      });
    }
    return const CommandResult.success();
  }

  @override
  Future<void> close() async {}
}
