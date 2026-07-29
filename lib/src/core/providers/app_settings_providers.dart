import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/data/astrobox/astrobox_cdn.dart';
import 'package:oronbox/src/data/community/community_source.dart';
import 'package:oronbox/src/host/application_host_provider.dart';

enum WideNavigationRailPosition { bottom, center, split }

class CleanSettings {
  const CleanSettings({
    this.exploreEntry = true,
    this.pluginsEntry = true,
    this.homeFeed = true,
    this.explore = true,
    this.inbox = true,
    this.announcements = true,
    this.comments = true,
    this.creator = true,
    this.bandBbsLogin = true,
    this.githubLogin = true,
    this.oronBox = true,
    this.bandBbs = true,
    this.astroBox = true,
    this.huamiAppStore = true,
  });
  final bool exploreEntry,
      pluginsEntry,
      homeFeed,
      explore,
      inbox,
      announcements,
      comments,
      creator,
      bandBbsLogin,
      githubLogin,
      oronBox,
      bandBbs,
      astroBox,
      huamiAppStore;
  bool get exploreEnabled => exploreEntry;
  bool get pluginsEnabled => pluginsEntry;
  bool get homeFeedEnabled => exploreEnabled && homeFeed;
  bool get resourceLibraryEnabled => exploreEnabled && explore;
  bool get inboxEnabled => exploreEnabled && inbox;
  bool get creatorEnabled => exploreEnabled && creator;
  bool get commentsEnabled => resourceLibraryEnabled && comments;
  bool get oronBoxSourceEnabled => resourceLibraryEnabled && oronBox;
  bool get bandBbsSourceEnabled => resourceLibraryEnabled && bandBbs;
  bool get astroBoxSourceEnabled => resourceLibraryEnabled && astroBox;
  bool get huamiAppStoreSourceEnabled =>
      resourceLibraryEnabled && huamiAppStore;
  bool get bandBbsLoginEnabled => bandBbsLogin;
  bool get githubLoginEnabled => bandBbsLoginEnabled && githubLogin;
  bool get announcementsEnabled => announcements;
  bool get hasResourceSource =>
      oronBoxSourceEnabled ||
      bandBbsSourceEnabled ||
      astroBoxSourceEnabled ||
      huamiAppStoreSourceEnabled;

  CleanSettings get normalized => this;

  CleanSettings copyWith({
    bool? exploreEntry,
    bool? pluginsEntry,
    bool? homeFeed,
    bool? explore,
    bool? inbox,
    bool? announcements,
    bool? comments,
    bool? creator,
    bool? bandBbsLogin,
    bool? githubLogin,
    bool? oronBox,
    bool? bandBbs,
    bool? astroBox,
    bool? huamiAppStore,
  }) => CleanSettings(
    exploreEntry: exploreEntry ?? this.exploreEntry,
    pluginsEntry: pluginsEntry ?? this.pluginsEntry,
    homeFeed: homeFeed ?? this.homeFeed,
    explore: explore ?? this.explore,
    inbox: inbox ?? this.inbox,
    announcements: announcements ?? this.announcements,
    comments: comments ?? this.comments,
    creator: creator ?? this.creator,
    bandBbsLogin: bandBbsLogin ?? this.bandBbsLogin,
    githubLogin: githubLogin ?? this.githubLogin,
    oronBox: oronBox ?? this.oronBox,
    bandBbs: bandBbs ?? this.bandBbs,
    astroBox: astroBox ?? this.astroBox,
    huamiAppStore: huamiAppStore ?? this.huamiAppStore,
  );
}

class AppSettings {
  const AppSettings({
    required this.cdn,
    required this.communitySource,
    required this.autoInstall,
    required this.disableAutoClean,
    required this.autoReconnect,
    required this.wideNavigationRailPosition,
    required this.bandbbsLoadPreviews,
    required this.bandbbsShowAllCategories,
    this.clean = const CleanSettings(),
  });

