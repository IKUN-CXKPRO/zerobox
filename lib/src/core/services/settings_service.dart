import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/data/astrobox/astrobox_cdn.dart';

class SettingsService {
  AstroBoxCdn getPreferredCdn() => AstroBoxCdn.raw;

  Future<void> setPreferredCdn(AstroBoxCdn cdn) async {}
}

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});
