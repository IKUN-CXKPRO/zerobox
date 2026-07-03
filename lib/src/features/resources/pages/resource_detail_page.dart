import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/app/widgets/network_img_layer.dart';
import 'package:zerobox/src/app/widgets/page_container.dart';
import 'package:zerobox/src/app/widgets/status_chips.dart';
import 'package:zerobox/src/app/widgets/sys_app_bar.dart';
import 'package:zerobox/src/core/constants/style_constants.dart';
import 'package:zerobox/src/data/astrobox/astrobox_providers.dart';
import 'package:zerobox/src/data/astrobox/models/astrobox_models.dart';
import 'package:zerobox/src/features/devices/controllers/device_manager.dart';
import 'package:zerobox/src/features/resources/services/download_queue_notifier.dart';

class ResourceDetailPage extends ConsumerWidget {
  const ResourceDetailPage({super.key, required this.item});

  final AstroBoxIndexItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final manifestAsync = ref.watch(astroBoxManifestProvider(item));

    return Scaffold(
      appBar: SysAppBar(title: Text(item.name)),
      body: manifestAsync.when(
        data: (manifest) {
          if (manifest == null) {
            return Center(child: Text(l10n.notFound));
          }
          return _ResourceDetailContent(item: item, manifest: manifest);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('${l10n.error}: $err')),
      ),
    );
  }
}

class _ResourceDetailContent extends ConsumerWidget {
  const _ResourceDetailContent({required this.item, required this.manifest});

  final AstroBoxIndexItem item;
  final AstroBoxManifest manifest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final repo = ref.watch(astroBoxRepositoryProvider);
    final deviceState = ref.watch(deviceManagerProvider);
    final currentDevice = deviceState.currentDevice;
    final currentCodename = currentDevice?.codename;
    final isReady = deviceState.protocolState.name == 'ready';

