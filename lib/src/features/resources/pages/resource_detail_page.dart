import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/widgets/horizontal_scroller.dart';
import 'package:oronbox/src/app/widgets/network_img_layer.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/core/providers/app_settings_providers.dart';
import 'package:oronbox/src/data/community/community_source.dart';
import 'package:oronbox/src/device/core/xiaomi_wearable_catalog.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/features/accounts/services/bandbbs_auth_service.dart';
import 'package:oronbox/src/features/accounts/application/host_accounts.dart';
import 'package:oronbox/src/features/accounts/services/oronbox_coin_service.dart';
import 'package:oronbox/src/features/resources/application/comments/oronbox_comments.dart';
import 'package:oronbox/src/features/resources/application/oronbox_resource_attributes.dart';
import 'package:oronbox/src/features/resources/application/resource_catalog_providers.dart';
import 'package:oronbox/src/features/resources/domain/community_resource.dart';
import 'package:oronbox/src/features/resources/services/download_queue_notifier.dart';
import 'package:oronbox/src/features/resources/services/install_queue_notifier.dart';
import 'package:oronbox/src/features/resources/widgets/community_html_content.dart';
import 'package:oronbox/src/features/resources/widgets/resource_external_link.dart';
import 'package:oronbox/src/features/resources/widgets/resource_media_hero.dart';
import 'package:oronbox/src/features/settings/pages/feedback_page.dart';

class ResourceDetailPage extends ConsumerWidget {
  const ResourceDetailPage({
    super.key,
    required this.resource,
    this.targetCommentId = '',
  });
  final CommunityResource resource;
  final String targetCommentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final detail = ref.watch(communityResourceDetailProvider(resource.ref));
    final visibleResource = detail.value ?? resource;
    final title = visibleResource.name.trim();
    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text(title.isEmpty ? l10n.resourceLibrary : title),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _ResourceHeader(
            resource: visibleResource,
            mediaResource: resource,
            animateCover: resource.coverUrl != null,
            animateIcon: resource.iconUrl != null,
          ),
          detail.when(
            loading: () => const PageContainer(
              padding: EdgeInsets.symmetric(
                horizontal: StyleConstants.pagePadding,
                vertical: 20,
              ),
              child: _DelayedLoadingIndicator(),
            ),
            error: (error, _) => PageContainer(
              padding: const EdgeInsets.all(StyleConstants.pagePadding),
              child: Text(localizedErrorMessage(l10n, error)),
            ),
            data: (value) =>
                _DetailContent(detail: value, targetCommentId: targetCommentId),
          ),
        ],
      ),
    );
  }
}

class _DelayedLoadingIndicator extends StatefulWidget {
  const _DelayedLoadingIndicator();

  @override
  State<_DelayedLoadingIndicator> createState() =>
      _DelayedLoadingIndicatorState();
}

class _DelayedLoadingIndicatorState extends State<_DelayedLoadingIndicator> {
  Timer? _timer;
  var _visible = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 160),
    child: _visible
        ? const LinearProgressIndicator(key: ValueKey('detail-progress'))
        : const SizedBox.shrink(key: ValueKey('detail-progress-delay')),
  );
}

class _ResourceHeader extends ConsumerWidget {
  const _ResourceHeader({
    required this.resource,
    required this.mediaResource,
    required this.animateCover,
    required this.animateIcon,
  });

