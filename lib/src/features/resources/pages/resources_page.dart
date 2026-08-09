import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/widgets/network_img_layer.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/core/providers/app_settings_providers.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/data/community/community_source.dart';
import 'package:oronbox/src/data/bandbbs/bandbbs_resource_provider.dart';
import 'package:oronbox/src/data/oronbox/oronbox_home_api.dart';
import 'package:oronbox/src/device/core/device_kind.dart';
import 'package:oronbox/src/device/core/device_profile.dart';
import 'package:oronbox/src/device/core/xiaomi_wearable_catalog.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/features/accounts/application/host_accounts.dart';
import 'package:oronbox/src/features/accounts/services/bandbbs_auth_service.dart';
import 'package:oronbox/src/features/messages/application/message_center.dart';
import 'package:oronbox/src/features/resources/application/home_providers.dart';
import 'package:oronbox/src/features/resources/application/resource_catalog_providers.dart';
import 'package:oronbox/src/features/resources/application/oronbox_resource_attributes.dart';
import 'package:oronbox/src/features/resources/controllers/resource_filter_controller.dart';
import 'package:oronbox/src/features/resources/domain/community_resource.dart';
import 'package:oronbox/src/features/resources/domain/resource_catalog.dart';
import 'package:oronbox/src/features/resources/widgets/bandbbs_category_sidebar.dart';
import 'package:oronbox/src/features/resources/widgets/bandbbs_resource_card.dart';
import 'package:oronbox/src/features/resources/widgets/blog_labels.dart';
import 'package:oronbox/src/features/resources/widgets/resource_external_link.dart';
import 'package:oronbox/src/features/resources/widgets/resource_media_hero.dart';

final _homeFeedProvider = FutureProvider.autoDispose
    .family<List<CommunityResource>, CommunitySortRule>((ref, sort) async {
      ref.watch(resourceRefreshProvider);
      final page = await ref
          .watch(communityCatalogProviderForSource(CommunitySourceId.oronBox))
          .getPage(CommunityResourceQuery(pageSize: 12, sort: sort));
      return page.items;
    });

final _featuredFeedProvider =
    FutureProvider.autoDispose<List<CommunityResource>>((ref) async {
      ref.watch(resourceRefreshProvider);
      final page = await ref
          .watch(communityCatalogProviderForSource(CommunitySourceId.oronBox))
          .getPage(
            const CommunityResourceQuery(
              pageSize: 12,
              sort: CommunitySortRule.recommendation,
              featured: true,
            ),
          );
      return page.items;
    });

class ResourcesPage extends ConsumerWidget {
  const ResourcesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final mode = ref.watch(resourceModeControllerProvider);
    final clean = ref.watch(appSettingsProvider).clean;
    final showHome = clean.homeFeedEnabled;
    final showExplore = clean.resourceLibraryEnabled && clean.hasResourceSource;
    final showCreator = clean.creatorEnabled;
    if (!showHome && !showExplore) {
      return Scaffold(
        appBar: SysAppBar(title: Text(l10n.exploreTab)),
        body: Center(child: Text(l10n.cleanModeDescription)),
      );
    }
    final displayMode = switch (mode) {
      ResourceMode.home when showHome => ResourceMode.home,
      ResourceMode.library when showExplore => ResourceMode.library,
      _ when showHome => ResourceMode.home,
      _ => ResourceMode.library,
    };
    return Scaffold(
      appBar: SysAppBar(
        title: Text(l10n.exploreTab),
        actions: [
          if (displayMode == ResourceMode.library) const _CommunitySourceMenu(),
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final catalog = ref.read(communityCatalogProvider);
              if (catalog is BandBbsCatalog) {
                catalog.clearCategoryCache();
                ref.invalidate(bandbbsCategoryTreeProvider);
              }
              ref.invalidate(communityCatalogDevicesProvider);
              ref.read(resourceRefreshProvider.notifier).refresh();
            },
          ),
          if (clean.inboxEnabled)
            _InboxAction(
              unread: ref.watch(messageCenterProvider).value?.unread ?? 0,
            ),
        ],
      ),
      body: Column(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: StyleConstants.pageMaxWidth,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: StyleConstants.pagePadding,
                  vertical: StyleConstants.pagePadding,
                ),
                child: SegmentedButton<ResourceMode>(
                  showSelectedIcon: false,
                  segments: [
                    if (showHome)
                      ButtonSegment(
                        value: ResourceMode.home,
                        label: Text(l10n.homeTab),
                        icon: const Icon(Icons.home_outlined),
                      ),
                    if (showExplore)
                      ButtonSegment(
                        value: ResourceMode.library,
                        label: Text(l10n.resourceLibrary),
                        icon: const Icon(Icons.library_books_outlined),
                      ),
                    if (showCreator)
                      ButtonSegment(
                        value: ResourceMode.creator,
                        label: Text(l10n.creatorCenter),
                        icon: const Icon(Icons.create_outlined),
                      ),
                  ],
                  selected: {displayMode},
                  onSelectionChanged: (value) {
                    final selected = value.first;
                    if (selected == ResourceMode.creator) {
                      context.push('/resources/creator');
                      return;
                    }
                    ref
                        .read(resourceModeControllerProvider.notifier)
                        .setMode(selected);
                  },
                ),
              ),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: switch (displayMode) {
                ResourceMode.home => const _ResourceHomeView(
                  key: ValueKey('home'),
                ),
                _ => const _ResourceLibraryView(key: ValueKey('library')),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InboxAction extends StatelessWidget {
  const _InboxAction({required this.unread});

  final int unread;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: AppLocalizations.of(context)!.inbox,
    onPressed: () => context.push('/inbox'),
    icon: unread > 0
        ? Badge(
            label: Text('$unread'),
            child: const Icon(Icons.notifications_outlined),
          )
        : const Icon(Icons.notifications_outlined),
  );
}