  final AstroBoxCdn cdn;
  final CommunitySourceId communitySource;
  final bool autoInstall;
  final bool disableAutoClean;
  final bool autoReconnect;
  final WideNavigationRailPosition wideNavigationRailPosition;
  final bool bandbbsLoadPreviews;
  final bool bandbbsShowAllCategories;
  final CleanSettings clean;

  AppSettings copyWith({
    AstroBoxCdn? cdn,
    CommunitySourceId? communitySource,
    bool? autoInstall,
    bool? disableAutoClean,
    bool? autoReconnect,
    WideNavigationRailPosition? wideNavigationRailPosition,
    bool? bandbbsLoadPreviews,
    bool? bandbbsShowAllCategories,
    CleanSettings? clean,
  }) {
    return AppSettings(
      cdn: cdn ?? this.cdn,
      communitySource: communitySource ?? this.communitySource,
      autoInstall: autoInstall ?? this.autoInstall,
      disableAutoClean: disableAutoClean ?? this.disableAutoClean,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      wideNavigationRailPosition:
          wideNavigationRailPosition ?? this.wideNavigationRailPosition,
      bandbbsLoadPreviews: bandbbsLoadPreviews ?? this.bandbbsLoadPreviews,
      bandbbsShowAllCategories:
          bandbbsShowAllCategories ?? this.bandbbsShowAllCategories,
      clean: clean ?? this.clean,
    );
  }

  static const String _keyCdn = 'astrobox_cdn';
  static const String _keyCommunitySource = 'community_source';
  static const String _keyAutoInstall = 'auto_install';
  static const String _keyDisableAutoClean = 'disable_auto_clean';
  static const String _keyAutoReconnect = 'auto_reconnect';
  static const String _keyWideNavigationRailPosition =
      'wide_navigation_rail_position';
  static const String _keyBandBbsLoadPreviews = 'bandbbs_load_previews';
  static const String _keyBandBbsShowAllCategories =
      'bandbbs_show_all_categories';

  static AppSettings load() {
    final prefs = SharedPrefsService.instance;
    final cdnRaw = prefs.getString(_keyCdn);
    final sourceRaw = prefs.getString(_keyCommunitySource);
    final railPositionRaw = prefs.getString(_keyWideNavigationRailPosition);
    return AppSettings(
      cdn: astroBoxCdnByName(cdnRaw ?? '') ?? AstroBoxCdn.raw,
      communitySource:
          communitySourceIdByName(sourceRaw ?? '') ??
          CommunitySourceId.astroboxRepo,
      autoInstall: prefs.getBool(_keyAutoInstall) ?? true,
      disableAutoClean: prefs.getBool(_keyDisableAutoClean) ?? false,
      autoReconnect: prefs.getBool(_keyAutoReconnect) ?? false,
      wideNavigationRailPosition: _enumByName(
        WideNavigationRailPosition.values,
        railPositionRaw,
        WideNavigationRailPosition.bottom,
      ),
      bandbbsLoadPreviews: prefs.getBool(_keyBandBbsLoadPreviews) ?? false,
      bandbbsShowAllCategories:
          prefs.getBool(_keyBandBbsShowAllCategories) ?? false,
      clean: CleanSettings(
        exploreEntry: prefs.getBool('clean_explore_entry') ?? true,
        pluginsEntry: prefs.getBool('clean_plugins_entry') ?? true,
        homeFeed: prefs.getBool('clean_home_feed') ?? true,
        explore: prefs.getBool('clean_explore') ?? true,
        inbox: prefs.getBool('clean_inbox') ?? true,
        announcements: prefs.getBool('clean_announcements') ?? true,
        comments: prefs.getBool('clean_comments') ?? true,
        creator: prefs.getBool('clean_creator') ?? true,
        bandBbsLogin: prefs.getBool('clean_bandbbs_login') ?? true,
        githubLogin: prefs.getBool('clean_github_login') ?? true,
        oronBox: prefs.getBool('clean_source_oronbox') ?? true,
        bandBbs: prefs.getBool('clean_source_bandbbs') ?? true,
        astroBox: prefs.getBool('clean_source_astrobox') ?? true,
        huamiAppStore: prefs.getBool('clean_source_huami_app_store') ?? true,
      ),
    );
  }

