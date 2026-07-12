import 'dart:async';
import 'dart:io';

import 'package:zerobox/src/commands/command_protocol.dart';
import 'package:zerobox/src/daemon/daemon_client.dart';
import 'package:zerobox/src/daemon/daemon_task_models.dart';

Stream<List<DaemonTaskView>> watchDaemonTasks() async* {
  if (!Platform.isLinux && !Platform.isMacOS && !Platform.isWindows) return;
  final client = await _connectOrStart();
  final tasks = <String, DaemonTaskView>{};
  final initial = await client.execute(
    const ZeroBoxCommand(method: 'queue.list'),
  );
  if (initial.value is List) {
    for (final row in (initial.value as List).whereType<Map>()) {
      final task = DaemonTaskView.fromJson(row.cast<String, Object?>());
      tasks[task.id] = task;
    }
  }
  yield _sorted(tasks);

  final updates = StreamController<List<DaemonTaskView>>();
  final subscription = client.events.listen((event) {
    if (event.event == 'task.removed') {
      tasks.remove(event.data['id']?.toString());
      updates.add(_sorted(tasks));
      return;
    }
    if (event.event != 'task') return;
    final task = DaemonTaskView.fromJson(event.data);
    tasks[task.id] = task;
    updates.add(_sorted(tasks));
  });
  try {
    yield* updates.stream;
  } finally {
    await subscription.cancel();
    await updates.close();
    await client.close();
  }
}

List<DaemonTaskView> _sorted(Map<String, DaemonTaskView> tasks) =>
    tasks.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

Future<ZeroBoxDaemonClient> _connectOrStart() async {
  try {
    return await ZeroBoxDaemonClient.connect();
  } catch (_) {
    await Process.start(Platform.resolvedExecutable, const [
      '--nogui',
      'daemon',
      'run',
    ], mode: ProcessStartMode.detached);
    for (var attempt = 0; attempt < 50; attempt += 1) {
      try {
        return await ZeroBoxDaemonClient.connect();
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    rethrow;
  }
}

Future<void> cancelDaemonTask(String id) => _taskCommand('queue.cancel', id);
Future<void> removeDaemonTask(String id) => _taskCommand('queue.remove', id);
Future<void> clearDaemonTasks() async {
  final client = await _connectOrStart();
  try {
    await client.execute(const ZeroBoxCommand(method: 'queue.clear'));
  } finally {
    await client.close();
  }
}

Future<void> _taskCommand(String method, String id) async {
  final client = await _connectOrStart();
  try {
    final result = await client.execute(
      ZeroBoxCommand(method: method, params: {'id': id}),
    );
    if (!result.ok) throw StateError(result.error!.message);
  } finally {
    await client.close();
  }
}
