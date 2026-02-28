import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Represents a parsed IDE theme with all color tokens
class SparkTheme {
  final String name;
  final bool isDark;
  final ThemeColors colors;
  final TokenColors tokenColors;

  const SparkTheme({
    required this.name,
    required this.isDark,
    required this.colors,
    required this.tokenColors,
  });

  factory SparkTheme.fromJson(Map<String, dynamic> json) {
    return SparkTheme(
      name: json['name'] as String,
      isDark: json['type'] == 'dark',
      colors: ThemeColors.fromJson(json['colors'] as Map<String, dynamic>),
      tokenColors:
          TokenColors.fromJson(json['tokenColors'] as Map<String, dynamic>),
    );
  }

  static Future<SparkTheme> load(String assetPath) async {
    final jsonStr = await rootBundle.loadString(assetPath);
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return SparkTheme.fromJson(json);
  }

  ThemeData toFlutterTheme() {
    final colorScheme = ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: colors.primary,
      onPrimary: isDark ? Colors.black : Colors.white,
      secondary: colors.secondary,
      onSecondary: isDark ? Colors.black : Colors.white,
      error: colors.error,
      onError: isDark ? Colors.black : Colors.white,
      surface: colors.surface,
      onSurface: colors.foreground,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.background,
      fontFamily: 'JetBrainsMono',
      textTheme: TextTheme(
        bodySmall: TextStyle(
          fontSize: 11,
          color: colors.foreground,
          fontFamily: 'JetBrainsMono',
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          color: colors.foreground,
          fontFamily: 'JetBrainsMono',
        ),
        bodyLarge: TextStyle(
          fontSize: 14,
          color: colors.foreground,
          fontFamily: 'JetBrainsMono',
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          color: colors.foreground.withValues(alpha: 0.7),
          fontFamily: 'JetBrainsMono',
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          color: colors.foreground,
          fontFamily: 'JetBrainsMono',
        ),
        titleSmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: colors.foreground,
          fontFamily: 'JetBrainsMono',
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: colors.foreground,
          fontFamily: 'JetBrainsMono',
        ),
      ),
      iconTheme: IconThemeData(
        color: colors.foreground.withValues(alpha: 0.8),
        size: 20,
      ),
      dividerColor: colors.border,
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
        space: 1,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(colors.scrollbarThumb),
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(3),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: colors.border),
        ),
        textStyle: TextStyle(
          color: colors.foreground,
          fontSize: 12,
          fontFamily: 'JetBrainsMono',
        ),
      ),
    );
  }
}

/// All UI color tokens for the IDE
class ThemeColors {
  final Color background;
  final Color foreground;
  final Color surface;
  final Color surfaceVariant;
  final Color primary;
  final Color primaryVariant;
  final Color secondary;
  final Color accent;
  final Color error;
  final Color warning;
  final Color info;
  final Color success;
  final Color border;
  final Color borderFocused;

  // Sidebar
  final Color sidebarBackground;
  final Color sidebarForeground;

  // Activity bar
  final Color activityBarBackground;
  final Color activityBarForeground;
  final Color activityBarActiveForeground;

  // Editor
  final Color editorBackground;
  final Color editorForeground;
  final Color editorLineHighlight;
  final Color editorSelectionBackground;
  final Color editorCursorColor;
  final Color editorLineNumberForeground;
  final Color editorLineNumberActiveForeground;
  final Color editorGutterBackground;

  // Tabs
  final Color tabBarBackground;
  final Color tabActiveBackground;
  final Color tabActiveForeground;
  final Color tabInactiveForeground;
  final Color tabActiveBorder;

  // Status bar
  final Color statusBarBackground;
  final Color statusBarForeground;

  // Panel
  final Color panelBackground;
  final Color panelBorder;

  // Terminal
  final Color terminalBackground;
  final Color terminalForeground;

  // Input
  final Color inputBackground;
  final Color inputForeground;
  final Color inputBorder;

  // Buttons
  final Color buttonBackground;
  final Color buttonForeground;
  final Color buttonHoverBackground;

