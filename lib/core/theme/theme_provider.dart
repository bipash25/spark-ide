import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spark_ide/core/theme/spark_theme.dart';
import 'package:spark_ide/providers/settings_provider.dart';

/// Available theme definitions with their asset paths.
class ThemeEntry {
  final String id;
  final String name;
  final String assetPath;
  final bool isDark;
  final Color previewBackground;
  final Color previewAccent;

  const ThemeEntry({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.isDark,
    required this.previewBackground,
    required this.previewAccent,
  });
}

/// All available themes.
const List<ThemeEntry> availableThemes = [
  ThemeEntry(
    id: 'spark_dark',
    name: 'Spark Dark',
    assetPath: 'assets/themes/spark_dark.json',
    isDark: true,
    previewBackground: Color(0xFF1E1E2E),
    previewAccent: Color(0xFF89B4FA),
  ),
  ThemeEntry(
    id: 'spark_light',
    name: 'Spark Light',
    assetPath: 'assets/themes/spark_light.json',
    isDark: false,
    previewBackground: Color(0xFFEFF1F5),
    previewAccent: Color(0xFF1E66F5),
  ),
  ThemeEntry(
    id: 'monokai',
    name: 'Monokai',
    assetPath: 'assets/themes/monokai.json',
    isDark: true,
    previewBackground: Color(0xFF272822),
    previewAccent: Color(0xFFA6E22E),
  ),
  ThemeEntry(
    id: 'dracula',
    name: 'Dracula',
    assetPath: 'assets/themes/dracula.json',
    isDark: true,
    previewBackground: Color(0xFF282A36),
    previewAccent: Color(0xFFBD93F9),
  ),
  ThemeEntry(
    id: 'one_dark',
    name: 'One Dark',
    assetPath: 'assets/themes/one_dark.json',
    isDark: true,
    previewBackground: Color(0xFF282C34),
    previewAccent: Color(0xFF61AFEF),
  ),
  ThemeEntry(
    id: 'solarized_dark',
    name: 'Solarized Dark',
    assetPath: 'assets/themes/solarized_dark.json',
    isDark: true,
    previewBackground: Color(0xFF002B36),
    previewAccent: Color(0xFF268BD2),
  ),
];

/// Theme mode notifier - manages dark/light theme switching
/// Now also tracks the selected theme by ID.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.dark);

  void setThemeMode(ThemeMode mode) {
    state = mode;
  }

  void toggleTheme() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

/// Tracks the selected theme ID with persistence.
class SelectedThemeNotifier extends StateNotifier<String> {
  final SharedPreferences _prefs;
  static const _key = 'selectedTheme';

  SelectedThemeNotifier(this._prefs)
      : super(_prefs.getString(_key) ?? 'spark_dark');

  void setTheme(String themeId) {
    state = themeId;
    _prefs.setString(_key, themeId);
  }
}

final selectedThemeProvider =
    StateNotifierProvider<SelectedThemeNotifier, String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SelectedThemeNotifier(prefs);
});

/// Resolves the asset path for the selected theme.
String _themeAssetPath(String themeId) {
  final entry = availableThemes.firstWhere(
    (t) => t.id == themeId,
    orElse: () => availableThemes.first,
  );
  return entry.assetPath;
}

/// Provides the current SparkTheme based on selected theme ID.
final sparkThemeProvider = FutureProvider<SparkTheme>((ref) async {
  final themeId = ref.watch(selectedThemeProvider);
  final path = _themeAssetPath(themeId);
  final theme = await SparkTheme.load(path);

  // Keep themeModeProvider in sync for compatibility
  final entry = availableThemes.firstWhere(
    (t) => t.id == themeId,
    orElse: () => availableThemes.first,
  );
  ref.read(themeModeProvider.notifier).setThemeMode(
        entry.isDark ? ThemeMode.dark : ThemeMode.light,
      );

  return theme;
});

/// Provides the current theme colors synchronously (with fallback)
final themeColorsProvider = Provider<ThemeColors>((ref) {
  final themeAsync = ref.watch(sparkThemeProvider);
  return themeAsync.when(
    data: (theme) => theme.colors,
    loading: () => _defaultDarkColors,
    error: (_, _) => _defaultDarkColors,
  );
});

