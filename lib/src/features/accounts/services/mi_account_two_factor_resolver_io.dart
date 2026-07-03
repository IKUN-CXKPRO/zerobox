import 'dart:async';
import 'dart:io';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'mi_account_two_factor_resolver_base.dart';

MiAccountTwoFactorResolver createPlatformMiAccountTwoFactorResolver() {
  if (Platform.isAndroid || Platform.isLinux) {
    return const NativeMiAccountTwoFactorResolver();
  }
  if (Platform.isMacOS || Platform.isWindows) {
    return const DesktopMiAccountTwoFactorResolver();
  }
  return const UnsupportedIoMiAccountTwoFactorResolver();
}

class NativeMiAccountTwoFactorResolver implements MiAccountTwoFactorResolver {
  const NativeMiAccountTwoFactorResolver();

  static const _method = MethodChannel('zerobox/mi_account_2fa');

  @override
  Future<String> resolve(BuildContext context, Uri notificationUrl) async {
    final cookieHeader = await _method.invokeMethod<String>('resolve', {
      'url': notificationUrl.toString(),
    });
    if (cookieHeader == null || cookieHeader.trim().isEmpty) {
      throw StateError('Xiaomi 2FA did not return account cookies');
    }
    return cookieHeader;
  }
}

class DesktopMiAccountTwoFactorResolver implements MiAccountTwoFactorResolver {
  const DesktopMiAccountTwoFactorResolver();

  @override
  Future<String> resolve(BuildContext context, Uri notificationUrl) async {
    if (Platform.isWindows && !await WebviewWindow.isWebviewAvailable()) {
      throw StateError('WebView2 Runtime is not available');
    }

    final completer = Completer<String>();
    Timer? timer;
    final webview = await WebviewWindow.create(
      configuration: CreateConfiguration(
        title: '小米账号验证',
        windowWidth: 460,
        windowHeight: 720,
        titleBarHeight: Platform.isLinux ? 0 : 40,
        titleBarTopPadding: Platform.isMacOS ? 20 : 0,
        userDataFolderWindows: await _desktopWebViewPath(),
      ),
    );

    Future<void> inspectCompletion() async {
      if (completer.isCompleted) return;
      try {
        final header = await _desktopCookieHeader(webview);
        final okSignal = await _desktopBodyIsOk(webview);
        if (_hasXiaomiSessionCookie(header) || okSignal) {
          if (header.trim().isEmpty) {
            timer?.cancel();
            completer.completeError(
              StateError('Xiaomi 2FA returned ok without account cookies'),
            );
            webview.close();
            return;
          }
          timer?.cancel();
          completer.complete(header);
          webview.close();
        }
      } catch (_) {
        // The native window can close while a polling call is in flight.
      }
    }

    webview
      ..setApplicationNameForUserAgent(' ZeroBox/1.0')
      ..setOnUrlRequestCallback((_) {
        unawaited(inspectCompletion());
        return true;
      })
      ..launch(notificationUrl.toString());

    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(inspectCompletion());
    });
    webview.onClose.whenComplete(() {
      timer?.cancel();
      if (!completer.isCompleted) {
        completer.completeError(StateError('Xiaomi 2FA window was closed'));
      }
    });

    return completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        webview.close();
        throw TimeoutException('Timed out waiting for Xiaomi 2FA');
      },
    );
  }
}

class UnsupportedIoMiAccountTwoFactorResolver
    implements MiAccountTwoFactorResolver {
  const UnsupportedIoMiAccountTwoFactorResolver();

  @override
  Future<String> resolve(BuildContext context, Uri notificationUrl) {
    throw UnsupportedError('This platform does not support Xiaomi 2FA WebView');
  }
}

Future<String> _desktopWebViewPath() async {
  final support = await getApplicationSupportDirectory();
  return '${support.path}${Platform.pathSeparator}mi_account_webview';
}

Future<String> _desktopCookieHeader(Webview webview) async {
  if (Platform.isLinux) {
    final raw = await webview.evaluateJavaScript('document.cookie');
    return _decodeJavaScriptString(raw);
  }

  final cookies = await webview.getAllCookies();
  return _cookieHeader(
    cookies.where(_isXiaomiCookie).map((cookie) {
      return MapEntry(cookie.name, cookie.value);
    }),
  );
}

Future<bool> _desktopBodyIsOk(Webview webview) async {
  try {
    final raw = await webview.evaluateJavaScript(
      "(document.body && document.body.innerText || '').trim()",
    );
    final text = _decodeJavaScriptString(raw).trim().toLowerCase();
    return text == 'ok' || text.endsWith('\nok');
  } catch (_) {
    return false;
  }
}

bool _isXiaomiCookie(dynamic cookie) {
  try {
    return (cookie.domain as String).toLowerCase().contains('xiaomi.com');
  } catch (_) {
    return false;
  }
}

String _decodeJavaScriptString(String? value) {
  var text = (value ?? '').trim();
  if (text.length >= 2 && text.startsWith('"') && text.endsWith('"')) {
    text = text.substring(1, text.length - 1);
  }
  return text.replaceAll(r'\n', '\n').replaceAll(r'\"', '"').trim();
}

String _cookieHeader(Iterable<MapEntry<String, String>> pairs) {
  final values = <String, String>{};
  for (final pair in pairs) {
    final name = pair.key.trim();
    final value = pair.value.trim();
    if (name.isEmpty || value.isEmpty) continue;
    values[name] = value;
  }
  return values.entries
      .map((entry) => '${entry.key}=${entry.value}')
      .join('; ');
}

bool _hasXiaomiSessionCookie(String cookieHeader) {
  final names = cookieHeader.split(';').map((pair) {
    final index = pair.indexOf('=');
    if (index <= 0) return '';
    return pair.substring(0, index).trim();
  }).toSet();
  return names.contains('passToken') ||
      names.contains('cUserId') ||
      names.contains('userId');
}
