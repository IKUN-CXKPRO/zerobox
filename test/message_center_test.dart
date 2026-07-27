import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/features/messages/application/message_center.dart';
import 'package:oronbox/src/host/application_host_provider.dart';

void main() {
  test(
    'opening a target marks the message read without waiting for network',
    () async {
      final host = _MessageHost();
      final container = ProviderContainer(
        overrides: [applicationHostProvider.overrideWithValue(host)],
      );
      addTearDown(container.dispose);

      await container.read(messageCenterProvider.future);
      final pending = container.read(messageCenterProvider.notifier).read('m1');
      await Future<void>.delayed(Duration.zero);

      final optimistic = container.read(messageCenterProvider).requireValue;
      expect(optimistic.messages.single.read, isTrue);
      expect(optimistic.unread, 0);

      host.readGate.complete();
      await pending;
    },
  );
}

class _MessageHost implements OronBoxCommandBus {
  final readGate = Completer<void>();

  @override
  Stream<CommandEvent> get events => const Stream.empty();

  @override
  Future<CommandResult> execute(OronBoxCommand command) async {
    if (command.method == 'message.list') {
      return CommandResult.success({
        'unread': 1,
        'messages': [
          {
            'id': 'm1',
            'kind': 'comment',
            'title': 'Reply',
            'body': 'Body',
            'created_at': '2026-07-27T12:00:00Z',
            'target_resource_id': 'resource-1',
            'target_comment_id': 'comment-1',
          },
        ],
      });
    }
    if (command.method == 'message.read') {
      await readGate.future;
      return const CommandResult.success(<String, Object?>{});
    }
    return CommandResult.failure(CommandError('unexpected', command.method));
  }

  @override
  Future<void> close() async {}
}
