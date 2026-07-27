import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/app/widgets/app_icon.dart';
import 'package:oronbox/src/core/constants/app_constants.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/core/logging/file_log_sink.dart';
import 'package:oronbox/src/core/services/build_info_service.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/host/application_host_provider.dart';
import 'package:oronbox/src/features/settings/pages/legal_documents_page.dart';
import 'package:oronbox/src/features/settings/services/oronbox_support_api.dart';

class AboutSoftwarePage extends ConsumerWidget {
  const AboutSoftwarePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text(l10n.settingsAboutSoftware),
      ),
      body: SingleChildScrollView(
        child: PageContainer(
          maxWidth: 1000,
          padding: const EdgeInsets.symmetric(
            horizontal: StyleConstants.pagePadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _AboutHeader(),
              const SizedBox(height: 12),
              _Section(
                icon: Icons.people_alt_outlined,
                title: l10n.settingsAboutSoftwareTeam,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final member in AppConstants.teamMembers)
                      _TeamMemberTile(member: member),
                  ],
                ),
              ),
              _Section(
                icon: Icons.gavel_outlined,
                title: l10n.legalAndPrivacy,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final document in [
                      ('terms', l10n.termsTitle),
                      ('privacy', l10n.privacyTitle),
                      ('resource-publishing', l10n.resourcePublishingTitle),
                      ('review-rules', l10n.reviewRulesTitle),
                    ])
                      FilledButton.tonalIcon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LegalDocumentPage(
                              id: document.$1,
                              title: document.$2,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.article_outlined),
                        label: Text(document.$2),
                      ),
                  ],
                ),
              ),
              _Section(
                icon: Icons.article_outlined,
                title: l10n.changelog,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.settingsAboutSoftwareReleaseName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.settingsAboutSoftwareReleaseBody,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              _Section(
                icon: Icons.terminal_outlined,
                title: l10n.settingsAboutSoftwareBuildInfo,
                child: FutureBuilder<String>(
                  future: BuildInfoService.resolveCommitHash(),
                  builder: (context, snapshot) {
                    final commit = snapshot.data ?? 'local';
                    return SelectableText(
                      'APP_VERSION: ${BuildInfoService.appVersion}\n'
                      'GIT_COMMIT_HASH: $commit\n'
                      'BUILD_USER: ${BuildInfoService.buildUser}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Text(
                  l10n.settingsAboutSoftwareCopyright,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _roleLabel(AppLocalizations l10n, TeamRole role) {
  return switch (role) {
    TeamRole.mainDeveloperDesigner => l10n.settingsTeamRoleMain,
    TeamRole.zeppOSImplementation => l10n.settingsTeamRoleZeppOS,
  };
}

Future<void> _openUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _AboutHeader extends ConsumerWidget {
  const _AboutHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        const SizedBox(height: 8),
        const AppIcon(size: 72),
        const SizedBox(height: 16),
        Text(
          'OronBox',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.settingsAboutSoftwareTagline,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 16),
        const _UpdatePill(),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            FilledButton.tonalIcon(
              onPressed: () => _openUrl(AppConstants.githubRepoUrl),
              icon: const Icon(Icons.code_outlined),
              label: Text(l10n.settingsAboutSoftwareRepository),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push('/settings/licenses'),
              icon: const Icon(Icons.description_outlined),
              label: Text(l10n.openSourceLicenses),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push('/settings/acknowledgements'),
              icon: const Icon(Icons.favorite_outline),
              label: Text(l10n.acknowledgements),
            ),
            OutlinedButton.icon(
              onPressed: () => _openUrl('https://oronbox.zxor.org'),
              icon: const Icon(Icons.language_outlined),
              label: Text(l10n.settingsAboutWebsite),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _UpdatePill extends ConsumerStatefulWidget {
  const _UpdatePill();

  @override
  ConsumerState<_UpdatePill> createState() => _UpdatePillState();
}

class _UpdatePillState extends ConsumerState<_UpdatePill> {
  var _checking = false;
  AppReleaseInfo? _found;
  var _newest = false;

  Future<void> _check() async {
    if (_checking) return;
    if (_found != null) {
      final url = _found!.downloadUrl.isNotEmpty
          ? _found!.downloadUrl
          : _found!.sourceUrl;
      if (url.isNotEmpty) _openUrl(url);
      return;
    }
    setState(() {
      _checking = true;
      _newest = false;
    });
    try {
      final release = await ref
          .read(oronBoxSupportApiProvider)
          .latestRelease(
            language: Localizations.localeOf(context).languageCode == 'en'
                ? 'en'
                : 'zh',
            currentVersion: BuildInfoService.appVersion,
          );
      if (!mounted) return;
      final current = BuildInfoService.appVersion.split('+').first;
      final latest = release.latestVersion
          .replaceFirst(RegExp(r'^v'), '')
          .split('+')
          .first;
      setState(() {
        _checking = false;
        if (_compareVersions(latest, current) > 0) {
          _found = release;
        } else {
          _newest = true;
        }
      });
      if (_newest) {
        Future<void>.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _newest = false);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final found = _found != null;
    final (icon, label) = _checking
        ? (null, l10n.updateChecking)
        : found
        ? (
            Icons.arrow_downward,
            l10n.newVersionAvailable(_found!.latestVersion),
          )
        : _newest
        ? (Icons.check, l10n.latestVersionInstalled)
        : (
            Icons.sync,
            'v${BuildInfoService.appVersion} · ${l10n.checkUpdates}',
          );
    return FilledButton.tonalIcon(
      style: found
          ? FilledButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
            )
          : null,
      onPressed: _checking ? null : _check,
      icon: icon == null
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

int _compareVersions(String a, String b) {
  final left = a.split('.').map((e) => int.tryParse(e) ?? 0).toList(),
      right = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  for (
    var i = 0;
    i < (left.length > right.length ? left.length : right.length);
    i++
  ) {
    final l = i < left.length ? left[i] : 0,
        r = i < right.length ? right[i] : 0;
    if (l != r) return l.compareTo(r);
  }
  return 0;
}

class RuntimeLogsPage extends ConsumerStatefulWidget {
  const RuntimeLogsPage({super.key});

  @override
  ConsumerState<RuntimeLogsPage> createState() => _RuntimeLogsPageState();
}

class _RuntimeLogsPageState extends ConsumerState<RuntimeLogsPage> {
  var _size = 0;
  var _busy = false;
  var _files = const <LogFileInfo>[];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final results = await Future.wait<Object>([
      logDirectorySize(),
      listLogFiles(),
    ]);
    if (mounted) {
      setState(() {
        _size = results[0] as int;
        _files = results[1] as List<LogFileInfo>;
      });
    }
  }

  String _fileSizeLabel(int size) {
    if (size >= 1024 * 1024) {
      return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(size / 1024).toStringAsFixed(size < 1024 ? 1 : 0)} KB';
  }

  String get _sizeLabel {
    if (_size >= 1024 * 1024) {
      return '${(_size / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(_size / 1024).toStringAsFixed(0)} KB';
  }

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    final path = await exportLogsZip();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          path == null
              ? l10n.settingsAboutLogsEmpty
              : l10n.settingsAboutLogsExported(path),
        ),
      ),
    );
  }

  Future<void> _clear() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsAboutLogsClear),
        content: Text(l10n.settingsAboutLogsClearConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.settingsAboutLogsClear),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await clearLogFiles();
    await _reload();
  }

  Future<void> _pullDeviceLogs() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settingsDeviceLogsPull),
        content: Text(l10n.settingsDeviceLogsTip),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.settingsDeviceLogsStart),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final progress = ValueNotifier<double>(0);
    final fileName = ValueNotifier<String>('');
    final cancelling = ValueNotifier<bool>(false);
    var cancelRequested = false;
    final dialogReady = Completer<BuildContext>();
    final host = ref.read(applicationHostProvider);
    final subscription = host.events.listen((event) {
      if (event.event != 'device.log.progress') return;
      progress.value = (event.data['progress'] as num?)?.toDouble() ?? 0;
      fileName.value = (event.data['fileName']?.toString() ?? '')
          .split(RegExp(r'[/\\]'))
          .last;
    });
    final dialogClosed = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        if (!dialogReady.isCompleted) dialogReady.complete(dialogContext);
        return _DeviceLogProgressDialog(
          progress: progress,
          fileName: fileName,
          cancelling: cancelling,
          onCancel: () async {
            if (cancelRequested) return;
            cancelRequested = true;
            cancelling.value = true;
            await host.execute(
              const OronBoxCommand(method: 'device.logs.cancel'),
            );
          },
        );
      },
    );
    final dialogContext = await dialogReady.future;
    try {
      final result = await host.execute(
        const OronBoxCommand(method: 'device.logs.pull'),
      );
      if (!result.ok) {
        throw StateError(result.error?.message ?? 'Unknown error');
      }
      final value = (result.value as Map).cast<String, Object?>();
      await _reload();
      if (mounted && !cancelRequested) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.settingsDeviceLogsSaved(value['name']?.toString() ?? ''),
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted && !cancelRequested) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.settingsDeviceLogsFailed('$error'))),
        );
      }
    } finally {
      if (dialogContext.mounted) Navigator.pop(dialogContext);
      await dialogClosed;
      await subscription.cancel();
      progress.dispose();
      fileName.dispose();
      cancelling.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openDirectory() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _LogDisclosureDialog(l10n: l10n),
    );
    if (confirmed != true || !mounted) return;
    final opened = await openLogDirectory();
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.settingsAboutLogsOpenFailed)));
    }
  }

  Future<void> _openFile(LogFileInfo file) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _LogDisclosureDialog(l10n: l10n),
    );
    if (confirmed != true || !mounted) return;
    final opened = await openLogFile(file);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.settingsAboutLogsOpenFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: SysAppBar(secondary: true, title: Text(l10n.settingsAboutLogs)),
      body: SingleChildScrollView(
        child: PageContainer(
          padding: const EdgeInsets.all(StyleConstants.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Section(
                icon: Icons.folder_outlined,
                title: l10n.settingsAboutLogsSize(_sizeLabel),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.settingsAboutLogsDescription,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _busy ? null : _openDirectory,
                          icon: const Icon(Icons.folder_open_outlined),
                          label: Text(l10n.settingsAboutLogsOpen),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _busy ? null : _export,
                          icon: const Icon(Icons.archive_outlined),
                          label: Text(l10n.settingsAboutLogsExport),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _busy ? null : _pullDeviceLogs,
                          icon: const Icon(Icons.watch_outlined),
                          label: Text(l10n.settingsDeviceLogsPull),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _clear,
                          icon: const Icon(Icons.delete_outline),
                          label: Text(l10n.settingsAboutLogsClear),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _Section(
                icon: Icons.list_alt_outlined,
                title: l10n.settingsLogsFileList,
                child: _files.isEmpty
                    ? Text(
                        l10n.settingsAboutLogsEmpty,
                        style: TextStyle(color: colors.onSurfaceVariant),
                      )
                    : Column(
                        children: [
                          for (final file in _files)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.description_outlined),
                              title: Text(
                                file.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${_fileSizeLabel(file.size)} · ${MaterialLocalizations.of(context).formatShortDate(file.modifiedAt)}',
                              ),
                              trailing: Icon(
                                defaultTargetPlatform == TargetPlatform.android
                                    ? Icons.share_outlined
                                    : Icons.folder_open_outlined,
                              ),
                              onTap: () => _openFile(file),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceLogProgressDialog extends StatelessWidget {
  const _DeviceLogProgressDialog({
    required this.progress,
    required this.fileName,
    required this.cancelling,
    required this.onCancel,
  });

  final ValueListenable<double> progress;
  final ValueListenable<String> fileName;
  final ValueListenable<bool> cancelling;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(l10n.settingsDeviceLogsPulling),
        content: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (context, value, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(value: value > 0 ? value : null),
              const SizedBox(height: 12),
              Text(l10n.settingsDeviceLogsProgress((value * 100).round())),
              ValueListenableBuilder<String>(
                valueListenable: fileName,
                builder: (context, name, _) => name.isEmpty
                    ? const SizedBox.shrink()
                    : Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: cancelling,
            builder: (context, value, _) => TextButton.icon(
              onPressed: value ? null : onCancel,
              icon: value
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.close, size: 18),
              label: Text(l10n.cancel),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogDisclosureDialog extends StatelessWidget {
  const _LogDisclosureDialog({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: Text(l10n.settingsAboutLogsWarningTitle),
        content: Text(l10n.settingsAboutLogsWarningMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.understood),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _TeamMemberTile extends StatelessWidget {
  const _TeamMemberTile({required this.member});

  final TeamMember member;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _openUrl(member.githubUrl),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            ClipOval(
              child: Image.asset(
                member.avatarAsset,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _roleLabel(l10n, member.role),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            SvgPicture.asset(
              'assets/images/brands/github.svg',
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(
                colors.onSurfaceVariant,
                BlendMode.srcIn,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
