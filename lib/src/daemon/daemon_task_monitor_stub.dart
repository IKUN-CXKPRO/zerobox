import 'package:zerobox/src/daemon/daemon_task_models.dart';

Stream<List<DaemonTaskView>> watchDaemonTasks() => const Stream.empty();
Future<void> cancelDaemonTask(String id) async {}
Future<void> removeDaemonTask(String id) async {}
Future<void> clearDaemonTasks() async {}
