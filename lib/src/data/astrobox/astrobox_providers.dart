import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/core/providers/app_settings_providers.dart';
import 'package:zerobox/src/data/astrobox/astrobox_cdn.dart';
import 'package:zerobox/src/data/astrobox/astrobox_community_repository.dart';
import 'package:zerobox/src/data/astrobox/models/astrobox_models.dart';

final astroBoxCdnProvider = Provider<AstroBoxCdn>((ref) {
  return ref.watch(appSettingsProvider).cdn;
});

final astroBoxRepositoryProvider = Provider<AstroBoxCommunityRepository>((ref) {
  final cdn = ref.watch(astroBoxCdnProvider);
  return AstroBoxCommunityRepository(cdn: cdn);
});

final astroBoxIndexProvider =
    FutureProvider.autoDispose<List<AstroBoxIndexItem>>((ref) async {
  final repo = ref.watch(astroBoxRepositoryProvider);
  return repo.fetchIndex();
});

final astroBoxDeviceMapProvider =
    FutureProvider.autoDispose<AstroBoxDeviceMap>((ref) async {
  final repo = ref.watch(astroBoxRepositoryProvider);
  return repo.fetchDeviceMap();
});

final astroBoxManifestProvider = FutureProvider.autoDispose
    .family<AstroBoxManifest?, AstroBoxIndexItem>((ref, item) async {
  final repo = ref.watch(astroBoxRepositoryProvider);
  return repo.fetchManifest(item);
});
