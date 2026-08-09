import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/router/app_router.dart';
import 'package:oronbox/src/core/constants/app_constants.dart';
import 'package:oronbox/src/core/providers/app_settings_providers.dart';
import 'package:oronbox/src/core/services/build_info_service.dart';
import 'package:oronbox/src/features/oobe/oobe_state.dart';
import 'package:oronbox/src/features/settings/services/oronbox_support_api.dart';
import 'package:oronbox/src/features/settings/widgets/update_download_dialog.dart';

/// Clears APKs left behind by previous in-app update flows.
Future<void> clearStaleApks() async {
  try {
    final dir = await getApplicationSupportDirectory();
    final apkDir = Directory('${dir.path}/apk');
    if (await apkDir.exists()) {
      await apkDir.delete(recursive: true);
    }
  } catch (_) {
    // Best effort; a leftover APK is harmless.
  }
}

/// Compares dotted version strings numerically (1.0.0.rc.3 < 1.0.0).
int compareVersions(String a, String b) {
  final left = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  final right = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  final length = left.length > right.length ? left.length : right.length;
  for (var i = 0; i < length; i++) {
    final l = i < left.length ? left[i] : 0;
    final r = i < right.length ? right[i] : 0;
    if (l != r) return l - r;
  }
  return 0;
}

/// Strips a leading 'v' and any '+build' suffix so releases compare cleanly.
String normalizeVersion(String version) =>
    version.replaceFirst(RegExp(r'^v'), '').split('+').first;

/// Startup update flow: cleans stale APKs, then (when enabled and first-run
/// onboarding is done) fetches the latest release and shows a changelog
/// dialog.
class UpdateCheckHandler extends ConsumerStatefulWidget {
  const UpdateCheckHandler({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UpdateCheckHandler> createState() =>
      _UpdateCheckHandlerState();
}

class _UpdateCheckHandlerState extends ConsumerState<UpdateCheckHandler> {
  @override
  void initState() {
    super.initState();
    // Wait for the first frame and OOBE to settle before prompting.
    Future.delayed(const Duration(seconds: 3), _run);
  }

  Future<void> _run() async {
    await clearStaleApks();
    if (!mounted) return;
    try {
      final settings = ref.read(appSettingsProvider);
      if (!settings.checkUpdateOnLaunch) return;
      if (!isOobeCompleted()) return;
      final language =
          Localizations.localeOf(context).languageCode == 'en' ? 'en' : 'zh';
      final release = await ref
          .read(oronBoxSupportApiProvider)
          .latestRelease(
            language: language,
            currentVersion: BuildInfoService.appVersion,
          );
      final latest = normalizeVersion(release.latestVersion);
      final current = normalizeVersion(BuildInfoService.appVersion);
      if (compareVersions(latest, current) <= 0) return;
      final navigator = rootNavigatorKey.currentState;
      if (!mounted || navigator == null) return;
      // The dialog's render tree must be laid out before any pointer event
      // can arrive; otherwise hit-testing runs into a size-less render box
      // (seen on desktop Linux right after startup).
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      showDialog<void>(
        context: navigator.context,
        builder: (_) => UpdateAvailableDialog(release: release),
      );
    } catch (_) {
      // Update check must never break startup.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Changelog dialog shown at startup when a newer release exists.
class UpdateAvailableDialog extends ConsumerWidget {
  const UpdateAvailableDialog({super.key, required this.release});

  final AppReleaseInfo release;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isAndroid = Platform.isAndroid;
    return AlertDialog(
      title: Text(l10n.newVersionAvailable(release.latestVersion)),
      content: SizedBox(
        // AlertDialog measures intrinsic width on its content; a fixed
        // width stops that query from reaching the Markdown viewport,
        // which cannot report intrinsic dimensions and crashes layout.
        width: 420,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: SingleChildScrollView(
            child: Markdown(
              data: release.releaseNotes,
              // The package pads its viewport by default; the dialog already
              // has its own insets.
              shrinkWrap: true,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.updateLater),
        ),
        if (isAndroid)
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              final navigator = rootNavigatorKey.currentState;
              if (navigator != null) {
                showDialog<void>(
                  context: navigator.context,
                  builder: (_) => UpdateDownloadDialog(release: release),
                );
              }
            },
            child: Text(l10n.updateNow),
          )
        else
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              final isEn =
                  Localizations.localeOf(context).languageCode == 'en';
              _openUrl(isEn
                  ? '${AppConstants.websiteUrl}/en/download'
                  : '${AppConstants.websiteUrl}/download');
            },
            child: Text(l10n.updateGoToPage),
          ),
      ],
    );
  }
}

Future<void> _openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