  static const defaults = AppSettings(
    cdn: AstroBoxCdn.raw,
    communitySource: CommunitySourceId.astroboxRepo,
    autoInstall: true,
    disableAutoClean: false,
    autoReconnect: false,
    wideNavigationRailPosition: WideNavigationRailPosition.bottom,
    bandbbsLoadPreviews: false,
    bandbbsShowAllCategories: false,
  );

  Future<void> save() async {
    final prefs = SharedPrefsService.instance;
    await prefs.setString(_keyCdn, cdn.name);
    await prefs.setString(_keyCommunitySource, communitySource.storageKey);
    await prefs.setBool(_keyAutoInstall, autoInstall);
    await prefs.setBool(_keyDisableAutoClean, disableAutoClean);
    await prefs.setBool(_keyAutoReconnect, autoReconnect);
    await prefs.setString(
      _keyWideNavigationRailPosition,
      wideNavigationRailPosition.name,
    );
    await prefs.setBool(_keyBandBbsLoadPreviews, bandbbsLoadPreviews);
    await prefs.setBool(_keyBandBbsShowAllCategories, bandbbsShowAllCategories);
    await prefs.setBool('clean_explore_entry', clean.exploreEntry);
    await prefs.setBool('clean_plugins_entry', clean.pluginsEntry);
    await prefs.setBool('clean_home_feed', clean.homeFeed);
    await prefs.setBool('clean_explore', clean.explore);
    await prefs.setBool('clean_inbox', clean.inbox);
    await prefs.setBool('clean_announcements', clean.announcements);
    await prefs.setBool('clean_comments', clean.comments);
    await prefs.setBool('clean_creator', clean.creator);
    await prefs.setBool('clean_bandbbs_login', clean.bandBbsLogin);
    await prefs.setBool('clean_github_login', clean.githubLogin);
    await prefs.setBool('clean_source_oronbox', clean.oronBox);
    await prefs.setBool('clean_source_bandbbs', clean.bandBbs);
    await prefs.setBool('clean_source_astrobox', clean.astroBox);
    await prefs.setBool('clean_source_huami_app_store', clean.huamiAppStore);
  }

  static T _enumByName<T extends Enum>(
    Iterable<T> values,
    String? name,
    T fallback,
  ) {
    if (name == null) return fallback;
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }
}

abstract class AppSettingsNotifier extends Notifier<AppSettings> {
  Future<void> setCdn(AstroBoxCdn cdn);
  Future<void> setCommunitySource(CommunitySourceId source);
  Future<void> setAutoInstall(bool value);
  Future<void> setDisableAutoClean(bool value);
  Future<void> setAutoReconnect(bool value);
  Future<void> setWideNavigationRailPosition(WideNavigationRailPosition value);
  Future<void> setBandBbsLoadPreviews(bool value);
  Future<void> setBandBbsShowAllCategories(bool value);
  Future<void> setClean(CleanSettings value);
}

class LocalAppSettingsNotifier extends AppSettingsNotifier {
  @override
  AppSettings build() => AppSettings.load();

  @override
  Future<void> setCdn(AstroBoxCdn cdn) async {
    state = state.copyWith(cdn: cdn);
    await state.save();
  }

  @override
  Future<void> setCommunitySource(CommunitySourceId source) async {
    state = state.copyWith(communitySource: source);
    await state.save();
  }

  @override
  Future<void> setAutoInstall(bool value) async {
    state = state.copyWith(autoInstall: value);
    await state.save();
  }

  @override
  Future<void> setDisableAutoClean(bool value) async {
    state = state.copyWith(disableAutoClean: value);
    await state.save();
  }

  @override
  Future<void> setAutoReconnect(bool value) async {
    state = state.copyWith(autoReconnect: value);
    await state.save();
  }

  @override
  Future<void> setWideNavigationRailPosition(
    WideNavigationRailPosition value,
  ) async {
    state = state.copyWith(wideNavigationRailPosition: value);
    await state.save();
  }

