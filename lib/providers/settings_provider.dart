import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spark_ide/services/keybindings/keybinding_service.dart';

/// Which panel is currently visible in the sidebar
enum SidebarPanel {
  explorer,
  search,
  classroom,
  // git, extensions, etc. can be added later
}

/// Which panel is visible in the bottom panel
enum BottomPanel {
  terminal,
  output,
  problems,
}

/// Global editor/IDE settings state
class SettingsState {
  final double fontSize;
  final String fontFamily;
  final bool wordWrap;
  final bool minimap;
  final bool lineNumbers;
  final int tabSize;
  final bool insertSpaces;
  final bool autoSave;
  final bool bracketMatching;
  final bool autoCloseBrackets;
  final bool highlightActiveLine;
  final bool renderWhitespace;
  final bool indentGuides;

  const SettingsState({
    this.fontSize = 14.0,
    this.fontFamily = 'JetBrainsMono',
    this.wordWrap = false,
    this.minimap = true,
    this.lineNumbers = true,
    this.tabSize = 4,
    this.insertSpaces = true,
    this.autoSave = false,
    this.bracketMatching = true,
    this.autoCloseBrackets = true,
    this.highlightActiveLine = true,
    this.renderWhitespace = false,
    this.indentGuides = true,
  });

  SettingsState copyWith({
    double? fontSize,
    String? fontFamily,
    bool? wordWrap,
    bool? minimap,
    bool? lineNumbers,
    int? tabSize,
    bool? insertSpaces,
    bool? autoSave,
    bool? bracketMatching,
    bool? autoCloseBrackets,
    bool? highlightActiveLine,
    bool? renderWhitespace,
    bool? indentGuides,
  }) {
    return SettingsState(
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      wordWrap: wordWrap ?? this.wordWrap,
      minimap: minimap ?? this.minimap,
      lineNumbers: lineNumbers ?? this.lineNumbers,
      tabSize: tabSize ?? this.tabSize,
      insertSpaces: insertSpaces ?? this.insertSpaces,
      autoSave: autoSave ?? this.autoSave,
      bracketMatching: bracketMatching ?? this.bracketMatching,
      autoCloseBrackets: autoCloseBrackets ?? this.autoCloseBrackets,
      highlightActiveLine: highlightActiveLine ?? this.highlightActiveLine,
      renderWhitespace: renderWhitespace ?? this.renderWhitespace,
      indentGuides: indentGuides ?? this.indentGuides,
    );
  }

  /// Serialize to a map for SharedPreferences.
  Map<String, dynamic> toMap() => {
        'fontSize': fontSize,
        'fontFamily': fontFamily,
        'wordWrap': wordWrap,
        'minimap': minimap,
        'lineNumbers': lineNumbers,
        'tabSize': tabSize,
        'insertSpaces': insertSpaces,
        'autoSave': autoSave,
        'bracketMatching': bracketMatching,
        'autoCloseBrackets': autoCloseBrackets,
        'highlightActiveLine': highlightActiveLine,
        'renderWhitespace': renderWhitespace,
        'indentGuides': indentGuides,
      };

  /// Deserialize from SharedPreferences values.
  factory SettingsState.fromPrefs(SharedPreferences prefs) {
    return SettingsState(
      fontSize: prefs.getDouble('settings.fontSize') ?? 14.0,
      fontFamily: prefs.getString('settings.fontFamily') ?? 'JetBrainsMono',
      wordWrap: prefs.getBool('settings.wordWrap') ?? false,
      minimap: prefs.getBool('settings.minimap') ?? true,
      lineNumbers: prefs.getBool('settings.lineNumbers') ?? true,
      tabSize: prefs.getInt('settings.tabSize') ?? 4,
      insertSpaces: prefs.getBool('settings.insertSpaces') ?? true,
      autoSave: prefs.getBool('settings.autoSave') ?? false,
      bracketMatching: prefs.getBool('settings.bracketMatching') ?? true,
      autoCloseBrackets: prefs.getBool('settings.autoCloseBrackets') ?? true,
      highlightActiveLine:
          prefs.getBool('settings.highlightActiveLine') ?? true,
      renderWhitespace: prefs.getBool('settings.renderWhitespace') ?? false,
      indentGuides: prefs.getBool('settings.indentGuides') ?? true,
    );
  }
}

/// Settings notifier with persistence.
class SettingsNotifier extends StateNotifier<SettingsState> {
  final SharedPreferences _prefs;

  SettingsNotifier(this._prefs)
      : super(SettingsState.fromPrefs(_prefs));

  void _save() {
    final s = state;
    _prefs.setDouble('settings.fontSize', s.fontSize);
    _prefs.setString('settings.fontFamily', s.fontFamily);
    _prefs.setBool('settings.wordWrap', s.wordWrap);
    _prefs.setBool('settings.minimap', s.minimap);
    _prefs.setBool('settings.lineNumbers', s.lineNumbers);
    _prefs.setInt('settings.tabSize', s.tabSize);
    _prefs.setBool('settings.insertSpaces', s.insertSpaces);
    _prefs.setBool('settings.autoSave', s.autoSave);
    _prefs.setBool('settings.bracketMatching', s.bracketMatching);
    _prefs.setBool('settings.autoCloseBrackets', s.autoCloseBrackets);
    _prefs.setBool('settings.highlightActiveLine', s.highlightActiveLine);
    _prefs.setBool('settings.renderWhitespace', s.renderWhitespace);
    _prefs.setBool('settings.indentGuides', s.indentGuides);
  }

  void setFontSize(double size) {
    state = state.copyWith(fontSize: size.clamp(8.0, 32.0));
    _save();
  }

  void increaseFontSize() => setFontSize(state.fontSize + 1);
  void decreaseFontSize() => setFontSize(state.fontSize - 1);

  void setTabSize(int size) {
    state = state.copyWith(tabSize: size.clamp(1, 8));
    _save();
  }

  void toggleWordWrap() {
    state = state.copyWith(wordWrap: !state.wordWrap);
    _save();
  }

  void toggleMinimap() {
    state = state.copyWith(minimap: !state.minimap);
    _save();
  }

  void toggleLineNumbers() {
    state = state.copyWith(lineNumbers: !state.lineNumbers);
    _save();
  }

  void toggleAutoSave() {
    state = state.copyWith(autoSave: !state.autoSave);
    _save();
  }

  void toggleIndentGuides() {
    state = state.copyWith(indentGuides: !state.indentGuides);
    _save();
  }

  void update(SettingsState Function(SettingsState) updater) {
    state = updater(state);
    _save();
  }
}

/// SharedPreferences provider — initialized eagerly in main().
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden with a ProviderScope override',
  );
});

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsNotifier(prefs);
});

/// Sidebar panel state
final sidebarPanelProvider = StateProvider<SidebarPanel>((ref) {
  return SidebarPanel.explorer;
});

/// Sidebar visibility
final sidebarVisibleProvider = StateProvider<bool>((ref) => true);

/// Bottom panel state
final bottomPanelProvider = StateProvider<BottomPanel>((ref) {
  return BottomPanel.terminal;
});

/// Bottom panel visibility
final bottomPanelVisibleProvider = StateProvider<bool>((ref) => false);

/// Sidebar width
final sidebarWidthProvider = StateProvider<double>((ref) => 260.0);

/// Bottom panel height
final bottomPanelHeightProvider = StateProvider<double>((ref) => 200.0);

/// Keybinding service provider.
final keyBindingServiceProvider = Provider<KeyBindingService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return KeyBindingService(prefs);
});
