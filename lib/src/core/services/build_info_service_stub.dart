abstract final class BuildInfoService {
  static const appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0+1',
  );

  static const _definedCommit = String.fromEnvironment(
    'GIT_COMMIT_HASH',
    defaultValue: 'local',
  );

  static Future<String> resolveCommitHash() async => _definedCommit;
}
