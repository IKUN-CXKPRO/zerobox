import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/core/network/dio_provider.dart';
import 'package:oronbox/src/device/core/device_kind.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/features/devices/services/firmware_catalog.dart';
import 'package:oronbox/src/features/resources/services/resource_install_service.dart';
import 'package:oronbox/src/features/resources/widgets/resource_install_confirmation.dart';
import 'package:oronbox/src/host/application_host_provider.dart';

class DeviceFirmwarePage extends ConsumerStatefulWidget {
  const DeviceFirmwarePage({super.key});

  @override
  ConsumerState<DeviceFirmwarePage> createState() => _DeviceFirmwarePageState();
}

class _DeviceFirmwarePageState extends ConsumerState<DeviceFirmwarePage> {
  bool _checking = false;
  bool _checked = false;
  bool _sourceUnavailable = false;
  bool _installingUpdate = false;
  double _downloadProgress = 0;
  String? _error;
  List<FirmwareRelease> _releases = const [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_checkForUpdates);
  }

  Future<void> _checkForUpdates() async {
    final manager = ref.read(deviceManagerProvider.notifier);
    final state = ref.read(deviceManagerProvider);
    final device = state.currentDevice;
    if (device == null || _checking) return;
    setState(() {
      _checking = true;
      _sourceUnavailable = false;
      _error = null;
    });
    final systemInfo = state.systemInfo;
    try {
      final releases = await ref
          .read(firmwareCatalogProvider)
          .findUpdates(
            FirmwareCatalogQuery(
              kind: manager.currentDeviceKind ?? DeviceKind.xiaomi,
              codename: device.codename,
              model: systemInfo?.model ?? '',
              currentVersion: systemInfo?.firmwareVersion ?? '',
            ),
          );
      if (!mounted) return;
      setState(() {
        _releases = releases;
        _checked = true;
      });
    } on FirmwareCatalogUnavailable {
      if (!mounted) return;
      setState(() {
        _releases = const [];
        _checked = true;
        _sourceUnavailable = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _releases = const [];
        _checked = true;
        _error = error.toString();
      });
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _downloadLatest(FirmwareRelease release) async {
    final result = await ref
        .read(applicationHostProvider)
        .execute(
          OronBoxCommand(
            method: 'task.enqueue',
            params: {
              'command': OronBoxCommand(
                method: 'file.download',
                params: {
                  'url': release.downloadUrl.toString(),
                  'fileName': release.fileName,
                  'title': release.fileName,
                },
              ).toJson(),
            },
          ),
        );
    if (!result.ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.downloadFailed)),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.downloadTaskAdded)),
    );
  }

  Future<void> _installLatest(FirmwareRelease release) async {
    if (_installingUpdate) return;
    if (kIsWeb) {
      await _downloadLatest(release);
      return;
    }
    setState(() {
      _installingUpdate = true;
      _downloadProgress = 0;
    });
    try {
      final file = await downloadFirmwareRelease(
        ref.read(appDioProvider),
        release,
        onProgress: (progress) {
          if (mounted) setState(() => _downloadProgress = progress);
        },
      );
      if (!mounted) return;
      await confirmAndEnqueueResourceFile(
        context: context,
        ref: ref,
        file: file,
        selectedType: LocalDeviceInstallType.firmware,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.downloadFailed)),
      );
    } finally {
      if (mounted) setState(() => _installingUpdate = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(deviceManagerProvider);
    final device = state.currentDevice;
    final currentVersion = state.systemInfo?.firmwareVersion.trim() ?? '';
    final latest = _releases.firstOrNull;
    final hasUpdate =
        latest != null &&
        currentVersion.isNotEmpty &&
        _compareVersions(latest.version, currentVersion) > 0;

    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text(l10n.deviceFeaturesInstallFirmware),
      ),
      body: PageContainer(
        padding: EdgeInsets.zero,
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: StyleConstants.pagePadding,
          ),
          children: [
            Text(
              l10n.firmwareCurrentVersion,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              currentVersion.isEmpty
                  ? l10n.firmwareVersionUnknown
                  : currentVersion,
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text(_statusText(l10n, latest, hasUpdate))),
                TextButton.icon(
                  onPressed: _checking ? null : _checkForUpdates,
                  icon: _checking
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(l10n.refresh),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: latest == null
                        ? null
                        : () => _downloadLatest(latest),
                    icon: const Icon(Icons.download_outlined),
                    label: Text(l10n.firmwareDownloadLatestFull),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: device == null
                        ? null
                        : () => context.push('/devices/install/firmware'),
                    icon: const Icon(Icons.folder_open_outlined),
                    label: Text(l10n.localFirmwareInstall),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              l10n.firmwareLatestRelease,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            SectionCard(
              margin: EdgeInsets.zero,
              child: latest == null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: Text(_emptyText(l10n))),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          latest.version,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        if (hasUpdate) ...[
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _installingUpdate
                                ? null
                                : () => _installLatest(latest),
                            icon: _installingUpdate
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.system_update_alt),
                            label: Text(
                              _installingUpdate
                                  ? l10n.firmwareDownloadingProgress(
                                      (_downloadProgress * 100).round(),
                                    )
                                  : l10n.firmwareUpdateNow,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Text(
                          l10n.firmwareReleaseNotes,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          latest.releaseNotes?.trim().isNotEmpty == true
                              ? latest.releaseNotes!.trim()
                              : l10n.firmwareReleaseNotesUnavailable,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusText(
    AppLocalizations l10n,
    FirmwareRelease? latest,
    bool hasUpdate,
  ) {
    if (_checking) return l10n.firmwareCheckingUpdates;
    if (_error != null) return l10n.updateCheckFailed;
    if (_sourceUnavailable) return l10n.firmwareSourceUnavailable;
    if (!_checked || latest == null) return l10n.firmwareNoUpdatesFound;
    return hasUpdate ? l10n.firmwareUpdateAvailable : l10n.firmwareUpToDate;
  }

  String _emptyText(AppLocalizations l10n) {
    if (_checking) return l10n.firmwareCheckingUpdates;
    if (_error != null) return l10n.updateCheckFailed;
    if (_sourceUnavailable) return l10n.firmwareSourceUnavailable;
    return l10n.firmwareNoUpdatesFound;
  }

  int _compareVersions(String left, String right) {
    List<int> parts(String value) => value
        .trim()
        .replaceFirst(RegExp(r'^[vV]'), '')
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
    final a = parts(left);
    final b = parts(right);
    final length = a.length > b.length ? a.length : b.length;
    for (var index = 0; index < length; index++) {
      final result = (index < a.length ? a[index] : 0).compareTo(
        index < b.length ? b[index] : 0,
      );
      if (result != 0) return result;
    }
    return 0;
  }
}
