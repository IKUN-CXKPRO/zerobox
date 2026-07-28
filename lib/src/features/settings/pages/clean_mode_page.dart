import 'package:segmented_list/segmented_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/app/widgets/huami_brand_icon.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/core/providers/app_settings_providers.dart';

class CleanModePage extends ConsumerWidget {
  const CleanModePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final value = ref.watch(appSettingsProvider).clean;
    final notifier = ref.read(appSettingsProvider.notifier);

    Future<void> update(CleanSettings next) => notifier.setClean(next);
    final exploreOn = value.exploreEnabled;
    final libraryOn = value.resourceLibraryEnabled;
    final bandBbsOn = value.bandBbsLoginEnabled;

    return Scaffold(
      appBar: SysAppBar(secondary: true, title: Text(l10n.cleanMode)),
      body: SegmentedList(
        maxWidth: StyleConstants.pageMaxWidth,
        contentPadding: const EdgeInsets.symmetric(
          vertical: StyleConstants.pagePadding,
        ),
        sections: [
          SegmentedSection(
            title: Text(l10n.cleanNavigationGroup),
            tiles: [
              _switch(
                l10n.cleanExploreEntry,
                value.exploreEntry,
                (enabled) {
                  var next = value.copyWith(exploreEntry: enabled);
                  if (enabled && !value.homeFeed && !value.explore) {
                    next = next.copyWith(explore: true);
                  }
                  update(next);
                },
                icon: Icons.apps_outlined,
              ),
              _switch(
                l10n.cleanPluginsEntry,
                value.pluginsEntry,
                (enabled) => update(value.copyWith(pluginsEntry: enabled)),
                icon: Icons.extension_outlined,
              ),
            ],
          ),
          SegmentedSection(
            title: Text(l10n.cleanExploreContentGroup),
            tiles: [
              _switch(
                l10n.cleanHomeFeed,
                exploreOn && value.homeFeed,
                (enabled) => update(value.copyWith(homeFeed: enabled)),
                enabled: exploreOn && (!value.homeFeed || value.explore),
                icon: Icons.home_outlined,
              ),
              _switch(
                l10n.cleanExplore,
                exploreOn && value.explore,
                (enabled) => update(value.copyWith(explore: enabled)),
                enabled: exploreOn && (!value.explore || value.homeFeed),
                icon: Icons.library_books_outlined,
              ),
              _switch(
                l10n.cleanCreator,
                exploreOn && value.creator,
                (enabled) => update(value.copyWith(creator: enabled)),
                enabled: exploreOn,
                icon: Icons.create_outlined,
              ),
              _switch(
                l10n.cleanInbox,
                exploreOn && value.inbox,
                (enabled) => update(value.copyWith(inbox: enabled)),
                enabled: exploreOn,
                icon: Icons.notifications_outlined,
              ),
              _switch(
                l10n.cleanComments,
                libraryOn && value.comments,
                (enabled) => update(value.copyWith(comments: enabled)),
                enabled: libraryOn,
                icon: Icons.forum_outlined,
              ),
            ],
          ),
          SegmentedSection(
            title: Text(l10n.cleanResourceSourcesGroup),
            tiles: [
              _sourceSwitch(
                l10n.cleanSourceOronBox,
                value.oronBox,
                libraryOn,
                value.bandBbs || value.astroBox || value.huamiAppStore,
                (enabled) => update(value.copyWith(oronBox: enabled)),
                brandAsset: 'assets/images/brands/oronbox.svg',
                brandLabel: 'OronBox',
              ),
              _sourceSwitch(
                l10n.cleanSourceBandBbs,
                value.bandBbs,
                libraryOn,
                value.oronBox || value.astroBox || value.huamiAppStore,
                (enabled) => update(value.copyWith(bandBbs: enabled)),
                brandAsset: 'assets/images/brands/bandbbs.svg',
                brandLabel: 'BandBBS',
              ),
              _sourceSwitch(
                l10n.cleanSourceAstroBox,
                value.astroBox,
                libraryOn,
                value.oronBox || value.bandBbs || value.huamiAppStore,
                (enabled) => update(value.copyWith(astroBox: enabled)),
                brandAsset: 'assets/images/brands/astrobox.svg',
                brandLabel: 'AstroBox',
              ),
              _sourceSwitch(
                l10n.cleanSourceHuamiAppStore,
                value.huamiAppStore,
                libraryOn,
                value.oronBox || value.bandBbs || value.astroBox,
                (enabled) => update(value.copyWith(huamiAppStore: enabled)),
                brandLabel: 'Amazfit',
                leading: const HuamiBrandIcon(),
              ),
            ],
          ),
          SegmentedSection(
            title: Text(l10n.cleanCommunityGroup),
            tiles: [
              _switch(
                l10n.cleanAnnouncements,
                value.announcements,
                (enabled) => update(value.copyWith(announcements: enabled)),
                icon: Icons.campaign_outlined,
              ),
              _switch(
                l10n.cleanBandBbsLogin,
                value.bandBbsLogin,
                (enabled) => update(value.copyWith(bandBbsLogin: enabled)),
                icon: Icons.login,
              ),
              _switch(
                l10n.cleanGitHubLogin,
                bandBbsOn && value.githubLogin,
                (enabled) => update(value.copyWith(githubLogin: enabled)),
                enabled: bandBbsOn,
                icon: Icons.code,
              ),
            ],
          ),
        ],
      ),
    );
  }

  AbstractSegmentedTile _sourceSwitch(
    String title,
    bool storedValue,
    bool libraryOn,
    bool anotherSourceOn,
    ValueChanged<bool> onChanged, {
    String? brandAsset,
    required String brandLabel,
    Widget? leading,
  }) => _switch(
    title,
    libraryOn && storedValue,
    onChanged,
    enabled: libraryOn && (!storedValue || anotherSourceOn),
    leading: leading ?? _SourceBrandIcon(asset: brandAsset, label: brandLabel),
  );

  AbstractSegmentedTile _switch(
    String title,
    bool value,
    ValueChanged<bool> onChanged, {
    bool enabled = true,
    IconData? icon,
    Widget? leading,
  }) => SegmentedTile.switchTile(
    onToggle: enabled ? (next) => onChanged(next ?? false) : null,
    initialValue: value,
    leading: leading ?? Icon(icon),
    title: Text(title),
  );
}

class _SourceBrandIcon extends StatelessWidget {
  const _SourceBrandIcon({this.asset, required this.label});

  final String? asset;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return SizedBox.square(
      dimension: 24,
      child: asset == null
          ? Center(
              child: Text(
                'A',
                semanticsLabel: label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  fontSize: 19,
                ),
              ),
            )
          : SvgPicture.asset(
              asset!,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              semanticsLabel: label,
            ),
    );
  }
}