  final CommunityResource resource;
  final CommunityResource mediaResource;
  final bool animateCover;
  final bool animateIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final attributeLabels = {
      for (final attribute
          in ref.watch(oronBoxResourceAttributesProvider).value ??
              const <OronBoxResourceAttribute>[])
        attribute.id: attribute.labelFor(Localizations.localeOf(context)),
    };
    final icon = NetworkImgLayer(
      src: mediaResource.iconUrl?.toString() ?? '',
      width: 76,
      height: 76,
    );
    return _Hero(
      image: mediaResource.coverUrl ?? mediaResource.iconUrl,
      resourceRef: resource.ref,
      animateCover: animateCover,
      child: PageContainer(
        padding: const EdgeInsets.fromLTRB(
          StyleConstants.pagePadding,
          20,
          StyleConstants.pagePadding,
          24,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (animateIcon)
              ResourceMediaHero(
                tag: resourceMediaHeroTag(resource.ref, 'icon'),
                url: mediaResource.iconUrl?.toString() ?? '',
                width: 76,
                height: 76,
                style: const ResourceMediaHeroStyle(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              )
            else
              icon,
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (resource.name.trim().isNotEmpty)
                    Text(
                      resource.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  const SizedBox(height: 4),
                  _Authors(resource: resource),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _Chip(
                        label: _typeLabel(
                          AppLocalizations.of(context)!,
                          resource.type,
                          source: resource.ref.source,
                        ),
                        color: theme.colorScheme.primary,
                      ),
                      _Chip(
                        label: _paidLabel(
                          AppLocalizations.of(context)!,
                          resource.paidType,
                        ),
                        color: resource.paidType == CommunityPaidType.free
                            ? Colors.green
                            : theme.colorScheme.tertiary,
                      ),
                      if (resource.ref.source == CommunitySourceId.bandbbs ||
                          resource.ref.source == CommunitySourceId.oronBox)
                        ...resource.tags
                            .take(2)
                            .map(
                              (tag) => _Chip(
                                label:
                                    resource.ref.source ==
                                        CommunitySourceId.oronBox
                                    ? attributeLabels[tag] ?? tag
                                    : tag,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                      if (resource.downloadCount != null)
                        _Chip(
                          label: AppLocalizations.of(
                            context,
                          )!.downloadTimes(resource.downloadCount!),
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      if (resource.curationGrade == 'featured')
                        _Chip(
                          label: AppLocalizations.of(context)!.resourceFeatured,
                          color: theme.colorScheme.primary,
                        ),
                      if (resource.coinCount > 0)
                        _Chip(
                          label: AppLocalizations.of(
                            context,
                          )!.resourceCoinCount(resource.coinCount),
                          color: theme.colorScheme.tertiary,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailContent extends ConsumerWidget {
  const _DetailContent({required this.detail, required this.targetCommentId});
  final CommunityResourceDetail detail;
  final String targetCommentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final deviceState = ref.watch(deviceManagerProvider);
    final current = deviceState.currentDevice;
    final currentCodename = normalizeXiaomiWearableCodename(current?.codename);
    final isBandBbs = detail.ref.source == CommunitySourceId.bandbbs;
    final previews = isBandBbs
        ? detail.previewImages
              .where(
                (image) => !detail.content.value.contains(image.url.toString()),
              )
              .toList()
        : detail.previewImages;
    return PageContainer(
      padding: const EdgeInsets.all(StyleConstants.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (detail.summary.isNotEmpty &&
              detail.summary != detail.content.value) ...[
            Text(
              detail.summary,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (detail.collectionName?.isNotEmpty == true) ...[
            InkWell(
              onTap: detail.collectionId?.isNotEmpty == true
                  ? () => context.push(
                      '/resources/collection/${detail.collectionId}',
                    )
                  : null,
              child: Text(
                l10n.resourceFromCollection(detail.collectionName!),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _Actions(
                  detail: detail,
                  currentCodename: currentCodename,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 108,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (detail.ref.source == CommunitySourceId.oronBox) ...[
                      _CoinButton(resource: detail),
                      const SizedBox(height: 6),
                    ],
                    FilledButton.tonalIcon(
                      onPressed: () => showFeedbackComposer(
                        context,
                        target: FeedbackTarget(
                          type: FeedbackTargetType.resource,
                          source: detail.ref.source.name,
                          id: detail.ref.id,
                          name: detail.name,
                          url: detail.links.firstOrNull?.url.toString() ?? '',
                        ),
                      ),
                      icon: const Icon(Icons.flag_outlined),
                      label: Text(l10n.report),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(36),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: theme
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: .62),
                        foregroundColor: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (detail.links.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final link in detail.links)
                  TextButton.icon(
                    onPressed: () =>
                        openResourceExternalLink(context, link.url),
                    icon: const Icon(Icons.link_outlined),
                    label: Text(link.title),
                  ),
              ],
            ),
          ],
          if (previews.isNotEmpty && !isBandBbs) ...[
            const SizedBox(height: 24),
            _PreviewGallery(previews: previews),
          ],
          if (detail.content.value.trim().isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.description,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            switch (detail.content.format) {
              ResourceContentFormat.html => CommunityHtmlContent(
                html: detail.content.value,
                baseUri: detail.content.baseUri,
                onOpenLink: (uri) => openResourceExternalLink(context, uri),
              ),
              ResourceContentFormat.plainText => SelectableText(
                detail.content.value,
                style: theme.textTheme.bodyLarge,
              ),
            },
          ],
          if (previews.isNotEmpty && isBandBbs) ...[
            const SizedBox(height: 24),
            _PreviewGallery(previews: previews),
          ],
          if (currentCodename.isNotEmpty) ...[
            const SizedBox(height: 24),
            _Compatibility(
              detail: detail,
              codename: currentCodename,
              deviceName: xiaomiDisplayNameForIdentity(
                name: current?.name.toString() ?? currentCodename,
                codename: currentCodename,
              ),
            ),
          ],
          if (detail.ref.source == CommunitySourceId.oronBox &&
              ref.watch(appSettingsProvider).clean.commentsEnabled) ...[
            const SizedBox(height: 28),
            _CommentsSection(
              resourceId: detail.ref.id,
              targetCommentId: targetCommentId,
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _CoinButton extends ConsumerStatefulWidget {
  const _CoinButton({required this.resource});

  final CommunityResource resource;

  @override
  ConsumerState<_CoinButton> createState() => _CoinButtonState();
}

class _CoinButtonState extends ConsumerState<_CoinButton> {
  var _sending = false;

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context)!;
    final count = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.resourceCoinDialogTitle),
        content: Text(l10n.resourceCoinDialogMessage),
        actions: [
          TextButton(onPressed: () => context.pop(), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => context.pop(1),
            child: Text(l10n.resourceCoinOne),
          ),
          FilledButton(
            onPressed: () => context.pop(2),
            child: Text(l10n.resourceCoinTwo),
          ),
        ],
      ),
    );
    if (count == null || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(oronBoxCoinServiceProvider)
          .coin(widget.resource.ref.id, count);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.resourceCoinSuccess)));
      ref.invalidate(communityResourceDetailProvider(widget.resource.ref));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizedErrorMessage(l10n, error))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: _sending ? null : _send,
    icon: _sending
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.toll_outlined),
    label: Text(AppLocalizations.of(context)!.resourceCoin),
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(36),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      visualDensity: VisualDensity.compact,
    ),
  );
}

class _CommentsSection extends ConsumerStatefulWidget {
  const _CommentsSection({
    required this.resourceId,
    required this.targetCommentId,
  });
  final String resourceId;
  final String targetCommentId;

  @override
  ConsumerState<_CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends ConsumerState<_CommentsSection> {
  final _controller = TextEditingController();
  final _deletingCommentIds = <String>{};
  List<OronBoxComment> _comments = const [];
  bool _loading = true;
  bool _sending = false;
  bool _hasMore = true;
  String? _replyTo;
  Object? _error;
  final _targetCommentKey = GlobalKey();
  bool _targetRevealed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(oronBoxCommentsApiProvider)
          .list(
            widget.resourceId,
            before: more && _comments.isNotEmpty
                ? _comments.last.createdAt
                : null,
          );
      if (!mounted) return;
      setState(() {
        _comments = more ? [..._comments, ...page] : page;
        _hasMore = page.length == 20;
        _loading = false;
      });
      _revealTargetComment();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _revealTargetComment() {
    if (_targetRevealed || widget.targetCommentId.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = _targetCommentKey.currentContext;
      if (!mounted) return;
      if (targetContext == null) {
        if (_hasMore && !_loading) unawaited(_load(more: true));
        return;
      }
      _targetRevealed = true;
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: .25,
      );
    });
  }

  Key? _commentKey(OronBoxComment comment) =>
      comment.id == widget.targetCommentId ? _targetCommentKey : null;

  Future<bool> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return false;
    setState(() => _sending = true);
    try {
      final comment = await ref
          .read(oronBoxCommentsApiProvider)
          .create(widget.resourceId, body, parentId: _replyTo ?? '');
      if (!mounted) return false;
      setState(() {
        if (_replyTo == null) {
          _comments = [comment, ..._comments];
        } else {
          _comments = _comments
              .map(
                (item) => item.id == _replyTo
                    ? item.copyWith(replies: [...item.replies, comment])
                    : item,
              )
              .toList();
        }
        _replyTo = null;
        _controller.clear();
      });
      return true;
    } on CommentApiException catch (error) {
      if (!mounted) return false;
      final l10n = AppLocalizations.of(context)!;
      final message = switch (error.code) {
        'comment_blocked' => l10n.commentBlocked,
        'moderation_unavailable' => l10n.commentModerationUnavailable,
        'comment_rate_limited' => l10n.commentRateLimited,
        _ => error.message,
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return false;
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _compose({String? parentId}) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _replyTo = parentId);
    var dialogBusy = false;
    final sent = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Text(
              parentId == null ? l10n.commentHint : l10n.commentReplying,
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: TextField(
                controller: _controller,
                enabled: !dialogBusy,
                autofocus: true,
                maxLength: 2000,
                minLines: 3,
                maxLines: 10,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: l10n.commentHint,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: dialogBusy
                    ? null
                    : () => Navigator.pop(dialogContext, false),
                child: Text(l10n.cancel),
              ),
              FilledButton.icon(
                onPressed: dialogBusy
                    ? null
                    : () async {
                        setDialogState(() => dialogBusy = true);
                        final success = await _send();
                        if (!dialogContext.mounted) return;
                        if (success) {
                          Navigator.pop(dialogContext, true);
                        } else {
                          setDialogState(() => dialogBusy = false);
                        }
                      },
                icon: dialogBusy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(parentId == null ? l10n.commentHint : l10n.reply),
              ),
            ],
          );
        },
      ),
    );
    if (sent != true && mounted) setState(() => _replyTo = null);
  }

  Future<void> _delete(OronBoxComment comment) async {
    if (_deletingCommentIds.contains(comment.id)) return;
    setState(() => _deletingCommentIds.add(comment.id));
    try {
      await ref.read(oronBoxCommentsApiProvider).delete(comment.id);
      await _load();
    } finally {
      if (mounted) setState(() => _deletingCommentIds.remove(comment.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auth = ref.watch(bandBbsAuthProvider);
    final isAdmin = ref.watch(currentUserRoleProvider).value == 'admin';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.comments,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: auth.isSignedIn
                  ? () => _compose()
                  : () => context.push('/settings/bandbbs'),
              icon: Icon(auth.isSignedIn ? Icons.edit_outlined : Icons.login),
              label: Text(
                auth.isSignedIn ? l10n.commentHint : l10n.commentLoginRequired,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_loading && _comments.isEmpty)
          const Center(child: CircularProgressIndicator())
        else if (_error != null && _comments.isEmpty)
          TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.retry),
          )
        else if (_comments.isEmpty)
          Text(l10n.commentEmpty)
        else
          for (final comment in _comments) ...[
            _CommentTile(
              key: _commentKey(comment),
              comment: comment,
              ownUserId: int.tryParse(auth.userId ?? ''),
              canModerate: isAdmin,
              deleting: _deletingCommentIds.contains(comment.id),
              onReply: () => _compose(parentId: comment.id),
              onDelete: () => _delete(comment),
              replies: [
                for (final reply in comment.replies)
                  _CommentTile(
                    key: _commentKey(reply),
                    comment: reply,
                    isReply: true,
                    ownUserId: int.tryParse(auth.userId ?? ''),
                    canModerate: isAdmin,
                    deleting: _deletingCommentIds.contains(reply.id),
                    onDelete: () => _delete(reply),
                  ),
              ],
            ),
          ],
        if (_hasMore && _comments.isNotEmpty)
          TextButton(
            onPressed: _loading ? null : () => _load(more: true),
            child: Text(l10n.loadMore),
          ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    super.key,
    required this.comment,
    required this.ownUserId,
    required this.canModerate,
    required this.deleting,
    this.isReply = false,
    this.onReply,
    required this.onDelete,
    this.replies = const [],
  });
  final OronBoxComment comment;
  final int? ownUserId;
  final bool canModerate;
  final bool deleting;
  final bool isReply;
  final VoidCallback? onReply;
  final VoidCallback onDelete;
  final List<Widget> replies;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final own = ownUserId == comment.bandBbsUserId;
    final date = comment.createdAt.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    final theme = Theme.of(context);
    final content = Padding(
      padding: EdgeInsets.all(isReply ? 10 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: isReply ? 14 : 18,
            backgroundImage: comment.avatarUrl.isEmpty
                ? null
                : NetworkImage(comment.avatarUrl),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.username,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${two(date.year % 100)}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                Text(
                  '米坛 ID ${comment.bandBbsUserId}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(comment.body, style: theme.textTheme.bodyMedium),
                if (own && comment.moderationAction == 'review')
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      l10n.commentPending,
                      style: TextStyle(color: theme.colorScheme.tertiary),
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onReply != null)
                      IconButton(
                        tooltip: l10n.reply,
                        visualDensity: VisualDensity.compact,
                        onPressed: onReply,
                        icon: const Icon(Icons.reply_outlined, size: 19),
                      ),
                    if (own || canModerate)
                      IconButton(
                        tooltip: l10n.delete,
                        visualDensity: VisualDensity.compact,
                        onPressed: deleting ? null : onDelete,
                        icon: deleting
                            ? const SizedBox.square(
                                dimension: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.delete_outline, size: 19),
                      )
                    else
                      IconButton(
                        tooltip: l10n.report,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => showFeedbackComposer(
                          context,
                          target: FeedbackTarget(
                            type: FeedbackTargetType.comment,
                            source: 'comment',
                            id: comment.id,
                            name: comment.username,
                          ),
                        ),
                        icon: const Icon(Icons.flag_outlined, size: 19),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (isReply) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: .48,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: content,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            content,
            if (replies.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                child: Column(children: replies),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Authors extends StatelessWidget {
  const _Authors({required this.resource});

  final CommunityResource resource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (resource.authors.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: resource.authors
          .map(
            (author) => InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openAuthor(context, resource, author),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '@${author.name}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    if (resource.ref.source == CommunitySourceId.huamiAppStore)
                      Padding(
                        padding: const EdgeInsets.only(left: 3),
                        child: Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  void _openAuthor(
    BuildContext context,
    CommunityResource resource,
    CommunityResourceAuthor author,
  ) {
    if (resource.ref.source == CommunitySourceId.huamiAppStore) {
      final name = author.name.trim();
      if (name.isEmpty) return;
      context.push(
        '/resources/huami-publisher?name=${Uri.encodeQueryComponent(name)}',
      );
      return;
    }
    final url = author.url;
    if (url != null) {
      openResourceExternalLink(context, url);
    }
  }
}

class _PreviewGallery extends StatelessWidget {
  const _PreviewGallery({required this.previews});
  final List<CommunityResourceImage> previews;

  static const _height = 240.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.preview,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        HorizontalScroller(
          height: _height,
          spacing: 12,
          children: [
            for (final image in previews)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _sized(image)
                    ? NetworkImgLayer(
                        src: image.url.toString(),
                        width: _height * _aspectOf(image),
                        height: _height,
                        fit: BoxFit.contain,
                      )
                    : NetworkImgAutoWidth(
                        src: image.url.toString(),
                        height: _height,
                      ),
              ),
          ],
        ),
      ],
    );
  }

  bool _sized(CommunityResourceImage image) =>
      image.width != null && image.height != null && image.height! > 0;

  double _aspectOf(CommunityResourceImage image) {
    final width = image.width;
    final height = image.height;
    if (width == null || height == null || height <= 0) return 3 / 2;
    return width / height;
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.detail, required this.currentCodename});
  final CommunityResourceDetail detail;
  final String currentCodename;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final files = detail.files;
    final choices = buildResourceInstallChoices(detail);
    if (files.isEmpty) return const SizedBox.shrink();
    final preferred = preferredResourceInstallChoice(
      detail,
      choices,
      currentCodename,
    );
    final inDownloadQueue = ref.watch(
      downloadQueueProvider.select(
        (tasks) => tasks.any(
          (task) =>
              task.resource.ref == detail.ref &&
              task.status != ResourceTaskStatus.completed,
        ),
      ),
    );
    final inInstallQueue = ref.watch(
      installQueueProvider.select(
        (state) => state.tasks.any(
          (task) =>
              task.resource?.ref == detail.ref &&
              task.status != ResourceTaskStatus.completed,
        ),
      ),
    );
    final inQueue = inDownloadQueue || inInstallQueue;
    final canInstall = detail.canDownload && !inQueue;
    void enqueue(ResourceInstallChoice choice) {
      final target = choice.codename.isNotEmpty
          ? choice.codename
          : currentCodename;
      final accepted = ref
          .read(downloadQueueProvider.notifier)
          .enqueue(resource: detail, file: choice.file, codename: target);
      if (!accepted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.downloadStarted)));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final expand = constraints.maxWidth < 520;
        final color = Theme.of(context).colorScheme;
        final label = inQueue ? l10n.productInQueue : l10n.install;
        final foreground = canInstall
            ? color.onPrimaryContainer
            : color.onSurface.withValues(alpha: .38);
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (files.isNotEmpty)
              SizedBox(
                width: expand ? double.infinity : 190,
                child: MenuAnchor(
                  style: const MenuStyle(
                    alignment: AlignmentDirectional.topEnd,
                  ),
                  alignmentOffset: const Offset(0, 4),
                  menuChildren: choices
                      .map(
                        (choice) => MenuItemButton(
                          onPressed: canInstall ? () => enqueue(choice) : null,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 280),
                            child: Text(
                              choice.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  builder: (_, controller, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Material(
                      color: canInstall
                          ? color.primaryContainer
                          : color.onSurface.withValues(alpha: .08),
                      child: SizedBox(
                        height: 48,
                        child: preferred == null
                            ? InkWell(
                                onTap: canInstall
                                    ? () => _toggleMenu(controller)
                                    : null,
                                child: _InstallButtonContent(
                                  label: label,
                                  color: foreground,
                                  trailing: const Icon(Icons.arrow_drop_down),
                                ),
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: canInstall
                                          ? () => enqueue(preferred)
                                          : null,
                                      child: _InstallButtonContent(
                                        label: label,
                                        color: foreground,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: 28,
                                    child: VerticalDivider(
                                      width: 1,
                                      color: foreground.withValues(alpha: .20),
                                    ),
                                  ),
                                  _InstallMenuHandle(
                                    enabled: canInstall && choices.length > 1,
                                    color: foreground,
                                    onTap: () => _toggleMenu(controller),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _toggleMenu(MenuController controller) {
    if (controller.isOpen) {
      controller.close();
    } else {
      controller.open();
    }
  }
}

class ResourceInstallChoice {
  const ResourceInstallChoice({
    required this.file,
    required this.codename,
    required this.label,
  });

  final CommunityResourceFile file;
  final String codename;
  final String label;
}

List<ResourceInstallChoice> buildResourceInstallChoices(
  CommunityResourceDetail detail,
) {
  final choices = <ResourceInstallChoice>[];
  for (final file in detail.files) {
    if (detail.ref.source == CommunitySourceId.bandbbs ||
        detail.ref.source == CommunitySourceId.huamiAppStore) {
      choices.add(
        ResourceInstallChoice(file: file, codename: '', label: file.fileName),
      );
      continue;
    }
    final devices = file.supportedDevices.isNotEmpty
        ? file.supportedDevices
        : detail.supportedDevices;
    if (devices.isEmpty) {
      choices.add(
        ResourceInstallChoice(file: file, codename: '', label: file.label),
      );
      continue;
    }
    for (final device in devices) {
      final codename = normalizeXiaomiWearableCodename(device);
      if (codename.isEmpty) continue;
      choices.add(
        ResourceInstallChoice(
          file: file,
          codename: codename,
          label: xiaomiDisplayNameForIdentity(
            name: codename,
            codename: codename,
          ),
        ),
      );
    }
  }
  return choices;
}

ResourceInstallChoice? preferredResourceInstallChoice(
  CommunityResourceDetail detail,
  List<ResourceInstallChoice> choices,
  String currentCodename,
) {
  if (detail.ref.source == CommunitySourceId.huamiAppStore) {
    return choices.firstOrNull;
  }
  return choices
      .where((choice) => _matchesDevice(choice.file, currentCodename))
      .where(
        (choice) =>
            choice.codename.isEmpty ||
            normalizeXiaomiWearableCodename(choice.codename) == currentCodename,
      )
      .firstOrNull;
}

bool _matchesDevice(CommunityResourceFile file, String codename) {
  if (file.supportedDevices.isEmpty) return true;
  return file.supportedDevices
      .map(normalizeXiaomiWearableCodename)
      .contains(codename);
}

class _InstallButtonContent extends StatelessWidget {
  const _InstallButtonContent({
    required this.label,
    required this.color,
    this.trailing,
  });

  final String label;
  final Color color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.download_for_offline, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            IconTheme(
              data: IconThemeData(color: color),
              child: trailing!,
            ),
          ],
        ],
      ),
    ),
  );
}

class _InstallMenuHandle extends StatelessWidget {
  const _InstallMenuHandle({
    required this.enabled,
    required this.color,
    required this.onTap,
  });

  final bool enabled;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: double.infinity,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Icon(Icons.arrow_drop_down, color: color),
      ),
    );
  }
}

class _Compatibility extends StatelessWidget {
  const _Compatibility({
    required this.detail,
    required this.codename,
    required this.deviceName,
  });
  final CommunityResourceDetail detail;
  final String codename;
  final String deviceName;
  @override
  Widget build(BuildContext context) {
    final compatible = detail.files.any(
      (file) => _matchesDevice(file, codename),
    );
    final versions = detail.files
        .expand((file) => file.supportedDevices)
        .map(normalizeXiaomiWearableCodename)
        .where((value) => value.isNotEmpty)
        .toSet();
    final color = Theme.of(context).colorScheme;
    final statusColor = compatible ? Colors.green : color.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.productDeviceRequirements,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              compatible ? Icons.check_circle : Icons.cancel,
              size: 20,
              color: statusColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                compatible
                    ? '${AppLocalizations.of(context)!.compatible} $deviceName'
                    : '${AppLocalizations.of(context)!.incompatible} $deviceName ${AppLocalizations.of(context)!.incompatibleSuffix}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        if (versions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.productOtherVersions,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: color.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: versions.map((version) {
              final selected = version == codename;
              return Chip(
                label: Text(
                  xiaomiDisplayNameForIdentity(
                    name: version,
                    codename: version,
                  ),
                ),
                backgroundColor: selected
                    ? color.primaryContainer
                    : color.surfaceContainerHighest,
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.child,
    required this.resourceRef,
    required this.animateCover,
    this.image,
  });
  final Widget child;
  final ResourceRef resourceRef;
  final bool animateCover;
  final Uri? image;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      if (image != null)
        Positioned.fill(
          child: animateCover
              ? ResourceMediaHero(
                  tag: resourceMediaHeroTag(resourceRef, 'cover'),
                  url: image.toString(),
                  width: double.infinity,
                  height: double.infinity,
                  style: const ResourceMediaHeroStyle(
                    opacity: .16,
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                )
              : Opacity(
                  opacity: .16,
                  child: NetworkImgLayer(
                    src: image.toString(),
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
        ),
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: .22),
          ),
        ),
      ),
      child,
    ],
  );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: color.withValues(alpha: .12),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w600),
    ),
  );
}

String _typeLabel(
  AppLocalizations l10n,
  CommunityResourceType type, {
  CommunitySourceId? source,
}) => switch (type) {
  CommunityResourceType.quickApp =>
    source == CommunitySourceId.huamiAppStore
        ? l10n.miniprogram
        : l10n.quickApp,
  CommunityResourceType.miniprogram => l10n.miniprogram,
  CommunityResourceType.watchface => l10n.watchface,
  CommunityResourceType.firmware => l10n.firmwareTool,
  CommunityResourceType.fontpack => l10n.fontPack,
  CommunityResourceType.iconpack => l10n.iconPack,
};
String _paidLabel(AppLocalizations l10n, CommunityPaidType type) =>
    switch (type) {
      CommunityPaidType.free => l10n.free,
      CommunityPaidType.paid => l10n.paid,
      CommunityPaidType.forcePaid => l10n.forcePaid,
    };