class _ResourceHomeView extends ConsumerWidget {
  const _ResourceHomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final clean = ref.watch(appSettingsProvider.select((state) => state.clean));
    final home = ref.watch(homeFeedProvider);
    final sections = [
      if (clean.homeFeaturedEnabled)
        (
          l10n.resourceHomeFeatured,
          CommunitySortRule.recommendation,
          ref.watch(_featuredFeedProvider),
        ),
      if (clean.homeRecommendedEnabled)
        (
          l10n.resourceHomeRecommended,
          CommunitySortRule.recommendation,
          ref.watch(_homeFeedProvider(CommunitySortRule.recommendation)),
        ),
      if (clean.homeLatestEnabled)
        (
          l10n.newlyPublished,
          CommunitySortRule.time,
          ref.watch(_homeFeedProvider(CommunitySortRule.time)),
        ),
    ];
    final curated = home.value;
    final curatedEmpty =
        curated == null ||
        ((!clean.homeBannerEnabled || curated.banners.isEmpty) &&
            curated.blogs.isEmpty &&
            (!clean.homeEditorSectionsEnabled ||
                curated.sections.every((section) => section.cards.isEmpty)));
    final allFailed =
        home.hasError && sections.every((section) => section.$3.hasError);
    final allEmpty =
        !allFailed &&
        curatedEmpty &&
        sections.every(
          (section) => section.$3.hasValue && section.$3.value!.isEmpty,
        );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(homeFeedProvider);
        ref.invalidate(_featuredFeedProvider);
        ref.invalidate(_homeFeedProvider);
      },
      child: ScrollConfiguration(
        behavior: const _NoStretchScrollBehavior(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (allFailed)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _HomeEmpty(
                  error: sections
                      .map((section) => section.$3.error)
                      .firstOrNull,
                ),
              )
            else if (allEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _HomeEmpty(),
              )
            else
              SliverList.list(
                children: [
                  if (clean.homeBannerEnabled)
                    if (curated == null && !home.hasError)
                      const _HomeBannerSkeleton()
                    else if (curated != null && curated.banners.isNotEmpty)
                      _HomeBannerCarousel(banners: curated.banners),
                  if (curated == null && !home.hasError)
                    const _HomeBlogSkeleton()
                  else if (curated != null && curated.blogs.isNotEmpty)
                    _HomeBlogSection(blogs: curated.blogs),
                  if (clean.homeEditorSectionsEnabled && curated != null)
                    for (final section in curated.sections)
                      if (section.cards.isNotEmpty)
                        _HomeEditorSection(section: section),
                  for (final (title, sort, feed) in sections)
                    _HomeSection(title: title, sort: sort, feed: feed),
                  const SizedBox(height: StyleConstants.pagePadding),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _HomeSection extends ConsumerWidget {
  const _HomeSection({
    required this.title,
    required this.sort,
    required this.feed,
  });

  final String title;
  final CommunitySortRule sort;
  final AsyncValue<List<CommunityResource>> feed;

  static const _cardSpacing = 12.0;
  static const _cardTargetWidth = 190.0;
  static const _cardBodyHeight = 76.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return PageContainer(
      padding: const EdgeInsets.fromLTRB(
        StyleConstants.pagePadding,
        StyleConstants.pagePadding,
        StyleConstants.pagePadding,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  ref.read(resourceFiltersProvider.notifier).reset();
                  ref.read(resourceFiltersProvider.notifier).setSort(sort);
                  ref
                      .read(resourceModeControllerProvider.notifier)
                      .setMode(ResourceMode.library);
                },
                child: Text(l10n.more),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final count = math.max(
                2,
                (constraints.maxWidth / _cardTargetWidth).floor(),
              );
              final cardWidth =
                  (constraints.maxWidth - (count - 1) * _cardSpacing) / count;
              final coverHeight = cardWidth * 0.64;
              return SizedBox(
                height: coverHeight + _cardBodyHeight,
                child: switch (feed) {
                  AsyncData(:final value) =>
                    value.isEmpty
                        ? _HomeSlotEmpty(height: coverHeight + _cardBodyHeight)
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: value.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: _cardSpacing),
                            itemBuilder: (context, index) => SizedBox(
                              width: cardWidth,
                              child: _ResourceCard(
                                item: value[index],
                                coverHeight: coverHeight,
                                heroEnabled: false,
                              ),
                            ),
                          ),
                  AsyncError(:final error) => Center(
                    child: Text(
                      localizedErrorMessage(l10n, error),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  _ => ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: count,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: _cardSpacing),
                    itemBuilder: (_, _) => SizedBox(
                      width: cardWidth,
                      child: _HomeResourceSkeleton(coverHeight: coverHeight),
                    ),
                  ),
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HomeEmpty extends ConsumerWidget {
  const _HomeEmpty({this.error});

  final Object? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(StyleConstants.pagePadding * 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              error != null ? Icons.cloud_off_outlined : Icons.home_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              error != null
                  ? localizedErrorMessage(l10n, error!)
                  : l10n.resourceHomeEmptyTitle,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.resourceHomeEmptySubtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (error != null)
              FilledButton.icon(
                onPressed: () {
                  ref.invalidate(homeFeedProvider);
                  ref.invalidate(_featuredFeedProvider);
                  ref.invalidate(_homeFeedProvider);
                },
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
              )
            else
              FilledButton.icon(
                onPressed: () {
                  ref
                      .read(resourceModeControllerProvider.notifier)
                      .setMode(ResourceMode.library);
                },
                icon: const Icon(Icons.library_books_outlined),
                label: Text(l10n.openResourceLibrary),
              ),
          ],
        ),
      ),
    );
  }
}

class _HomeSlotEmpty extends StatelessWidget {
  const _HomeSlotEmpty({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          AppLocalizations.of(context)!.noContent,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _HomeBannerSkeleton extends StatelessWidget {
  const _HomeBannerSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: .12);
    return PageContainer(
      padding: const EdgeInsets.fromLTRB(
        StyleConstants.pagePadding,
        0,
        StyleConstants.pagePadding,
        8,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Container(
          height: math.min(constraints.maxWidth * 9 / 21, 340),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _HomeBlogSkeleton extends StatelessWidget {
  const _HomeBlogSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: .12);
    return PageContainer(
      padding: const EdgeInsets.fromLTRB(
        StyleConstants.pagePadding,
        8,
        StyleConstants.pagePadding,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.resourceHomeUpdates,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) => Container(
              height: math.min(constraints.maxWidth * 9 / 21, 240) + 110,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeResourceSkeleton extends StatelessWidget {
  const _HomeResourceSkeleton({required this.coverHeight});

  final double coverHeight;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: .12);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: coverHeight, color: color),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 112,
                  height: 14,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 68,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeBannerCarousel extends ConsumerStatefulWidget {
  const _HomeBannerCarousel({required this.banners});

  final List<HomeBanner> banners;

  @override
  ConsumerState<_HomeBannerCarousel> createState() =>
      _HomeBannerCarouselState();
}

class _HomeBannerCarouselState extends ConsumerState<_HomeBannerCarousel> {
  final _controller = PageController();
  Timer? _timer;
  var _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_controller.hasClients || widget.banners.length < 2) {
        return;
      }
      _controller.animateToPage(
        (_index + 1) % widget.banners.length,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _open(HomeBanner banner) {
    switch (banner.type) {
      case HomeBannerType.resource:
        if (banner.resourceId.isNotEmpty) {
          context.push(
            '/resources/detail/${banner.resourceId}?source=${CommunitySourceId.oronBox.storageKey}',
          );
        }
      case HomeBannerType.blog:
        if (banner.blogSlug.isNotEmpty) {
          context.push(
            '/resources/blog/${banner.blogSlug}',
            extra: BlogCard(
              slug: banner.blogSlug,
              type: 'announcement',
              title: banner.title,
              subtitle: banner.subtitle,
              author: '',
              coverUrl: banner.coverUrl,
            ),
          );
        }
      case HomeBannerType.link:
        final url = banner.linkUrl;
        if (url != null) openResourceExternalLink(context, url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PageContainer(
      padding: const EdgeInsets.fromLTRB(
        StyleConstants.pagePadding,
        0,
        StyleConstants.pagePadding,
        8,
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) => SizedBox(
              height: math.min(constraints.maxWidth * 9 / 21, 340),
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.banners.length,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (context, index) {
                  final banner = widget.banners[index];
                  return Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    color: colors.surfaceContainerHighest.withValues(alpha: .5),
                    child: InkWell(
                      onTap: () => _open(banner),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (banner.coverUrl != null)
                            NetworkImgLayer(
                              src: banner.coverUrl!.toString(),
                              fit: BoxFit.cover,
                              borderRadius: BorderRadius.zero,
                            ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: .72),
                                ],
                                stops: const [.38, 1],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 18,
                            right: 18,
                            bottom: 14,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  banner.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                if (banner.subtitle.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    banner.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Colors.white.withValues(
                                            alpha: .85,
                                          ),
                                        ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (widget.banners.length > 1) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.banners.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _index ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? colors.primary
                          : colors.onSurfaceVariant.withValues(alpha: .35),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeEditorSection extends StatelessWidget {
  const _HomeEditorSection({required this.section});

  final HomeSection section;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PageContainer(
      padding: const EdgeInsets.fromLTRB(
        StyleConstants.pagePadding,
        8,
        StyleConstants.pagePadding,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.name,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (section.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              section.description,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 12),
          for (final card in section.cards) ...[
            if (card.resource != null)
              _WideResourceCard(card: card.resource!)
            else if (card.blog != null)
              _HomeBlogCard(card: card.blog!, heroEnabled: false),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _HomeBlogSection extends StatelessWidget {
  const _HomeBlogSection({required this.blogs});

  final List<BlogCard> blogs;

  @override
  Widget build(BuildContext context) => PageContainer(
    padding: const EdgeInsets.fromLTRB(
      StyleConstants.pagePadding,
      8,
      StyleConstants.pagePadding,
      0,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.resourceHomeUpdates,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        for (final blog in blogs) ...[
          _HomeBlogCard(card: blog, heroEnabled: true),
          const SizedBox(height: 12),
        ],
      ],
    ),
  );
}

CommunityResourceType _homeCardKind(String kind) => switch (kind) {
  'zepp_app' => CommunityResourceType.miniprogram,
  'watchface' => CommunityResourceType.watchface,
  'firmware' => CommunityResourceType.firmware,
  _ => CommunityResourceType.quickApp,
};

class _WideResourceCard extends StatelessWidget {
  const _WideResourceCard({required this.card});

  final HomeResourceCard card;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: colors.surfaceContainerHighest.withValues(alpha: .5),
      child: InkWell(
        onTap: () => context.push(
          '/resources/detail/${card.id}',
          extra: CommunityResource(
            ref: ResourceRef(source: CommunitySourceId.oronBox, id: card.id),
            name: card.name,
            type: _homeCardKind(card.kind),
            paidType: CommunityPaidType.free,
            authors: [
              if (card.owner.isNotEmpty)
                CommunityResourceAuthor(name: card.owner),
            ],
            supportedDevices: const {},
            iconUrl: card.iconUrl,
            coverUrl: card.coverUrl,
            summary: card.summary,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  NetworkImgLayer(
                    src: (card.iconUrl ?? card.coverUrl)?.toString(),
                    width: 56,
                    height: 56,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (card.summary.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            card.summary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _ResourceLabel(
                    label: _typeLabel(
                      l10n,
                      _homeCardKind(card.kind),
                      source: CommunitySourceId.oronBox,
                    ),
                    color: colors.primary,
                  ),
                  if (card.owner.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Icon(
                      Icons.person_outline,
                      size: 14,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        card.owner,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (card.previews.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (var i = 0; i < card.previews.take(3).length; i++) ...[
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 16 / 10,
                          child: NetworkImgLayer(
                            src: card.previews[i].toString(),
                            fit: BoxFit.cover,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      if (i < card.previews.take(3).length - 1)
                        const SizedBox(width: 8),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeBlogCard extends StatelessWidget {
  const _HomeBlogCard({required this.card, required this.heroEnabled});

  final BlogCard card;
  final bool heroEnabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: colors.surfaceContainerHighest.withValues(alpha: .5),
      child: InkWell(
        onTap: () => context.push('/resources/blog/${card.slug}', extra: card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final height = math.min(constraints.maxWidth * 9 / 21, 240.0);
                return card.coverUrl != null
                    ? HeroMode(
                        enabled: heroEnabled,
                        child: ResourceMediaHero(
                          tag: 'blog-cover-${card.slug}',
                          url: card.coverUrl!.toString(),
                          width: double.infinity,
                          height: height,
                          style: const ResourceMediaHeroStyle(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          fit: BoxFit.cover,
                        ),
                      )
                    : Container(
                        height: height,
                        color: colors.primaryContainer.withValues(alpha: .35),
                      );
              },
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ResourceLabel(
                    label: blogTypeLabel(l10n, card.type),
                    color: colors.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    card.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (card.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      card.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResourceLibraryView extends ConsumerStatefulWidget {
  const _ResourceLibraryView({super.key});
  @override
  ConsumerState<_ResourceLibraryView> createState() =>
      _ResourceLibraryViewState();
}

/// Marker for the signed-out BandBBS state, so the error view can offer a
/// sign-in action instead of a bare message.
class _BandBbsSignInRequired implements Exception {
  const _BandBbsSignInRequired();
}

class _ResourceLibraryViewState extends ConsumerState<_ResourceLibraryView>
    with SingleTickerProviderStateMixin {
  static const _pageSize = 30;
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  var _searchText = '';
  bool? _sidebarExpanded;
  var _gridView =
      SharedPrefsService.instance.getBool('resource_grid_view') ?? true;
  late final AnimationController _layoutAnimation;
  final _resourceLayoutKeys = <String, GlobalKey>{};
  var _resourceLayoutMotions = const <String, _ResourceLayoutMotion>{};
  var _preparingLayoutMotion = false;
  final _items = <CommunityResource>[];
  var _page = 0;
  var _hasMore = true;
  var _loading = true;
  var _loadingMore = false;
  var _waitingForSidebarLoad = false;
  var _fillCheckScheduled = false;
  Object? _error;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    _layoutAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _scrollController.addListener(_onScroll);
    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus) _commitSearch();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _reset());
  }

  @override
  void dispose() {
    _layoutAnimation.dispose();
    _searchFocus.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  GlobalKey _resourceLayoutKey(CommunityResource item) => _resourceLayoutKeys
      .putIfAbsent(item.ref.key, () => GlobalKey(debugLabel: item.ref.key));

  Map<String, Rect> _captureResourceRects() {
    final result = <String, Rect>{};
    for (final entry in _resourceLayoutKeys.entries) {
      final renderObject = entry.value.currentContext?.findRenderObject();
      if (renderObject case final RenderBox box when box.hasSize) {
        result[entry.key] = box.localToGlobal(Offset.zero) & box.size;
      }
    }
    return result;
  }

  void _toggleLayout() {
    final sourceRects = _captureResourceRects();
    _layoutAnimation.stop();
    final widthProgress = ((MediaQuery.sizeOf(context).width - 600) / 800)
        .clamp(0.0, 1.0);
    _layoutAnimation.duration = Duration(
      milliseconds: (240 + 240 * widthProgress).round(),
    );
    setState(() {
      _gridView = !_gridView;
      _resourceLayoutMotions = const {};
      _preparingLayoutMotion = true;
    });
    unawaited(
      SharedPrefsService.instance.setBool('resource_grid_view', _gridView),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final targetRects = _captureResourceRects();
      final motions = <String, _ResourceLayoutMotion>{};
      for (final entry in sourceRects.entries) {
        final target = targetRects[entry.key];
        if (target != null && target.width > 0 && target.height > 0) {
          motions[entry.key] = _ResourceLayoutMotion(
            source: entry.value,
            target: target,
          );
        }
      }
      setState(() {
        _resourceLayoutMotions = motions;
        _preparingLayoutMotion = false;
      });
      _layoutAnimation.forward(from: 0);
    });
  }

  Widget _animateResourceLayout(CommunityResource item, Widget child) {
    return _ResourceLayoutTransition(
      key: _resourceLayoutKey(item),
      animation: _layoutAnimation,
      motion: _resourceLayoutMotions[item.ref.key],
      hidden: _preparingLayoutMotion,
      child: child,
    );
  }

  void _commitSearch() {
    final value = _searchController.text;
    if (value == ref.read(resourceFiltersProvider).query) return;
    ref.read(resourceFiltersProvider.notifier).setQuery(value);
  }

  void _onScroll() {
    if (_error != null) return;
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 600) {
      _load(_generation);
    }
  }

  void _scheduleViewportFill(int generation) {
    if (_fillCheckScheduled) return;
    _fillCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fillCheckScheduled = false;
      if (!mounted ||
          generation != _generation ||
          _error != null ||
          !_scrollController.hasClients) {
        return;
      }
      if (_scrollController.position.extentAfter < 600) {
        _load(generation);
      }
    });
  }

  Future<void> _reset() async {
    final generation = ++_generation;
    setState(() {
      _items.clear();
      _page = 0;
      _hasMore = true;
      _loading = true;
      _loadingMore = false;
      _error = null;
    });
    await _load(generation);
  }

  Future<void> _load(int generation) async {
    if (!_hasMore || _loadingMore) return;
    if (ref.read(selectedCommunitySourceProvider) ==
            CommunitySourceId.bandbbs &&
        !ref.read(bandBbsAuthProvider).isSignedIn) {
      // The daemon rejects every BandBBS request when signed out; short
      // circuit here instead of hammering it from the viewport-fill loop.
      setState(() {
        _items.clear();
        _hasMore = false;
        _loading = false;
        _loadingMore = false;
        _error = const _BandBbsSignInRequired();
      });
      return;
    }
    _ensureBandBbsSidebarLoaded();
    setState(() => _loadingMore = true);
    try {
      final filters = ref.read(resourceFiltersProvider);
      final result = await ref
          .read(communityCatalogProvider)
          .getPage(
            CommunityResourceQuery(
              page: _page,
              pageSize: _pageSize,
              query: filters.query,
              sort: filters.sort,
              type: filters.type,
              hidePaid: filters.hidePaid,
              hideForcePaid: filters.hideForcePaid,
              featured: filters.featured,
              selectedDevices: filters.selectedDevices,
              selectedAttributes: filters.selectedAttributes,
            ),
          );
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(
          result.items.where(
            (item) => !_items.any((current) => current.ref == item.ref),
          ),
        );
        _page += 1;
        _hasMore = result.hasMore && result.items.isNotEmpty;
        _loading = false;
        _loadingMore = false;
      });
      _scheduleViewportFill(generation);
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error;
        _hasMore = false;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _ensureBandBbsSidebarLoaded() {
    if (ref.read(selectedCommunitySourceProvider) !=
        CommunitySourceId.bandbbs) {
      return;
    }
    final tree = ref.read(bandbbsCategoryTreeProvider);
    if (tree.isLoading) {
      if (_waitingForSidebarLoad) return;
      _waitingForSidebarLoad = true;
      unawaited(
        _retryBandBbsSidebarAfter(ref.read(bandbbsCategoryTreeProvider.future)),
      );
      return;
    }
    final roots = tree.value;
    if (roots == null || roots.isEmpty) {
      ref.invalidate(bandbbsCategoryTreeProvider);
    }
  }

  Future<void> _retryBandBbsSidebarAfter(
    Future<List<BandBbsCategoryNode>> request,
  ) async {
    var hasCategories = false;
    try {
      hasCategories = (await request).isNotEmpty;
    } catch (_) {
      // The resource list remains usable when category loading fails
    } finally {
      _waitingForSidebarLoad = false;
    }
    if (!mounted || hasCategories) return;
    if (ref.read(selectedCommunitySourceProvider) ==
        CommunitySourceId.bandbbs) {
      ref.invalidate(bandbbsCategoryTreeProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final filters = ref.watch(resourceFiltersProvider);
    final source = ref.watch(selectedCommunitySourceProvider);
    ref.listen(resourceFiltersProvider, (_, _) => _reset());
    ref.listen(resourceRefreshProvider, (_, _) => _reset());
    ref.listen(bandBbsAuthProvider, (previous, next) {
      if (!(previous?.isSignedIn ?? false) && next.isSignedIn) _reset();
    });
    ref.listen(
      appSettingsProvider.select(
        (settings) => settings.bandbbsShowAllCategories,
      ),
      (_, _) => _reset(),
    );
    final capabilities = ref.watch(communityCatalogProvider).capabilities;
    final forceList =
        source == CommunitySourceId.bandbbs ||
        source == CommunitySourceId.huamiAppStore;
    if (!_searchFocus.hasFocus && _searchController.text != filters.query) {
      _searchController.text = filters.query;
      _searchText = filters.query;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        _scheduleViewportFill(_generation);
        final isBandBbs = source == CommunitySourceId.bandbbs;
        final expanded =
            isBandBbs && (_sidebarExpanded ?? constraints.maxWidth >= 900);
        final list = _buildList(
          context,
          l10n,
          filters,
          source,
          gridView: !forceList && _gridView,
        );
        return Column(
          children: [
            _buildToolbar(
              context,
              l10n,
              capabilities,
              sidebarExpanded: expanded,
              onToggleSidebar: isBandBbs
                  ? () => setState(() => _sidebarExpanded = !expanded)
                  : null,
              showLayoutToggle: !forceList,
            ),
            Expanded(
              child: !isBandBbs
                  ? list
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          width: expanded ? 260 : 0,
                          clipBehavior: Clip.hardEdge,
                          decoration: const BoxDecoration(),
                          child: const OverflowBox(
                            alignment: Alignment.topLeft,
                            minWidth: 260,
                            maxWidth: 260,
                            child: BandBbsCategorySidebar(),
                          ),
                        ),
                        Expanded(child: list),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildToolbar(
    BuildContext context,
    AppLocalizations l10n,
    CommunityCatalogCapabilities capabilities, {
    required bool sidebarExpanded,
    VoidCallback? onToggleSidebar,
    required bool showLayoutToggle,
  }) {
    final colors = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 600;
    final toolbarButtonStyle = IconButton.styleFrom(
      backgroundColor: colors.surfaceContainerHigh,
      foregroundColor: colors.onSurfaceVariant,
      hoverColor: colors.surfaceContainerHighest,
      highlightColor: colors.surfaceContainerHighest,
    );
    return PageContainer(
      padding: EdgeInsets.symmetric(
        horizontal: StyleConstants.pagePadding,
        vertical: compact ? 10 : StyleConstants.pagePadding,
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (onToggleSidebar != null) ...[
                IconButton.filled(
                  style: toolbarButtonStyle,
                  icon: Icon(sidebarExpanded ? Icons.menu_open : Icons.menu),
                  tooltip: l10n.categories,
                  onPressed: onToggleSidebar,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: SearchBar(
                  constraints: BoxConstraints.tightFor(
                    height: compact ? 48 : 56,
                  ),
                  enabled: capabilities.search,
                  elevation: const WidgetStatePropertyAll(0),
                  controller: _searchController,
                  focusNode: _searchFocus,
                  hintText: l10n.search,
                  leading: const Icon(Icons.search),
                  trailing: [
                    if (_searchText.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchText = '');
                          ref
                              .read(resourceFiltersProvider.notifier)
                              .setQuery('');
                        },
                      ),
                  ],
                  onChanged: (value) => setState(() => _searchText = value),
                  onSubmitted: (_) => _commitSearch(),
                ),
              ),
              if (showLayoutToggle) ...[
                const SizedBox(width: 8),
                IconButton.filled(
                  style: toolbarButtonStyle,
                  tooltip: _gridView
                      ? l10n.resourceListView
                      : l10n.resourceGridView,
                  onPressed: _toggleLayout,
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: RotationTransition(
                        turns: Tween<double>(begin: -.12, end: 0).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                        child: child,
                      ),
                    ),
                    child: Icon(
                      _gridView ? Icons.view_list : Icons.grid_view,
                      key: ValueKey(_gridView),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          const _FilterBar(),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    AppLocalizations l10n,
    ResourceFilters filters,
    CommunitySourceId source, {
    required bool gridView,
  }) {
    return RefreshIndicator(
      onRefresh: _reset,
      child: ScrollConfiguration(
        behavior: const _NoStretchScrollBehavior(),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: switch (_error) {
                    _BandBbsSignInRequired() => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l10n.settingsBandBbsAccountRequired),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => context.push('/settings/bandbbs'),
                          child: Text(l10n.settingsTapToSignIn),
                        ),
                      ],
                    ),
                    _ => Text(localizedErrorMessage(l10n, _error!)),
                  },
                ),
              )
            else ...[
              if (!gridView)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: StyleConstants.pagePadding,
                  ),
                  sliver: SliverList.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, index) => Padding(
                      padding: EdgeInsets.only(
                        bottom: index == _items.length - 1 ? 0 : 8,
                      ),
                      child: _animateResourceLayout(
                        _items[index],
                        BandBbsResourceCard(
                          key: ValueKey(_items[index].ref.key),
                          item: _items[index],
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: PageContainer(
                    padding: const EdgeInsets.symmetric(
                      horizontal: StyleConstants.pagePadding,
                    ),
                    child: _ResourceGrid(
                      items: _items,
                      animateItem: _animateResourceLayout,
                    ),
                  ),
                ),
              if (_loadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (_items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text(l10n.notFound)),
                )
              else if (!_hasMore)
                SliverToBoxAdapter(
                  child: PageContainer(
                    padding: const EdgeInsets.symmetric(
                      horizontal: StyleConstants.pagePadding,
                    ),
                    child: _OtherSourcesFooter(currentSource: source),
                  ),
                ),
            ],
            const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
          ],
        ),
      ),
    );
  }
}

// Android 默认的拉伸 overscroll 会把边缘卡片的圆角拉变形,禁掉
class _NoStretchScrollBehavior extends MaterialScrollBehavior {
  const _NoStretchScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

bool _isCurrentDeviceZepp(DeviceManagerState state) {
  final device = state.currentDevice;
  if (device == null) return false;
  return DeviceRegistry.resolveIdentity(
        name: device.name,
        codename: device.codename,
      ).kind ==
      DeviceKind.zepp;
}

List<CommunitySourceId> enabledCommunitySources(
  List<CommunitySourceId>? loadedSources,
  CleanSettings clean, {
  required bool isZepposDevice,
}) => [
  for (final candidate in loadedSources ?? CommunitySourceId.values)
    if ((candidate != CommunitySourceId.oronBox ||
            (clean.oronBoxSourceEnabled && !isZepposDevice)) &&
        (candidate != CommunitySourceId.bandbbs ||
            clean.bandBbsSourceEnabled) &&
        (candidate != CommunitySourceId.astroboxRepo ||
            (clean.astroBoxSourceEnabled && !isZepposDevice)) &&
        (candidate != CommunitySourceId.huamiAppStore ||
            (clean.huamiAppStoreSourceEnabled && isZepposDevice)))
      candidate,
];

Future<void> _switchCommunitySource(
  BuildContext context,
  WidgetRef ref,
  CommunitySourceId candidate,
) async {
  final l10n = AppLocalizations.of(context)!;
  if (candidate == CommunitySourceId.bandbbs) {
    final host = ref.read(hostAccountsProvider.notifier);
    await host.refresh();
    if (!context.mounted) return;
    if (!ref.read(hostAccountsProvider).bandbbs.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsBandBbsAccountRequired)),
      );
      return;
    }
  }
  if (candidate == CommunitySourceId.huamiAppStore &&
      !ref.read(hostAccountsProvider).amazfit.isSignedIn) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.settingsHuamiAccountRequired)));
    return;
  }
  await ref.read(appSettingsProvider.notifier).setCommunitySource(candidate);
  ref.read(resourceFiltersProvider.notifier).reset();
}

class _CommunitySourceMenu extends ConsumerWidget {
  const _CommunitySourceMenu();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(selectedCommunitySourceProvider);
    final loadedSources = ref.watch(communitySourcesProvider).value;
    final clean = ref.watch(appSettingsProvider).clean;
    final sourceById = <String, CommunitySourceId>{
      for (final candidate in enabledCommunitySources(
        loadedSources,
        clean,
        isZepposDevice: _isCurrentDeviceZepp(ref.watch(deviceManagerProvider)),
      ))
        candidate.storageKey: candidate,
    };
    if (!sourceById.containsKey(source.storageKey) && sourceById.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(appSettingsProvider.notifier)
            .setCommunitySource(sourceById.values.first);
      });
    }
    final l10n = AppLocalizations.of(context)!;
    return MenuAnchor(
      menuChildren: sourceById.values
          .map(
            (candidate) => MenuItemButton(
              trailingIcon: candidate == source
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onPressed: candidate == source
                  ? null
                  : () => _switchCommunitySource(context, ref, candidate),
              child: Text(_communitySourceLabel(l10n, candidate)),
            ),
          )
          .toList(),
      builder: (_, controller, _) => TextButton.icon(
        onPressed: controller.isOpen ? controller.close : controller.open,
        icon: const Icon(Icons.arrow_drop_down),
        label: Text(_communitySourceLabel(l10n, source)),
      ),
    );
  }
}

class _OtherSourcesFooter extends ConsumerWidget {
  const _OtherSourcesFooter({required this.currentSource});

  final CommunitySourceId currentSource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final clean = ref.watch(appSettingsProvider).clean;
    final loadedSources = ref.watch(communitySourcesProvider).value;
    final others = enabledCommunitySources(
      loadedSources,
      clean,
      isZepposDevice: _isCurrentDeviceZepp(ref.watch(deviceManagerProvider)),
    ).where((candidate) => candidate != currentSource).toList();
    if (others.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(
            l10n.resourceLibraryEndOfList,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final candidate in others)
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.surfaceContainerHighest,
                    foregroundColor: colors.onSurface,
                  ),
                  onPressed: () =>
                      _switchCommunitySource(context, ref, candidate),
                  child: Text(_communitySourceLabel(l10n, candidate)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final filters = ref.watch(resourceFiltersProvider);
    final source = ref.watch(selectedCommunitySourceProvider);
    final devices =
        ref.watch(communityCatalogDevicesProvider).value ??
        const <CommunityResourceDevice>[];
    final deviceOptions = _buildDeviceFilterOptions(devices);
    final resourceAttributes = source == CommunitySourceId.oronBox
        ? ref.watch(oronBoxResourceAttributesProvider).value ?? const []
        : const <OronBoxResourceAttribute>[];
    final selectedDeviceOptions = deviceOptions
        .where((option) => option.ids.any(filters.selectedDevices.contains))
        .toList();
    final knownDeviceIds = deviceOptions.expand((option) => option.ids).toSet();
    final unknownSelectedDevices = filters.selectedDevices
        .where((id) => !knownDeviceIds.contains(id))
        .toList();
    final categoryTitles = <String, String>{};
    final attributeLabels = {
      for (final attribute in resourceAttributes)
        attribute.id: attribute.labelFor(Localizations.localeOf(context)),
    };
    if (source == CommunitySourceId.bandbbs) {
      void collect(List<BandBbsCategoryNode> nodes) {
        for (final node in nodes) {
          categoryTitles['${BandBbsCategorySidebar.categoryFilterPrefix}${node.id}'] =
              node.title;
          collect(node.children);
        }
      }

      collect(ref.watch(bandbbsCategoryTreeProvider).value ?? const []);
    }
    final hasActiveFilters =
        filters.type != null ||
        filters.hidePaid ||
        filters.featured ||
        (source == CommunitySourceId.astroboxRepo && filters.hideForcePaid) ||
        filters.selectedDevices.isNotEmpty ||
        filters.selectedAttributes.isNotEmpty;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: Text(l10n.filter),
            selected: hasActiveFilters,
            onPressed: () => _showFilters(context),
          ),
          const SizedBox(width: 8),
          ...selectedDeviceOptions.map(
            (option) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(option.label),
                selected: true,
                onSelected: (_) => ref
                    .read(resourceFiltersProvider.notifier)
                    .toggleDeviceGroup(option.ids),
              ),
            ),
          ),
          ...unknownSelectedDevices.map(
            (codename) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(
                  source == CommunitySourceId.huamiAppStore &&
                          int.tryParse(codename) != null
                      ? '\u8bbe\u5907\u6e90 $codename'
                      : categoryTitles[codename] ?? codename,
                ),
                selected: true,
                onSelected: (_) => ref
                    .read(resourceFiltersProvider.notifier)
                    .toggleDevice(codename),
              ),
            ),
          ),
          if (filters.type != null) ...[
            const SizedBox(width: 8),
            Padding(
              padding: EdgeInsets.zero,
              child: FilterChip(
                label: Text(_typeLabel(l10n, filters.type!, source: source)),
                selected: true,
                onSelected: (_) =>
                    ref.read(resourceFiltersProvider.notifier).setType(null),
              ),
            ),
          ],
          if (source == CommunitySourceId.oronBox)
            for (final attribute in filters.selectedAttributes)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: FilterChip(
                  label: Text(attributeLabels[attribute] ?? attribute),
                  selected: true,
                  onSelected: (_) => ref
                      .read(resourceFiltersProvider.notifier)
                      .toggleAttribute(attribute),
                ),
              ),
          if (filters.hidePaid)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: FilterChip(
                label: Text(l10n.paid),
                selected: true,
                onSelected: (_) => ref
                    .read(resourceFiltersProvider.notifier)
                    .setHidePaid(false),
              ),
            ),
          if (filters.featured)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: FilterChip(
                label: Text(l10n.resourceHomeFeatured),
                selected: true,
                onSelected: (_) => ref
                    .read(resourceFiltersProvider.notifier)
                    .setFeatured(false),
              ),
            ),
          if (source == CommunitySourceId.astroboxRepo && filters.hideForcePaid)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: FilterChip(
                label: Text(l10n.forcePaid),
                selected: true,
                onSelected: (_) => ref
                    .read(resourceFiltersProvider.notifier)
                    .setHideForcePaid(false),
              ),
            ),
        ],
      ),
    );
  }

  void _showFilters(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return _FilterSheet(scrollController: scrollController);
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final Widget label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: label,
      avatar: Icon(
        selected ? Icons.filter_list_off : Icons.filter_list,
        size: 18,
      ),
      onPressed: onPressed,
    );
  }
}

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final filters = ref.watch(resourceFiltersProvider);
    final source = ref.watch(selectedCommunitySourceProvider);
    final devices =
        ref.watch(communityCatalogDevicesProvider).value ??
        const <CommunityResourceDevice>[];
    final deviceOptions = _buildDeviceFilterOptions(devices);
    final resourceAttributes = source == CommunitySourceId.oronBox
        ? ref.watch(oronBoxResourceAttributesProvider).value ??
              const <OronBoxResourceAttribute>[]
        : const <OronBoxResourceAttribute>[];
    final deviceSectionTitle = source == CommunitySourceId.bandbbs
        ? l10n.categories
        : l10n.devices;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        Text(l10n.filter, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Text(l10n.all, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (source != CommunitySourceId.huamiAppStore)
              FilterChip(
                label: Text(
                  _typeLabel(
                    l10n,
                    CommunityResourceType.quickApp,
                    source: source,
                  ),
                ),
                selected: filters.type == CommunityResourceType.quickApp,
                onSelected: (_) => ref
                    .read(resourceFiltersProvider.notifier)
                    .setType(
                      filters.type == CommunityResourceType.quickApp
                          ? null
                          : CommunityResourceType.quickApp,
                    ),
              ),
            if (source == CommunitySourceId.oronBox ||
                source == CommunitySourceId.huamiAppStore ||
                source.isPlugin)
              FilterChip(
                label: Text(l10n.miniprograms),
                selected: filters.type == CommunityResourceType.miniprogram,
                onSelected: (_) => ref
                    .read(resourceFiltersProvider.notifier)
                    .setType(
                      filters.type == CommunityResourceType.miniprogram
                          ? null
                          : CommunityResourceType.miniprogram,
                    ),
              ),
            FilterChip(
              label: Text(l10n.watchfaces),
              selected: filters.type == CommunityResourceType.watchface,
              onSelected: (_) => ref
                  .read(resourceFiltersProvider.notifier)
                  .setType(
                    filters.type == CommunityResourceType.watchface
                        ? null
                        : CommunityResourceType.watchface,
                  ),
            ),
            FilterChip(
              label: Text(l10n.firmwareTools),
              selected: filters.type == CommunityResourceType.firmware,
              onSelected: (_) => ref
                  .read(resourceFiltersProvider.notifier)
                  .setType(
                    filters.type == CommunityResourceType.firmware
                        ? null
                        : CommunityResourceType.firmware,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(deviceSectionTitle, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: deviceOptions
              .map(
                (option) => FilterChip(
                  label: Text(option.label),
                  selected: option.ids.any(filters.selectedDevices.contains),
                  onSelected: (_) {
                    ref
                        .read(resourceFiltersProvider.notifier)
                        .toggleDeviceGroup(option.ids);
                  },
                ),
              )
              .toList(),
        ),
        if (source == CommunitySourceId.huamiAppStore) ...[
          const SizedBox(height: 12),
          _HuamiDeviceSourceInput(filters: filters),
        ],
        if (source == CommunitySourceId.oronBox) ...[
          const SizedBox(height: 16),
          Text(
            l10n.creatorContentAttributes,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: Text(l10n.resourceHomeFeatured),
                selected: filters.featured,
                onSelected: (value) => ref
                    .read(resourceFiltersProvider.notifier)
                    .setFeatured(value),
              ),
              for (final attribute in resourceAttributes)
                FilterChip(
                  label: Text(
                    attribute.labelFor(Localizations.localeOf(context)),
                  ),
                  selected: filters.selectedAttributes.contains(attribute.id),
                  onSelected: (_) => ref
                      .read(resourceFiltersProvider.notifier)
                      .toggleAttribute(attribute.id),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Text(l10n.paid, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: Text('${l10n.hide}${l10n.paid}'),
              selected: filters.hidePaid,
              onSelected: (value) =>
                  ref.read(resourceFiltersProvider.notifier).setHidePaid(value),
            ),
            if (source == CommunitySourceId.astroboxRepo)
              FilterChip(
                label: Text('${l10n.hide}${l10n.forcePaid}'),
                selected: filters.hideForcePaid,
                onSelected: (value) => ref
                    .read(resourceFiltersProvider.notifier)
                    .setHideForcePaid(value),
              ),
          ],
        ),
      ],
    );
  }
}

class _HuamiDeviceSourceInput extends ConsumerStatefulWidget {
  const _HuamiDeviceSourceInput({required this.filters});

  final ResourceFilters filters;

  @override
  ConsumerState<_HuamiDeviceSourceInput> createState() =>
      _HuamiDeviceSourceInputState();
}

class _HuamiDeviceSourceInputState
    extends ConsumerState<_HuamiDeviceSourceInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _firstNumericDeviceSource());
  }

  @override
  void didUpdateWidget(covariant _HuamiDeviceSourceInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final value = _firstNumericDeviceSource();
    if (value != _controller.text) {
      _controller.text = value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '\u8bbe\u5907\u6e90',
              hintText: '260',
              prefixIcon: const Icon(Icons.numbers),
              isDense: true,
              border: const OutlineInputBorder(),
              suffixIcon: widget.filters.selectedDevices.any(_isNumeric)
                  ? IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).deleteButtonTooltip,
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _controller.clear();
                        ref
                            .read(resourceFiltersProvider.notifier)
                            .clearNumericDevices();
                      },
                    )
                  : null,
            ),
            onSubmitted: (_) => _apply(),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: color.primaryContainer,
            foregroundColor: color.onPrimaryContainer,
          ),
          onPressed: _apply,
          child: const Text('\u5e94\u7528'),
        ),
      ],
    );
  }

  void _apply() {
    final source = int.tryParse(_controller.text.trim());
    if (source == null || source <= 0) return;
    ref.read(resourceFiltersProvider.notifier).setNumericDevice(source);
  }

  String _firstNumericDeviceSource() =>
      widget.filters.selectedDevices.firstWhere(_isNumeric, orElse: () => '');

  bool _isNumeric(String value) {
    final parsed = int.tryParse(value);
    return parsed != null && parsed > 0;
  }
}

