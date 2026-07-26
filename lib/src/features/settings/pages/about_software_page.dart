import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/app/widgets/app_icon.dart';
import 'package:oronbox/src/core/constants/app_constants.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/core/logging/file_log_sink.dart';
import 'package:oronbox/src/core/services/build_info_service.dart';
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final useTwoColumns = constraints.maxWidth >= 720;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: AppConstants.teamMembers.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: useTwoColumns ? 2 : 1,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        mainAxisExtent: 72,
                      ),
                      itemBuilder: (context, index) {
                        final member = AppConstants.teamMembers[index];
                        return _TeamMemberTile(
                          name: member.name,
                          role: _roleLabel(l10n, member.role),
                          avatarAsset: member.avatarAsset,
                          onTap: () => _openUrl(member.githubUrl),
                        );
                      },
                    );
                  },
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
              const _LogsSection(),
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

  String _roleLabel(AppLocalizations l10n, TeamRole role) {
    return switch (role) {
      TeamRole.mainDeveloperDesigner => l10n.settingsTeamRoleMain,
      TeamRole.zeppOSImplementation => l10n.settingsTeamRoleZeppOS,
    };
  }
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
              onPressed: () =>
                  _openUrl('${AppConstants.githubRepoUrl}/blob/main/LICENSE'),
              icon: const Icon(Icons.description_outlined),
              label: Text(l10n.openSourceLicenses),
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

class _LogsSection extends StatefulWidget {
  const _LogsSection();

  @override
  State<_LogsSection> createState() => _LogsSectionState();
}

class _LogsSectionState extends State<_LogsSection> {
  var _size = 0;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final size = await logDirectorySize();
    if (mounted) setState(() => _size = size);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _Section(
      icon: Icons.folder_outlined,
      title: l10n.settingsAboutLogs,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settingsAboutLogsDescription,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.settingsAboutLogsSize(_sizeLabel),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              OutlinedButton.icon(
                onPressed: _busy ? null : _clear,
                icon: const Icon(Icons.delete_outline),
                label: Text(l10n.settingsAboutLogsClear),
              ),
            ],
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
  const _TeamMemberTile({
    required this.name,
    required this.role,
    required this.avatarAsset,
    required this.onTap,
  });

  final String name;
  final String role;
  final String avatarAsset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                avatarAsset,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    role,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                Theme.of(context).colorScheme.onSurfaceVariant,
                BlendMode.srcIn,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