  @override
  Future<void> setBandBbsLoadPreviews(bool value) async {
    state = state.copyWith(bandbbsLoadPreviews: value);
    await state.save();
  }

  @override
  Future<void> setBandBbsShowAllCategories(bool value) async {
    state = state.copyWith(bandbbsShowAllCategories: value);
    await state.save();
  }

  @override
  Future<void> setClean(CleanSettings value) async {
    state = state.copyWith(clean: value.normalized);
    await state.save();
  }
}

class HostAppSettingsNotifier extends AppSettingsNotifier {
  StreamSubscription<CommandEvent>? _subscription;

  @override
  AppSettings build() {
    _subscription = ref.watch(applicationHostProvider).events.listen((event) {
      if (event.event == 'settings.state' || event.event == 'host.connected') {
        unawaited(refresh());
      }
    });
    ref.onDispose(() => unawaited(_subscription?.cancel()));
    Future.microtask(refresh);
    return AppSettings.load();
  }

  Future<void> refresh() async {
    final result = await ref
        .read(applicationHostProvider)
        .execute(const OronBoxCommand(method: 'settings.list'));
    if (!result.ok) return;
    final json = (result.value as Map).cast<String, Object?>();
    state = AppSettings(
      cdn:
          astroBoxCdnByName(json['astrobox_cdn']?.toString() ?? '') ??
          AstroBoxCdn.raw,
      communitySource:
          communitySourceIdByName(json['community_source']?.toString() ?? '') ??
          CommunitySourceId.astroboxRepo,
      autoInstall: json['auto_install'] as bool? ?? true,
      disableAutoClean: json['disable_auto_clean'] as bool? ?? false,
      autoReconnect: json['auto_reconnect'] as bool? ?? false,
      wideNavigationRailPosition: state.wideNavigationRailPosition,
      bandbbsLoadPreviews: json['bandbbs_load_previews'] as bool? ?? false,
      bandbbsShowAllCategories:
          json['bandbbs_show_all_categories'] as bool? ?? false,
      clean: state.clean,
    );
  }

  Future<void> _set(String key, Object value, AppSettings next) async {
    final result = await ref
        .read(applicationHostProvider)
        .execute(
          OronBoxCommand(
            method: 'settings.set',
            params: {'key': key, 'value': value},
          ),
        );
    if (!result.ok) {
      throw StateError('${result.error!.code}: ${result.error!.message}');
    }
    state = next;
  }

  @override
  Future<void> setCdn(AstroBoxCdn cdn) =>
      _set('astrobox_cdn', cdn.name, state.copyWith(cdn: cdn));
  @override
  Future<void> setCommunitySource(CommunitySourceId source) => _set(
    'community_source',
    source.storageKey,
    state.copyWith(communitySource: source),
  );
  @override
  Future<void> setAutoInstall(bool value) =>
      _set('auto_install', value, state.copyWith(autoInstall: value));
  @override
  Future<void> setDisableAutoClean(bool value) => _set(
    'disable_auto_clean',
    value,
    state.copyWith(disableAutoClean: value),
  );
  @override
  Future<void> setAutoReconnect(bool value) =>
      _set('auto_reconnect', value, state.copyWith(autoReconnect: value));
  @override
  Future<void> setWideNavigationRailPosition(
    WideNavigationRailPosition value,
  ) async {
    state = state.copyWith(wideNavigationRailPosition: value);
    await SharedPrefsService.instance.setString(
      AppSettings._keyWideNavigationRailPosition,
      value.name,
    );
  }

  @override
  Future<void> setBandBbsLoadPreviews(bool value) => _set(
    'bandbbs_load_previews',
    value,
    state.copyWith(bandbbsLoadPreviews: value),
  );
  @override
  Future<void> setBandBbsShowAllCategories(bool value) => _set(
    'bandbbs_show_all_categories',
    value,
    state.copyWith(bandbbsShowAllCategories: value),
  );
  @override
  Future<void> setClean(CleanSettings value) async {
    state = state.copyWith(clean: value.normalized);
    await state.save();
  }
}

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(
  LocalAppSettingsNotifier.new,
);