/// Provides the current token colors synchronously (with fallback)
final tokenColorsProvider = Provider<TokenColors>((ref) {
  final themeAsync = ref.watch(sparkThemeProvider);
  return themeAsync.when(
    data: (theme) => theme.tokenColors,
    loading: () => _defaultTokenColors,
    error: (_, _) => _defaultTokenColors,
  );
});

// Default dark theme colors as fallback
const _defaultDarkColors = ThemeColors(
  background: Color(0xFF1E1E2E),
  foreground: Color(0xFFCDD6F4),
  surface: Color(0xFF181825),
  surfaceVariant: Color(0xFF1E1E2E),
  primary: Color(0xFF89B4FA),
  primaryVariant: Color(0xFF74C7EC),
  secondary: Color(0xFFA6E3A1),
  accent: Color(0xFFF5C2E7),
  error: Color(0xFFF38BA8),
  warning: Color(0xFFFAB387),
  info: Color(0xFF89DCEB),
  success: Color(0xFFA6E3A1),
  border: Color(0xFF313244),
  borderFocused: Color(0xFF89B4FA),
  sidebarBackground: Color(0xFF11111B),
  sidebarForeground: Color(0xFFBAC2DE),
  activityBarBackground: Color(0xFF11111B),
  activityBarForeground: Color(0xFFBAC2DE),
  activityBarActiveForeground: Color(0xFF89B4FA),
  editorBackground: Color(0xFF1E1E2E),
  editorForeground: Color(0xFFCDD6F4),
  editorLineHighlight: Color(0xFF2A2B3D),
  editorSelectionBackground: Color(0x8044475A),
  editorCursorColor: Color(0xFFF5E0DC),
  editorLineNumberForeground: Color(0xFF585B70),
  editorLineNumberActiveForeground: Color(0xFFCDD6F4),
  editorGutterBackground: Color(0xFF1E1E2E),
  tabBarBackground: Color(0xFF181825),
  tabActiveBackground: Color(0xFF1E1E2E),
  tabActiveForeground: Color(0xFFCDD6F4),
  tabInactiveForeground: Color(0xFF6C7086),
  tabActiveBorder: Color(0xFF89B4FA),
  statusBarBackground: Color(0xFF11111B),
  statusBarForeground: Color(0xFFBAC2DE),
  panelBackground: Color(0xFF181825),
  panelBorder: Color(0xFF313244),
  terminalBackground: Color(0xFF11111B),
  terminalForeground: Color(0xFFCDD6F4),
  inputBackground: Color(0xFF313244),
  inputForeground: Color(0xFFCDD6F4),
  inputBorder: Color(0xFF45475A),
  buttonBackground: Color(0xFF89B4FA),
  buttonForeground: Color(0xFF1E1E2E),
  buttonHoverBackground: Color(0xFF74C7EC),
  listHoverBackground: Color(0xFF2A2B3D),
  listActiveBackground: Color(0xFF313244),
  scrollbarThumb: Color(0x40585B70),
  scrollbarThumbHover: Color(0x80585B70),
  titleBarBackground: Color(0xFF11111B),
  titleBarForeground: Color(0xFFBAC2DE),
);

const _defaultTokenColors = TokenColors(
  keyword: Color(0xFFCBA6F7),
  string: Color(0xFFA6E3A1),
  number: Color(0xFFFAB387),
  comment: Color(0xFF6C7086),
  function: Color(0xFF89B4FA),
  variable: Color(0xFFCDD6F4),
  type: Color(0xFFF9E2AF),
  operator: Color(0xFF89DCEB),
  punctuation: Color(0xFFBAC2DE),
  tag: Color(0xFFF38BA8),
  attribute: Color(0xFFFAB387),
  property: Color(0xFF89DCEB),
  constant: Color(0xFFFAB387),
  regexp: Color(0xFFF5C2E7),
  parameter: Color(0xFFEBA0AC),
  decorator: Color(0xFFF5C2E7),
  namespace: Color(0xFFF9E2AF),
  builtin: Color(0xFFF38BA8),
  className: Color(0xFFF9E2AF),
  interfaceName: Color(0xFF74C7EC),
  enumName: Color(0xFFF9E2AF),
  structName: Color(0xFFF9E2AF),
  macro: Color(0xFFF5C2E7),
  label: Color(0xFF89DCEB),
);
