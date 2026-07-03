import 'desktop_webview_bootstrap_stub.dart'
    if (dart.library.io) 'desktop_webview_bootstrap_io.dart';

bool runDesktopWebViewBootstrap(List<String> args) {
  return runPlatformDesktopWebViewBootstrap(args);
}
