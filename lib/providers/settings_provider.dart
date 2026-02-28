import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which panel is currently visible in the sidebar
enum SidebarPanel {
  explorer,
  search,
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
    );
  }
}

/// Settings notifier
class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState());

  void setFontSize(double size) =>
      state = state.copyWith(fontSize: size.clamp(8.0, 32.0));

  void increaseFontSize() => setFontSize(state.fontSize + 1);
  void decreaseFontSize() => setFontSize(state.fontSize - 1);

  void setTabSize(int size) =>
      state = state.copyWith(tabSize: size.clamp(1, 8));

  void toggleWordWrap() => state = state.copyWith(wordWrap: !state.wordWrap);
  void toggleMinimap() => state = state.copyWith(minimap: !state.minimap);
  void toggleLineNumbers() =>
      state = state.copyWith(lineNumbers: !state.lineNumbers);
  void toggleAutoSave() => state = state.copyWith(autoSave: !state.autoSave);

  void update(SettingsState Function(SettingsState) updater) {
    state = updater(state);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
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