class _DeviceFilterOption {
  const _DeviceFilterOption({required this.label, required this.ids});

  final String label;
  final Set<String> ids;
}

List<_DeviceFilterOption> _buildDeviceFilterOptions(
  Iterable<CommunityResourceDevice> devices,
) {
  final grouped = <String, Set<String>>{};
  for (final device in devices) {
    final rawId = device.codename.trim();
    final identity = normalizeXiaomiWearableIdentity(rawId);
    final id = identity?.codename ?? rawId;
    if (id.isEmpty) continue;

    final label =
        identity?.displayName ??
        (device.name.trim().isNotEmpty ? device.name.trim() : id);
    grouped.putIfAbsent(label, () => <String>{}).add(id);
  }

  return grouped.entries
      .map((entry) => _DeviceFilterOption(label: entry.key, ids: entry.value))
      .toList()
    ..sort((a, b) => a.label.compareTo(b.label));
}

String _typeLabel(
  AppLocalizations l10n,
  CommunityResourceType type, {
  CommunitySourceId? source,
}) => switch (type) {
  CommunityResourceType.quickApp =>
    source == CommunitySourceId.huamiAppStore
        ? l10n.miniprograms
        : l10n.quickApps,
  CommunityResourceType.miniprogram => l10n.miniprograms,
  CommunityResourceType.watchface => l10n.watchfaces,
  CommunityResourceType.firmware => l10n.firmwareTools,
};

