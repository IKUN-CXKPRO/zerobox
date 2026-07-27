import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/host/application_host_provider.dart';

final messageCenterProvider =
    AsyncNotifierProvider<MessageCenterController, MessageCenterState>(
      MessageCenterController.new,
    );

class MessageCenterController extends AsyncNotifier<MessageCenterState> {
  @override
  Future<MessageCenterState> build() => _load();
  Future<MessageCenterState> _load() async {
    final result = await ref
        .read(applicationHostProvider)
        .execute(const OronBoxCommand(method: 'message.list'));
    if (!result.ok) return const MessageCenterState();
    final root = (result.value as Map).cast<String, Object?>();
    return MessageCenterState(
      unread: (root['unread'] as num?)?.toInt() ?? 0,
      messages: (root['messages'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => UserMessage.fromJson(item.cast<String, Object?>()))
          .toList(),
    );
  }

  Future<void> refresh() async => state = AsyncData(await _load());
  Future<void> read(String id) async {
    final current = state.value;
    if (current != null) {
      final wasUnread = current.messages.any(
        (message) => message.id == id && !message.read,
      );
      state = AsyncData(
        MessageCenterState(
          unread: wasUnread && current.unread > 0
              ? current.unread - 1
              : current.unread,
          messages: current.messages
              .map(
                (message) =>
                    message.id == id ? message.copyWith(read: true) : message,
              )
              .toList(growable: false),
        ),
      );
    }
    await ref
        .read(applicationHostProvider)
        .execute(
          OronBoxCommand(method: 'message.read', params: {'message': id}),
        );
  }

  Future<bool> clear() async {
    final result = await ref
        .read(applicationHostProvider)
        .execute(const OronBoxCommand(method: 'message.clear'));
    if (!result.ok) return false;
    state = const AsyncData(MessageCenterState());
    return true;
  }
}

class MessageCenterState {
  const MessageCenterState({this.messages = const [], this.unread = 0});
  final List<UserMessage> messages;
  final int unread;
}

class UserMessage {
  const UserMessage({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.read,
    required this.targetResourceId,
    required this.targetCommentId,
  });
  final String id, kind, title, body, targetResourceId, targetCommentId;
  final DateTime createdAt;
  final bool read;
  UserMessage copyWith({bool? read}) => UserMessage(
    id: id,
    kind: kind,
    title: title,
    body: body,
    createdAt: createdAt,
    read: read ?? this.read,
    targetResourceId: targetResourceId,
    targetCommentId: targetCommentId,
  );

  factory UserMessage.fromJson(Map<String, Object?> json) => UserMessage(
    id: json['id']?.toString() ?? '',
    kind: json['kind']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    body: json['body']?.toString() ?? '',
    createdAt:
        DateTime.tryParse(json['created_at']?.toString() ?? '') ??
        DateTime.now(),
    read: json['read_at'] != null,
    targetResourceId: json['target_resource_id']?.toString() ?? '',
    targetCommentId: json['target_comment_id']?.toString() ?? '',
  );
}
