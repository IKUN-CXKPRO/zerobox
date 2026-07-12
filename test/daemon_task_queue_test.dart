import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerobox/src/commands/command_protocol.dart';
import 'package:zerobox/src/core/services/shared_prefs_service.dart';
import 'package:zerobox/src/daemon/daemon_task_queue.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.instance.init();
  });

  test('runs queued commands strictly one at a time', () async {
    final bus = _DelayedBus();
    final queue = DaemonTaskQueue(bus);
    final first = queue.enqueue(const ZeroBoxCommand(method: 'first'));
    final second = queue.enqueue(const ZeroBoxCommand(method: 'second'));

    expect((await queue.wait(first))?.status, 'completed');
    expect((await queue.wait(second))?.status, 'completed');
    expect(bus.maxActive, 1);
    expect(bus.methods, ['first', 'second']);
    await queue.close();
  });

  test('cancelling a running task invokes the cancellation hook', () async {
    final bus = _BlockingBus();
    late final DaemonTaskQueue queue;
    queue = DaemonTaskQueue(bus, onCancelRunning: () async => bus.release());
    final id = queue.enqueue(const ZeroBoxCommand(method: 'install.local'));
    await bus.started.future;

    expect(queue.cancel(id), isTrue);
    expect((await queue.wait(id))?.status, 'cancelled');
    expect(bus.cancelled, isTrue);
    await queue.close();
  });
}

class _DelayedBus implements ZeroBoxCommandBus {
  int active = 0;
  int maxActive = 0;
  final methods = <String>[];

  @override
  Stream<CommandEvent> get events => const Stream.empty();

  @override
  Future<CommandResult> execute(ZeroBoxCommand command) async {
    active += 1;
    maxActive = active > maxActive ? active : maxActive;
    methods.add(command.method);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    active -= 1;
    return const CommandResult.success();
  }

  @override
  Future<void> close() async {}
}

class _BlockingBus implements ZeroBoxCommandBus {
  final started = Completer<void>();
  final _release = Completer<void>();
  bool cancelled = false;

  void release() {
    cancelled = true;
    if (!_release.isCompleted) _release.complete();
  }

  @override
  Stream<CommandEvent> get events => const Stream.empty();

  @override
  Future<CommandResult> execute(ZeroBoxCommand command) async {
    if (!started.isCompleted) started.complete();
    await _release.future;
    return const CommandResult.failure(
      CommandError('cancelled', 'Operation was cancelled'),
    );
  }

  @override
  Future<void> close() async {}
}
