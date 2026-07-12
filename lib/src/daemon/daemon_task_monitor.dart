import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/daemon/daemon_task_models.dart';
import 'package:zerobox/src/daemon/daemon_task_monitor_impl.dart';

final daemonTasksProvider = StreamProvider<List<DaemonTaskView>>(
  (ref) => watchDaemonTasks(),
);
