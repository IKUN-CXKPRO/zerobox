import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/commands/command_protocol.dart';
import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/host/application_host_provider.dart';

class LogWindowController extends Notifier<bool> {
  static const _channel = MethodChannel('zerobox/log_window');

  StreamSubscription<String>? _localSubscription;
  StreamSubscription<CommandEvent>? _hostSubscription;

  @override
  bool build() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'closed') {
        await _stopStreaming();
        state = false;
      }
    });
    ref.onDispose(() {
      _channel.setMethodCallHandler(null);
      unawaited(_stopStreaming());
    });
    return false;
  }

  Future<void> setOpen(bool open, {ThemeData? theme}) async {
    if (open == state) return;
    if (!open) {
      await _stopStreaming();
      await _channel.invokeMethod<void>('close');
      state = false;
      return;
    }

    final colorScheme = theme?.colorScheme;
    await _channel.invokeMethod<void>('open', {
      'dark': theme?.brightness == Brightness.dark,
      if (colorScheme != null) ...{
        'surface': colorScheme.surface.toARGB32(),
        'surfaceContainer': colorScheme.surfaceContainer.toARGB32(),
        'surfaceContainerLowest': colorScheme.surfaceContainerLowest.toARGB32(),
        'onSurface': colorScheme.onSurface.toARGB32(),
        'onSurfaceVariant': colorScheme.onSurfaceVariant.toARGB32(),
        'outline': colorScheme.outlineVariant.toARGB32(),
        'primary': colorScheme.primary.toARGB32(),
        'onPrimary': colorScheme.onPrimary.toARGB32(),
      },
    });
    state = true;

    // Subscribe before loading history so no new record can fall through the
    // gap between opening the native window and attaching the live streams.
    _localSubscription = zeroBoxLogStream.listen(_append);
    final host = ref.read(applicationHostProvider);
    _hostSubscription = host.events.listen((event) {
      if (event.event == 'log') {
        final message = event.data['message']?.toString();
        if (message != null && message.isNotEmpty) _append(message);
      }
    });

    await _appendMany(recentZeroBoxLogs);
    final result = await host.execute(
      const ZeroBoxCommand(method: 'logs.recent'),
    );
    if (result.ok && result.value is List) {
      await _appendMany((result.value! as List).map((line) => line.toString()));
    } else if (result.error != null) {
      await _append('[日志窗口] 无法读取 daemon 历史日志: ${result.error!.message}');
    }
  }

  Future<void> _append(String line) =>
      _channel.invokeMethod<void>('append', {'line': line});

  Future<void> _appendMany(Iterable<String> lines) async {
    final values = lines.toList(growable: false);
    if (values.isEmpty) return;
    await _channel.invokeMethod<void>('appendMany', {'lines': values});
  }

  Future<void> _stopStreaming() async {
    await _localSubscription?.cancel();
    await _hostSubscription?.cancel();
    _localSubscription = null;
    _hostSubscription = null;
  }
}

final logWindowProvider = NotifierProvider<LogWindowController, bool>(
  LogWindowController.new,
);