    final iconUrl = repo.resolveImageUrl(item, manifest.item.icon);
    final previewUrls = manifest.item.preview
        .map((p) => repo.resolveImageUrl(item, p))
        .where((u) => u.isNotEmpty)
        .toList();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          color: colorScheme.primaryContainer.withValues(alpha: 0.2),
          child: PageContainer(
            padding: const EdgeInsets.symmetric(
              horizontal: StyleConstants.pagePadding,
              vertical: StyleConstants.pagePadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: NetworkImgLayer(
                        src: iconUrl,
                        width: 80,
                        height: 80,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _AuthorLinks(
                            authors: manifest.item.author,
                            fallback: item.repoOwner,
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _ResourceTypeChip(type: item.type, l10n: l10n),
                              _PaidTypeChip(paidType: item.paidType),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _DownloadButton(
                  item: item,
                  manifest: manifest,
                  currentCodename: currentCodename,
                  isReady: isReady,
                ),
                const SizedBox(height: 12),
                if (manifest.links.isNotEmpty)
                  _ShareLinks(links: manifest.links),
              ],
            ),
          ),
        ),
        PageContainer(
          padding: const EdgeInsets.symmetric(
            horizontal: StyleConstants.pagePadding,
            vertical: StyleConstants.pagePadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (previewUrls.isNotEmpty) ...[
                SectionHeader(title: l10n.preview),
                SizedBox(
                  height: 180,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: previewUrls.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      return ClipRRect(
                        borderRadius:
                            BorderRadius.circular(StyleConstants.cardRadius),
                        child: NetworkImgLayer(
                          src: previewUrls[index],
                          width: 260,
                          height: 180,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: StyleConstants.sectionSpacing),
              ],
              if (manifest.item.description.isNotEmpty) ...[
                SectionHeader(title: l10n.productAbout),
                SectionCard(
                  child: Text(
                    manifest.item.description,
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: StyleConstants.sectionSpacing),
              ],
              SectionHeader(title: l10n.productDeviceRequirements),
              _DeviceRequirementCard(
                currentDevice: currentDevice,
                currentCodename: currentCodename,
                compatible: currentCodename != null &&
                    manifest.downloads.containsKey(currentCodename),
                downloads: manifest.downloads,
              ),
              const SizedBox(height: StyleConstants.sectionSpacing),
              SectionHeader(title: l10n.downloads),
              _DownloadList(
                item: item,
                manifest: manifest,
                currentCodename: currentCodename,
                isReady: isReady,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }
}

class _AuthorLinks extends StatelessWidget {
  const _AuthorLinks({required this.authors, required this.fallback});

  final List<AstroBoxManifestAuthor> authors;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveAuthors =
        authors.where((a) => a.name.isNotEmpty).toList();
    final displayAuthors = effectiveAuthors.isEmpty
        ? [AstroBoxManifestAuthor(name: fallback)]
        : effectiveAuthors;

    return Wrap(
      spacing: 8,
      children: displayAuthors.map((author) {
        return Text(
          '@${author.name}',
          style: textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        );
      }).toList(),
    );
  }
}

class _ResourceTypeChip extends StatelessWidget {
  const _ResourceTypeChip({required this.type, required this.l10n});

  final AstroBoxResourceType type;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final label = switch (type) {
      AstroBoxResourceType.quickApp => l10n.quickApp,
      AstroBoxResourceType.watchface => l10n.watchface,
      AstroBoxResourceType.firmware => l10n.firmwareTool,
      AstroBoxResourceType.fontpack => l10n.fontPack,
      AstroBoxResourceType.iconpack => l10n.iconPack,
    };
    return StatusChip(label: label);
  }
}

class _PaidTypeChip extends StatelessWidget {
  const _PaidTypeChip({required this.paidType});

  final AstroBoxPaidType paidType;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final (label, color) = switch (paidType) {
      AstroBoxPaidType.free => (l10n.free, Colors.green),
      AstroBoxPaidType.paid => (l10n.paid, colorScheme.tertiary),
      AstroBoxPaidType.forcePaid => (l10n.forcePaid, colorScheme.error),
    };
    return StatusChip(label: label, color: color);
  }
}

class _DownloadButton extends ConsumerWidget {
  const _DownloadButton({
    required this.item,
    required this.manifest,
    required this.currentCodename,
    required this.isReady,
  });

  final AstroBoxIndexItem item;
  final AstroBoxManifest manifest;
  final String? currentCodename;
  final bool isReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final downloads = manifest.downloads.entries.toList();
    if (downloads.isEmpty) return const SizedBox.shrink();

    final showDefault = currentCodename != null &&
        manifest.downloads.containsKey(currentCodename);
    final defaultEntry = showDefault
        ? manifest.downloads.entries.firstWhere((e) => e.key == currentCodename)
        : downloads.first;

    final inQueue = ref.watch(downloadQueueProvider.select(
      (tasks) => tasks.any(
        (t) =>
            t.item.id == item.id &&
            t.status != ResourceTaskStatus.completed,
      ),
    ));

    return MenuAnchor(
      builder: (context, controller, child) {
        return SizedBox(
          height: 48,
          child: Row(
            children: [
              if (showDefault)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: inQueue || !isReady
                        ? null
                        : () => _enqueue(ref, defaultEntry.value, defaultEntry.key),
                    icon: const Icon(Icons.download_for_offline),
                    label: Text(
                      inQueue ? l10n.productInQueue : l10n.install,
                    ),
                    style: FilledButton.styleFrom(
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.horizontal(
                          left: Radius.circular(24),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: FilledButton.icon(
                    onPressed: downloads.length == 1 && !inQueue && isReady
                        ? () => _enqueue(ref, downloads.first.value, downloads.first.key)
                        : null,
                    icon: const Icon(Icons.download_for_offline),
                    label: Text(inQueue ? l10n.productInQueue : l10n.install),
                    style: FilledButton.styleFrom(
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(24)),
                      ),
                    ),
                  ),
                ),
              if (downloads.length > 1)
                FilledButton.tonal(
                  onPressed: () {
                    if (controller.isOpen) {
                      controller.close();
                    } else {
                      controller.open();
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: showDefault
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    foregroundColor: showDefault
                        ? Theme.of(context).colorScheme.onPrimary
                        : null,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.horizontal(
                        right: Radius.circular(24),
                      ),
                    ),
                  ).copyWith(
                    minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
                  ),
                  child: const Icon(Icons.arrow_drop_down),
                ),
            ],
          ),
        );
      },
      menuChildren: downloads.map((entry) {
        return MenuItemButton(
          onPressed: () => _enqueue(ref, entry.value, entry.key),
          child: Text(entry.key),
        );
      }).toList(),
    );
  }