String _communitySourceLabel(AppLocalizations l10n, CommunitySourceId source) =>
    switch (source) {
      CommunitySourceId.astroboxRepo => l10n.communitySourceAstroBoxRepo,
      CommunitySourceId.bandbbs => l10n.communitySourceBandBbs,
      CommunitySourceId.huamiAppStore => l10n.communitySourceHuamiAppStore,
      _ => source.displayName,
    };

class _ResourceGrid extends StatelessWidget {
  const _ResourceGrid({required this.items, required this.animateItem});
  final List<CommunityResource> items;
  final Widget Function(CommunityResource item, Widget child) animateItem;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final spacing = 10.0;
        final minTrackWidth = 150.0;
        final crossAxisCount = ((width + spacing) / (minTrackWidth + spacing))
            .floor()
            .clamp(1, 1000);
        final trackWidth =
            (width - (crossAxisCount - 1) * spacing) / crossAxisCount;
        final cardWidth = trackWidth > 300 ? 300.0 : trackWidth;
        final coverHeight = cardWidth * 2 / 3;

        return Wrap(
          alignment: WrapAlignment.start,
          spacing: spacing,
          runSpacing: spacing,
          children: items.indexed.map((entry) {
            final (index, item) = entry;
            return SizedBox(
              width: trackWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: cardWidth,
                  child: animateItem(
                    item,
                    _ResourceCard(item: item, coverHeight: coverHeight),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ResourceLayoutMotion {
  const _ResourceLayoutMotion({required this.source, required this.target});

  final Rect source;
  final Rect target;
}

class _ResourceLayoutTransition extends StatelessWidget {
  const _ResourceLayoutTransition({
    super.key,
    required this.animation,
    required this.motion,
    required this.hidden,
    required this.child,
  });

  final Animation<double> animation;
  final _ResourceLayoutMotion? motion;
  final bool hidden;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        if (hidden) return Opacity(opacity: 0, child: child);
        final currentMotion = motion;
        if (currentMotion == null) return child!;
        final progress = Curves.easeInOutCubic.transform(animation.value);
        final remaining = 1 - progress;
        final target = currentMotion.target;
        final source = currentMotion.source;
        final scaleX = 1 + (source.width / target.width - 1) * remaining;
        final scaleY = 1 + (source.height / target.height - 1) * remaining;
        final opacityDistance = progress * 2 - 1;
        final mediaOpacity = opacityDistance * opacityDistance;
        final transform = Matrix4.diagonal3Values(scaleX, scaleY, 1)
          ..setTranslationRaw(
            (source.left - target.left) * remaining,
            (source.top - target.top) * remaining,
            0,
          );
        return ResourceLayoutMediaOpacity(
          opacity: mediaOpacity,
          child: Transform(
            alignment: Alignment.topLeft,
            transform: transform,
            child: child,
          ),
        );
      },
    );
  }
}

class _ResourceCard extends ConsumerWidget {
  const _ResourceCard({
    required this.item,
    required this.coverHeight,
    this.heroEnabled = true,
  });
  final CommunityResource item;
  final double coverHeight;
  final bool heroEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = Theme.of(context).colorScheme;
    final image = item.coverUrl ?? item.iconUrl;
    final heroRole = item.coverUrl != null ? 'cover' : 'icon';
    final attributeLabels = {
      for (final attribute
          in ref.watch(oronBoxResourceAttributesProvider).value ??
              const <OronBoxResourceAttribute>[])
        attribute.id: attribute.labelFor(Localizations.localeOf(context)),
    };
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: color.surfaceContainerHighest.withValues(alpha: .5),
      child: InkWell(
        onTap: () => item.isCollection
            ? context.push('/resources/collection/${item.ref.id}', extra: item)
            : context.push('/resources/detail/${item.ref.id}', extra: item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HeroMode(
              enabled: heroEnabled,
              child: ResourceMediaHero(
                tag: resourceMediaHeroTag(item.ref, heroRole),
                url: image?.toString() ?? '',
                width: double.infinity,
                height: coverHeight,
                style: const ResourceMediaHeroStyle(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _ResourceLabel(
                        label: _typeLabel(
                          AppLocalizations.of(context)!,
                          item.type,
                          source: item.ref.source,
                        ),
                        color: color.primary,
                      ),
                      if (item.isCollection)
                        _ResourceLabel(
                          label: AppLocalizations.of(
                            context,
                          )!.resourceCollection,
                          color: color.tertiary,
                        ),
                      if (item.paidType != CommunityPaidType.free)
                        _ResourceLabel(
                          label: _paidLabel(
                            AppLocalizations.of(context)!,
                            item.paidType,
                          ),
                          color: color.tertiary,
                        ),
                      if (item.ref.source == CommunitySourceId.bandbbs ||
                          item.ref.source == CommunitySourceId.oronBox)
                        ...item.tags
                            .take(2)
                            .map(
                              (tag) => _ResourceLabel(
                                label:
                                    item.ref.source == CommunitySourceId.oronBox
                                    ? attributeLabels[tag] ?? tag
                                    : tag,
                                color: color.onSurfaceVariant,
                              ),
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

class _ResourceLabel extends StatelessWidget {
  const _ResourceLabel({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(StyleConstants.chipRadius),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _paidLabel(AppLocalizations l10n, CommunityPaidType type) =>
    switch (type) {
      CommunityPaidType.free => l10n.free,
      CommunityPaidType.paid => l10n.paid,
      CommunityPaidType.forcePaid => l10n.forcePaid,
    };
