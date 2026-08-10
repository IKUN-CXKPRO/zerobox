import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/router/app_router.dart';
import 'package:oronbox/src/features/resources/widgets/resource_install_confirmation.dart';

/// File extensions the app claims as "open with" targets. Content is still
/// detected by magic bytes; the extension only decides which hint to pass to
/// the analyzer (`.bin` is usually firmware, everything else starts as app).
const _handledExtensions = <String>{'rpk', 'bin', 'face', 'zpk', 'mwz'};

/// Receives files opened with OronBox from the OS file manager. Every native
/// platform pushes the resolved local path through the `oronbox/file_open`
/// method channel (cold and warm start alike), so this widget only needs one
/// listener; it then routes the file through the same confirmation/enqueue
/// flow used by drag-and-drop.
class FileOpenHandler extends ConsumerStatefulWidget {
  const FileOpenHandler({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<FileOpenHandler> createState() => _FileOpenHandlerState();
}

class _FileOpenHandlerState extends ConsumerState<FileOpenHandler> {
  static const _channel = MethodChannel('oronbox/file_open');
  final Set<String> _handledPaths = {};

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler(_handleCall);
    // Cold start: the native side may have received an "open with" intent
    // before Flutter finished initializing, so it cannot push through the
    // channel yet; pull the initial file once the first frame is up.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final initial = await _channel.invokeMethod<String?>('getInitialFile');
      if (initial != null && mounted) {
        await _openFile(initial);
      }
    });
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  Future<Object?> _handleCall(MethodCall call) async {
    if (call.method == 'openFile') {
      final path = call.arguments as String?;
      if (path != null && mounted) {
        await _openFile(path);
      }
    }
    return null;
  }

  Future<void> _openFile(String path) async {
    if (!_handledExtensions.contains(_extensionOf(path))) return;
    if (!_handledPaths.add(path)) return;
    final file = XFile(path);
    final navigatorContext = rootNavigatorKey.currentContext;
    if (navigatorContext == null) return;
    // Opened externally: nobody picked a type, so leave selectedType unset and
    // let the analyzer's result decide; unknown files are simply rejected.
    final enqueued = await confirmAndEnqueueResourceFile(
      context: navigatorContext,
      ref: ref,
      file: file,
    );
    if (!mounted || !navigatorContext.mounted || !enqueued) return;
    ScaffoldMessenger.of(navigatorContext).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(navigatorContext)!.queueAddedFiles(1),
        ),
      ),
    );
  }

  static String _extensionOf(String path) {
    final name = path.split(RegExp(r'[/\\]')).last;
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
