import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/core/services/shared_prefs_service.dart';

enum AppThemeMode { system, light, dark, oledDark }

class ThemeSettings {
  const ThemeSettings({
    required this.themeMode,
    required this.useDynamicColor,
  });

  final AppThemeMode themeMode;
  final bool useDynamicColor;

  ThemeSettings copyWith({AppThemeMode? themeMode, bool? useDynamicColor}) {
    return ThemeSettings(
      themeMode: themeMode ?? this.themeMode,
      useDynamicColor: useDynamicColor ?? this.useDynamicColor,
    );
  }

  static const String _keyThemeMode = 'app_theme_mode';
  static const String _keyDynamicColor = 'app_dynamic_color';

  static ThemeSettings load() {
    final prefs = SharedPrefsService.instance;
    final raw = prefs.getString(_keyThemeMode);
    return ThemeSettings(
      themeMode: AppThemeMode.values.byName(
        raw ?? AppThemeMode.system.name,
      ),
      useDynamicColor: prefs.getBool(_keyDynamicColor) ?? true,
    );
  }

  Future<void> save() async {
    final prefs = SharedPrefsService.instance;
    await prefs.setString(_keyThemeMode, themeMode.name);
    await prefs.setBool(_keyDynamicColor, useDynamicColor);
  }

  ThemeMode get materialThemeMode {
    return switch (themeMode) {
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark || AppThemeMode.oledDark => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  bool get isOledDark => themeMode == AppThemeMode.oledDark;
}

class ThemeSettingsNotifier extends Notifier<ThemeSettings> {
  @override
  ThemeSettings build() => ThemeSettings.load();

  Future<void> setThemeMode(AppThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await state.save();
  }

  Future<void> setDynamicColor(bool value) async {
    state = state.copyWith(useDynamicColor: value);
    await state.save();
  }
}

final themeSettingsProvider =
    NotifierProvider<ThemeSettingsNotifier, ThemeSettings>(ThemeSettingsNotifier.new);

enum AppLocale { system, en, zh }

class LocaleSettings {
  const LocaleSettings({required this.locale});

  final AppLocale locale;

  LocaleSettings copyWith({AppLocale? locale}) {
    return LocaleSettings(locale: locale ?? this.locale);
  }

  static const String _keyLocale = 'app_locale';

  static LocaleSettings load() {
    final prefs = SharedPrefsService.instance;
    final raw = prefs.getString(_keyLocale);
    return LocaleSettings(
      locale: AppLocale.values.byName(raw ?? AppLocale.system.name),
    );
  }

  Future<void> save() async {
    await SharedPrefsService.instance.setString(_keyLocale, locale.name);
  }

  Locale? get materialLocale {
    return switch (locale) {
      AppLocale.en => const Locale('en'),
      AppLocale.zh => const Locale('zh'),
      _ => null,
    };
  }
}

class LocaleSettingsNotifier extends Notifier<LocaleSettings> {
  @override
  LocaleSettings build() => LocaleSettings.load();

  Future<void> setLocale(AppLocale locale) async {
    state = state.copyWith(locale: locale);
    await state.save();
  }
}

final localeSettingsProvider =
    NotifierProvider<LocaleSettingsNotifier, LocaleSettings>(LocaleSettingsNotifier.new);
