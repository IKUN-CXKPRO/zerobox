import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/features/resources/application/creator/creator_workspace_controller.dart';
import 'package:oronbox/src/features/resources/domain/creator_workspace.dart';
import 'package:oronbox/src/features/resources/pages/creator/creator_shared.dart';

class CreatorResourceList extends StatefulWidget {
  const CreatorResourceList({
    super.key,
    required this.state,
    required this.controller,
    required this.onCreate,
    this.onOpen,
  });

  final CreatorWorkspaceState state;
  final CreatorWorkspaceController controller;
  final VoidCallback onCreate;
  final ValueChanged<CreatorWorkspace>? onOpen;

  @override
  State<CreatorResourceList> createState() => _CreatorResourceListState();
}

class _CreatorResourceListState extends State<CreatorResourceList> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = widget.state;
    if (state.loading && state.resources.isEmpty) {
      return LoadingView(message: creatorOperationLabel(l10n, state.operation));
    }
    if (state.resources.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(l10n.creatorNoResources),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: state.loading ? null : widget.onCreate,
              icon: const Icon(Icons.add),
              label: Text(l10n.creatorNewResource),
            ),
          ],
        ),
      );
    }
    final presentStates = creatorStateOrder
        .where(
          (value) => state.resources.any(
            (workspace) => creatorWorkspaceState(workspace) == value,
          ),
        )
        .toList();
    if (!presentStates.contains(_filter)) _filter = 'all';
    final visible = _filter == 'all'
        ? state.resources
        : state.resources
              .where((workspace) => creatorWorkspaceState(workspace) == _filter)
              .toList();
    return RefreshIndicator(
      onRefresh: widget.controller.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                _filterChip(l10n.all, 'all'),
                for (final value in presentStates)
                  _filterChip(creatorStateLabel(l10n, value), value),
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (final workspace in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CreatorResourceCard(
                workspace: workspace,
                controller: widget.controller,
                onTap: () {
                  widget.controller.select(workspace);
                  widget.onOpen?.call(workspace);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: FilterChip(
      label: Text(label),
      selected: _filter == value,
      showCheckmark: false,
      onSelected: (_) => setState(() => _filter = value),
    ),
  );
}

class CreatorResourceThumbnail extends StatefulWidget {
  const CreatorResourceThumbnail({
    super.key,
    required this.workspace,
    required this.controller,
    this.size = 64,
  });

  final CreatorWorkspace workspace;
  final CreatorWorkspaceController controller;
  final double size;

  @override
  State<CreatorResourceThumbnail> createState() =>
      _CreatorResourceThumbnailState();
}

class _CreatorResourceThumbnailState extends State<CreatorResourceThumbnail> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CreatorResourceThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspace.resource.id != widget.workspace.resource.id ||
        creatorThumbnailMedia(oldWidget.workspace)?.sha256 !=
            creatorThumbnailMedia(widget.workspace)?.sha256) {
      _bytes = null;
      _load();
    }
  }

  Future<void> _load() async {
    final media = creatorThumbnailMedia(widget.workspace);
    if (media == null) return;
    try {
      final bytes = await widget.controller.blob(
        widget.workspace.resource.id,
        media.sha256,
      );
      if (mounted) setState(() => _bytes = bytes);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bytes = _bytes;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: bytes != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(bytes, fit: BoxFit.cover),
            )
          : Icon(
              widget.workspace.resource.kind == CreatorResourceKind.watchface
                  ? Icons.watch_outlined
                  : Icons.apps_outlined,
              color: colors.onSurfaceVariant,
            ),
    );
  }
}

class CreatorResourceCard extends StatelessWidget {
  const CreatorResourceCard({
    super.key,
    required this.workspace,
    required this.controller,
    required this.onTap,
  });

  final CreatorWorkspace workspace;
  final CreatorWorkspaceController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final state = creatorWorkspaceState(workspace);
    final subtitle = workspace.latestRevision?.summary ?? '';
    final note = state == 'rejected' ? creatorReviewNote(workspace) : '';
    final supportedDeviceCount = workspace.artifacts
        .expand((artifact) => artifact.devices)
        .toSet()
        .length;
    return Card(
      clipBehavior: Clip.antiAlias,
      color: colors.surfaceContainerHighest.withValues(alpha: .5),
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          creatorWorkspaceTitle(workspace),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                              ),
                        ),
                        if (subtitle.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                          ),
                        if (workspace.resource.updatedAt != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _creatorResourceTime(
                                workspace.resource.updatedAt!,
                              ),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  CreatorStateBadge(state: state),
                  const SizedBox(width: 8),
                  CreatorResourceThumbnail(
                    workspace: workspace,
                    controller: controller,
                    size: 48,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _CreatorResourceTag(
                    label: creatorKindLabel(l10n, workspace.resource.kind),
                    color:
                        workspace.resource.kind == CreatorResourceKind.quickApp
                        ? colors.error
                        : colors.primary,
                  ),
                  if (workspace.artifacts.isNotEmpty)
                    _CreatorResourceTag(
                      icon: Icons.inventory_2_outlined,
                      label: l10n.creatorArtifactCount(
                        workspace.artifacts.length,
                      ),
                      color: colors.onSurfaceVariant,
                    ),
                  if (supportedDeviceCount > 0)
                    _CreatorResourceTag(
                      icon: Icons.watch_outlined,
                      label: l10n.creatorCompatibleDeviceCount(
                        supportedDeviceCount,
                      ),
                      color: colors.onSurfaceVariant,
                    ),
                  if (workspace.revisions.isNotEmpty)
                    _CreatorResourceTag(
                      icon: Icons.download,
                      label: '${workspace.resource.downloadCount}',
                      color: colors.onSurfaceVariant,
                    ),
                ],
              ),
              if (note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${l10n.reviewNote}: $note',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colors.error),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _creatorResourceTime(DateTime value) {
  final time = value.toLocal();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${two(time.year % 100)}-${two(time.month)}-${two(time.day)} '
      '${two(time.hour)}:${two(time.minute)}';
}

class _CreatorResourceTag extends StatelessWidget {
  const _CreatorResourceTag({
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