  void _enqueue(
    WidgetRef ref,
    AstroBoxManifestDownload download,
    String codename,
  ) {
    ref.read(downloadQueueProvider.notifier).enqueue(
          item: item,
          manifest: manifest,
          download: download,
          codename: codename,
        );
  }
}

class _ShareLinks extends StatelessWidget {
  const _ShareLinks({required this.links});

  final List<AstroBoxManifestLink> links;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: links.map((link) {
        return ActionChip(
          avatar: link.icon?.isNotEmpty == true
              ? Icon(_linkIcon(link.icon!), color: colorScheme.primary)
              : null,
          label: Text(link.title),
          onPressed: () {
            // TODO: open url
          },
        );
      }).toList(),
    );
  }

  IconData _linkIcon(String icon) {
    return switch (icon.toLowerCase()) {
      'github' || 'github-logo' => Icons.code,
      'link' => Icons.link,
      _ => Icons.open_in_new,
    };
  }
}

class _DeviceRequirementCard extends StatelessWidget {
  const _DeviceRequirementCard({
    required this.currentDevice,
    required this.currentCodename,
    required this.compatible,
    required this.downloads,
  });

  final dynamic currentDevice;
  final String? currentCodename;
  final bool compatible;
  final Map<String, AstroBoxManifestDownload> downloads;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final deviceName = currentDevice?.name?.toString() ?? '';

    return SectionCard(
      color: compatible
          ? colorScheme.primaryContainer.withValues(alpha: 0.4)
          : colorScheme.errorContainer.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                compatible ? Icons.check_circle : Icons.cancel,
                color: compatible ? colorScheme.primary : colorScheme.error,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  compatible
                      ? '${l10n.compatible} $deviceName'
                      : currentDevice != null
                          ? '${l10n.incompatible} $deviceName ${l10n.incompatibleSuffix}'
                          : l10n.deviceNotConnected,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: compatible
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
          if (currentCodename != null) ...[
            const SizedBox(height: 4),
            Text(
              currentCodename!,
              style: TextStyle(
                fontSize: 12,
                color: compatible
                    ? colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                    : colorScheme.onErrorContainer.withValues(alpha: 0.7),
              ),
            ),
          ],
          if (downloads.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              l10n.productOtherVersions,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: downloads.keys.map((codename) {
                final selected = codename == currentCodename;
                return Chip(
                  label: Text(codename),
                  backgroundColor: selected
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _DownloadList extends StatelessWidget {
  const _DownloadList({
    required this.item,
    required this.manifest,
    required this.currentCodename,
    required this.isReady,
  });

  final AstroBoxIndexItem item;
  final AstroBoxManifest manifest;
  final String? currentCodename;
  final bool isReady;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: manifest.downloads.entries.map((entry) {
        return SectionCard(
          padding: EdgeInsets.zero,
          color: entry.key == currentCodename
              ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2)
              : null,
          child: ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(entry.value.fileName),
            subtitle: Text('${l10n.version}: ${entry.value.version}'),
            trailing: FilledButton.tonal(
              onPressed: isReady ? () => _enqueue(context, entry) : null,
              child: Text(l10n.install),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _enqueue(BuildContext context, MapEntry<String, AstroBoxManifestDownload> entry) {
    ProviderScope.containerOf(context)
        .read(downloadQueueProvider.notifier)
        .enqueue(
          item: item,
          manifest: manifest,
          download: entry.value,
          codename: entry.key,
        );
  }
}
