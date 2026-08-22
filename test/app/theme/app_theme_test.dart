import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/app/theme/app_theme.dart';

void main() {
  test('Windows theme provides explicit CJK system font fallbacks', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final theme = AppTheme.buildLightTheme();

    expect(theme.textTheme.bodyMedium?.fontFamilyFallback, [
      'Microsoft YaHei UI',
      'Microsoft JhengHei UI',
      'Yu Gothic UI',
      'Malgun Gothic',
    ]);
  });
}