  // Lists
  final Color listHoverBackground;
  final Color listActiveBackground;

  // Scrollbar
  final Color scrollbarThumb;
  final Color scrollbarThumbHover;

  // Title bar
  final Color titleBarBackground;
  final Color titleBarForeground;

  const ThemeColors({
    required this.background,
    required this.foreground,
    required this.surface,
    required this.surfaceVariant,
    required this.primary,
    required this.primaryVariant,
    required this.secondary,
    required this.accent,
    required this.error,
    required this.warning,
    required this.info,
    required this.success,
    required this.border,
    required this.borderFocused,
    required this.sidebarBackground,
    required this.sidebarForeground,
    required this.activityBarBackground,
    required this.activityBarForeground,
    required this.activityBarActiveForeground,
    required this.editorBackground,
    required this.editorForeground,
    required this.editorLineHighlight,
    required this.editorSelectionBackground,
    required this.editorCursorColor,
    required this.editorLineNumberForeground,
    required this.editorLineNumberActiveForeground,
    required this.editorGutterBackground,
    required this.tabBarBackground,
    required this.tabActiveBackground,
    required this.tabActiveForeground,
    required this.tabInactiveForeground,
    required this.tabActiveBorder,
    required this.statusBarBackground,
    required this.statusBarForeground,
    required this.panelBackground,
    required this.panelBorder,
    required this.terminalBackground,
    required this.terminalForeground,
    required this.inputBackground,
    required this.inputForeground,
    required this.inputBorder,
    required this.buttonBackground,
    required this.buttonForeground,
    required this.buttonHoverBackground,
    required this.listHoverBackground,
    required this.listActiveBackground,
    required this.scrollbarThumb,
    required this.scrollbarThumbHover,
    required this.titleBarBackground,
    required this.titleBarForeground,
  });

  factory ThemeColors.fromJson(Map<String, dynamic> json) {
    return ThemeColors(
      background: _parseColor(json['background']),
      foreground: _parseColor(json['foreground']),
      surface: _parseColor(json['surface']),
      surfaceVariant: _parseColor(json['surfaceVariant']),
      primary: _parseColor(json['primary']),
      primaryVariant: _parseColor(json['primaryVariant']),
      secondary: _parseColor(json['secondary']),
      accent: _parseColor(json['accent']),
      error: _parseColor(json['error']),
      warning: _parseColor(json['warning']),
      info: _parseColor(json['info']),
      success: _parseColor(json['success']),
      border: _parseColor(json['border']),
      borderFocused: _parseColor(json['borderFocused']),
      sidebarBackground: _parseColor(json['sidebarBackground']),
      sidebarForeground: _parseColor(json['sidebarForeground']),
      activityBarBackground: _parseColor(json['activityBarBackground']),
      activityBarForeground: _parseColor(json['activityBarForeground']),
      activityBarActiveForeground:
          _parseColor(json['activityBarActiveForeground']),
      editorBackground: _parseColor(json['editorBackground']),
      editorForeground: _parseColor(json['editorForeground']),
      editorLineHighlight: _parseColor(json['editorLineHighlight']),
      editorSelectionBackground:
          _parseColor(json['editorSelectionBackground']),
      editorCursorColor: _parseColor(json['editorCursorColor']),
      editorLineNumberForeground:
          _parseColor(json['editorLineNumberForeground']),
      editorLineNumberActiveForeground:
          _parseColor(json['editorLineNumberActiveForeground']),
      editorGutterBackground: _parseColor(json['editorGutterBackground']),
      tabBarBackground: _parseColor(json['tabBarBackground']),
      tabActiveBackground: _parseColor(json['tabActiveBackground']),
      tabActiveForeground: _parseColor(json['tabActiveForeground']),
      tabInactiveForeground: _parseColor(json['tabInactiveForeground']),
      tabActiveBorder: _parseColor(json['tabActiveBorder']),
      statusBarBackground: _parseColor(json['statusBarBackground']),
      statusBarForeground: _parseColor(json['statusBarForeground']),
      panelBackground: _parseColor(json['panelBackground']),
      panelBorder: _parseColor(json['panelBorder']),
      terminalBackground: _parseColor(json['terminalBackground']),
      terminalForeground: _parseColor(json['terminalForeground']),
      inputBackground: _parseColor(json['inputBackground']),
      inputForeground: _parseColor(json['inputForeground']),
      inputBorder: _parseColor(json['inputBorder']),
      buttonBackground: _parseColor(json['buttonBackground']),
      buttonForeground: _parseColor(json['buttonForeground']),
      buttonHoverBackground: _parseColor(json['buttonHoverBackground']),
      listHoverBackground: _parseColor(json['listHoverBackground']),
      listActiveBackground: _parseColor(json['listActiveBackground']),
      scrollbarThumb: _parseColor(json['scrollbarThumb']),
      scrollbarThumbHover: _parseColor(json['scrollbarThumbHover']),
      titleBarBackground: _parseColor(json['titleBarBackground']),
      titleBarForeground: _parseColor(json['titleBarForeground']),
    );
  }

