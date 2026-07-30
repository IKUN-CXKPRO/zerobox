import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/core/network/github_cdn.dart';

class SettingsService {
  GitHubCdn getPreferredCdn() => GitHubCdn.raw;

  Future<void> setPreferredCdn(GitHubCdn cdn) async {}
}

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});