  static Color _parseColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    } else if (hex.length == 8) {
      // Keep as-is (RRGGBBAA -> need to convert to AARRGGBB)
      final alpha = hex.substring(6, 8);
      hex = '$alpha${hex.substring(0, 6)}';
    }
    return Color(int.parse(hex, radix: 16));
  }
}

/// Syntax highlighting token colors
class TokenColors {
  final Color keyword;
  final Color string;
  final Color number;
  final Color comment;
  final Color function;
  final Color variable;
  final Color type;
  final Color operator;
  final Color punctuation;
  final Color tag;
  final Color attribute;
  final Color property;
  final Color constant;
  final Color regexp;
  final Color parameter;
  final Color decorator;
  final Color namespace;
  final Color builtin;
  final Color className;
  final Color interfaceName;
  final Color enumName;
  final Color structName;
  final Color macro;
  final Color label;

  const TokenColors({
    required this.keyword,
    required this.string,
    required this.number,
    required this.comment,
    required this.function,
    required this.variable,
    required this.type,
    required this.operator,
    required this.punctuation,
    required this.tag,
    required this.attribute,
    required this.property,
    required this.constant,
    required this.regexp,
    required this.parameter,
    required this.decorator,
    required this.namespace,
    required this.builtin,
    required this.className,
    required this.interfaceName,
    required this.enumName,
    required this.structName,
    required this.macro,
    required this.label,
  });

  factory TokenColors.fromJson(Map<String, dynamic> json) {
    return TokenColors(
      keyword: ThemeColors._parseColor(json['keyword']),
      string: ThemeColors._parseColor(json['string']),
      number: ThemeColors._parseColor(json['number']),
      comment: ThemeColors._parseColor(json['comment']),
      function: ThemeColors._parseColor(json['function']),
      variable: ThemeColors._parseColor(json['variable']),
      type: ThemeColors._parseColor(json['type']),
      operator: ThemeColors._parseColor(json['operator']),
      punctuation: ThemeColors._parseColor(json['punctuation']),
      tag: ThemeColors._parseColor(json['tag']),
      attribute: ThemeColors._parseColor(json['attribute']),
      property: ThemeColors._parseColor(json['property']),
      constant: ThemeColors._parseColor(json['constant']),
      regexp: ThemeColors._parseColor(json['regexp']),
      parameter: ThemeColors._parseColor(json['parameter']),
      decorator: ThemeColors._parseColor(json['decorator']),
      namespace: ThemeColors._parseColor(json['namespace']),
      builtin: ThemeColors._parseColor(json['builtin']),
      className: ThemeColors._parseColor(json['class']),
      interfaceName: ThemeColors._parseColor(json['interface']),
      enumName: ThemeColors._parseColor(json['enum']),
      structName: ThemeColors._parseColor(json['struct']),
      macro: ThemeColors._parseColor(json['macro']),
      label: ThemeColors._parseColor(json['label']),
    );
  }
}
