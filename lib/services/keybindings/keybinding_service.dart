import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a single IDE command with its keybinding.
class KeyBinding {
  final String id;
  final String label;
  final String category;
  final SingleActivator defaultBinding;
  final SingleActivator? customBinding;

  const KeyBinding({
    required this.id,
    required this.label,
    required this.category,
    required this.defaultBinding,
    this.customBinding,
  });

  /// The active binding (custom if set, otherwise default).
  SingleActivator get activeBinding => customBinding ?? defaultBinding;

  KeyBinding copyWith({SingleActivator? customBinding, bool clearCustom = false}) {
    return KeyBinding(
      id: id,
      label: label,
      category: category,
      defaultBinding: defaultBinding,
      customBinding: clearCustom ? null : (customBinding ?? this.customBinding),
    );
  }

  /// Format a SingleActivator as a human-readable string.
  static String formatBinding(SingleActivator binding) {
    final parts = <String>[];
    if (binding.control) parts.add('Ctrl');
    if (binding.shift) parts.add('Shift');
    if (binding.alt) parts.add('Alt');
    if (binding.meta) parts.add('Meta');
    parts.add(_keyLabel(binding.trigger));
    return parts.join('+');
  }

  String get activeLabel => formatBinding(activeBinding);
  String get defaultLabel => formatBinding(defaultBinding);
  bool get isCustomized => customBinding != null;

  static String _keyLabel(LogicalKeyboardKey key) {
    // Common key labels
    final map = <LogicalKeyboardKey, String>{
      LogicalKeyboardKey.keyA: 'A',
      LogicalKeyboardKey.keyB: 'B',
      LogicalKeyboardKey.keyC: 'C',
      LogicalKeyboardKey.keyD: 'D',
      LogicalKeyboardKey.keyE: 'E',
      LogicalKeyboardKey.keyF: 'F',
      LogicalKeyboardKey.keyG: 'G',
      LogicalKeyboardKey.keyH: 'H',
      LogicalKeyboardKey.keyI: 'I',
      LogicalKeyboardKey.keyJ: 'J',
      LogicalKeyboardKey.keyK: 'K',
      LogicalKeyboardKey.keyL: 'L',
      LogicalKeyboardKey.keyM: 'M',
      LogicalKeyboardKey.keyN: 'N',
      LogicalKeyboardKey.keyO: 'O',
      LogicalKeyboardKey.keyP: 'P',
      LogicalKeyboardKey.keyQ: 'Q',
      LogicalKeyboardKey.keyR: 'R',
      LogicalKeyboardKey.keyS: 'S',
      LogicalKeyboardKey.keyT: 'T',
      LogicalKeyboardKey.keyU: 'U',
      LogicalKeyboardKey.keyV: 'V',
      LogicalKeyboardKey.keyW: 'W',
      LogicalKeyboardKey.keyX: 'X',
      LogicalKeyboardKey.keyY: 'Y',
      LogicalKeyboardKey.keyZ: 'Z',
      LogicalKeyboardKey.digit0: '0',
      LogicalKeyboardKey.digit1: '1',
      LogicalKeyboardKey.digit2: '2',
      LogicalKeyboardKey.digit3: '3',
      LogicalKeyboardKey.digit4: '4',
      LogicalKeyboardKey.digit5: '5',
      LogicalKeyboardKey.digit6: '6',
      LogicalKeyboardKey.digit7: '7',
      LogicalKeyboardKey.digit8: '8',
      LogicalKeyboardKey.digit9: '9',
      LogicalKeyboardKey.f1: 'F1',
      LogicalKeyboardKey.f2: 'F2',
      LogicalKeyboardKey.f3: 'F3',
      LogicalKeyboardKey.f4: 'F4',
      LogicalKeyboardKey.f5: 'F5',
      LogicalKeyboardKey.f6: 'F6',
      LogicalKeyboardKey.f7: 'F7',
      LogicalKeyboardKey.f8: 'F8',
      LogicalKeyboardKey.f9: 'F9',
      LogicalKeyboardKey.f10: 'F10',
      LogicalKeyboardKey.f11: 'F11',
      LogicalKeyboardKey.f12: 'F12',
      LogicalKeyboardKey.enter: 'Enter',
      LogicalKeyboardKey.escape: 'Escape',
      LogicalKeyboardKey.tab: 'Tab',
      LogicalKeyboardKey.space: 'Space',
      LogicalKeyboardKey.backspace: 'Backspace',
      LogicalKeyboardKey.delete: 'Delete',
      LogicalKeyboardKey.arrowUp: 'Up',
      LogicalKeyboardKey.arrowDown: 'Down',
      LogicalKeyboardKey.arrowLeft: 'Left',
      LogicalKeyboardKey.arrowRight: 'Right',
      LogicalKeyboardKey.home: 'Home',
      LogicalKeyboardKey.end: 'End',
      LogicalKeyboardKey.pageUp: 'PageUp',
      LogicalKeyboardKey.pageDown: 'PageDown',
      LogicalKeyboardKey.equal: '=',
      LogicalKeyboardKey.minus: '-',
      LogicalKeyboardKey.bracketLeft: '[',
      LogicalKeyboardKey.bracketRight: ']',
      LogicalKeyboardKey.slash: '/',
      LogicalKeyboardKey.backquote: '`',
      LogicalKeyboardKey.semicolon: ';',
      LogicalKeyboardKey.quote: "'",
      LogicalKeyboardKey.comma: ',',
      LogicalKeyboardKey.period: '.',
    };
    return map[key] ?? key.keyLabel;
  }
}

/// All default keybindings for the IDE.
final List<KeyBinding> defaultKeyBindings = [
  // File operations
  const KeyBinding(
    id: 'file.save',
    label: 'Save File',
    category: 'File',
    defaultBinding: SingleActivator(LogicalKeyboardKey.keyS, control: true),
  ),
  const KeyBinding(
    id: 'file.saveAll',
    label: 'Save All',
    category: 'File',
    defaultBinding: SingleActivator(LogicalKeyboardKey.keyS, control: true, shift: true),
  ),
  const KeyBinding(
    id: 'file.open',
    label: 'Open File',
    category: 'File',
    defaultBinding: SingleActivator(LogicalKeyboardKey.keyO, control: true),
  ),
  const KeyBinding(
    id: 'file.openFolder',
    label: 'Open Folder',
    category: 'File',
    defaultBinding: SingleActivator(LogicalKeyboardKey.keyO, control: true, shift: true),
  ),
  const KeyBinding(
    id: 'file.newFile',
    label: 'New File',
    category: 'File',
    defaultBinding: SingleActivator(LogicalKeyboardKey.keyN, control: true),
  ),
  const KeyBinding(
    id: 'file.closeTab',
    label: 'Close Tab',
    category: 'File',
    defaultBinding: SingleActivator(LogicalKeyboardKey.keyW, control: true),
  ),

  // Navigation
  const KeyBinding(
    id: 'nav.nextTab',
    label: 'Next Tab',
    category: 'Navigation',
    defaultBinding: SingleActivator(LogicalKeyboardKey.tab, control: true),
  ),
  const KeyBinding(
    id: 'nav.prevTab',
    label: 'Previous Tab',
    category: 'Navigation',
    defaultBinding: SingleActivator(LogicalKeyboardKey.tab, control: true, shift: true),
  ),
  const KeyBinding(
    id: 'nav.commandPalette',
    label: 'Command Palette',
    category: 'Navigation',
    defaultBinding: SingleActivator(LogicalKeyboardKey.keyP, control: true, shift: true),
  ),
  const KeyBinding(
    id: 'nav.goToLine',
    label: 'Go to Line',
    category: 'Navigation',
    defaultBinding: SingleActivator(LogicalKeyboardKey.keyG, control: true),
  ),

  // View
  const KeyBinding(
    id: 'view.toggleSidebar',
    label: 'Toggle Sidebar',
    category: 'View',
    defaultBinding: SingleActivator(LogicalKeyboardKey.keyB, control: true),
  ),
  const KeyBinding(
    id: 'view.toggleTerminal',
    label: 'Toggle Terminal',
    category: 'View',
    defaultBinding: SingleActivator(LogicalKeyboardKey.backquote, control: true),
  ),
  const KeyBinding(
    id: 'view.globalSearch',
    label: 'Search in Files',
    category: 'View',
    defaultBinding: SingleActivator(LogicalKeyboardKey.keyF, control: true, shift: true),
  ),
  const KeyBinding(
    id: 'view.zoomIn',
    label: 'Zoom In',
    category: 'View',
    defaultBinding: SingleActivator(LogicalKeyboardKey.equal, control: true),
  ),
  const KeyBinding(
    id: 'view.zoomOut',
    label: 'Zoom Out',
    category: 'View',
    defaultBinding: SingleActivator(LogicalKeyboardKey.minus, control: true),
  ),

  // Editor
  const KeyBinding(
    id: 'editor.find',
    label: 'Find',
    category: 'Editor',
    defaultBinding: SingleActivator(LogicalKeyboardKey.keyF, control: true),
  ),
  const KeyBinding(
    id: 'editor.duplicateLine',
    label: 'Duplicate Line',
    category: 'Editor',
    defaultBinding: SingleActivator(LogicalKeyboardKey.keyD, control: true),
  ),
  const KeyBinding(
    id: 'editor.deleteLine',
    label: 'Delete Line',
    category: 'Editor',
    defaultBinding: SingleActivator(LogicalKeyboardKey.keyK, control: true, shift: true),
  ),
  const KeyBinding(
    id: 'editor.toggleComment',
    label: 'Toggle Comment',
    category: 'Editor',
    defaultBinding: SingleActivator(LogicalKeyboardKey.slash, control: true),
  ),
  const KeyBinding(
    id: 'editor.selectLine',
    label: 'Select Line',
    category: 'Editor',
    defaultBinding: SingleActivator(LogicalKeyboardKey.keyL, control: true),
  ),
  const KeyBinding(
    id: 'editor.moveLineUp',
    label: 'Move Line Up',
    category: 'Editor',
    defaultBinding: SingleActivator(LogicalKeyboardKey.arrowUp, alt: true),
  ),
  const KeyBinding(
    id: 'editor.moveLineDown',
    label: 'Move Line Down',
    category: 'Editor',
    defaultBinding: SingleActivator(LogicalKeyboardKey.arrowDown, alt: true),
  ),
  const KeyBinding(
    id: 'editor.autoComplete',
    label: 'Trigger Auto-Complete',
    category: 'Editor',
    defaultBinding: SingleActivator(LogicalKeyboardKey.space, control: true),
  ),
  const KeyBinding(
    id: 'editor.goToDefinition',
    label: 'Go to Definition',
    category: 'Editor',
    defaultBinding: SingleActivator(LogicalKeyboardKey.f12),
  ),

  // Run
  const KeyBinding(
    id: 'run.file',
    label: 'Run File',
    category: 'Run',
    defaultBinding: SingleActivator(LogicalKeyboardKey.f5),
  ),
];

/// Service for managing keybinding customization with persistence.
class KeyBindingService {
  static const _prefsKey = 'custom_keybindings';

  final SharedPreferences _prefs;
  late List<KeyBinding> _bindings;

  KeyBindingService(this._prefs) {
    _bindings = List.from(defaultKeyBindings);
    _loadCustomBindings();
  }

  List<KeyBinding> get bindings => List.unmodifiable(_bindings);

  /// Get the active binding for a command ID.
  SingleActivator? getBinding(String id) {
    final kb = _bindings.where((b) => b.id == id).firstOrNull;
    return kb?.activeBinding;
  }

  /// Get the KeyBinding object for a command ID.
  KeyBinding? getKeyBinding(String id) {
    return _bindings.where((b) => b.id == id).firstOrNull;
  }

  /// Customize a keybinding.
  void setCustomBinding(String id, SingleActivator binding) {
    final index = _bindings.indexWhere((b) => b.id == id);
    if (index == -1) return;
    _bindings[index] = _bindings[index].copyWith(customBinding: binding);
    _saveCustomBindings();
  }

  /// Reset a keybinding to default.
  void resetBinding(String id) {
    final index = _bindings.indexWhere((b) => b.id == id);
    if (index == -1) return;
    _bindings[index] = _bindings[index].copyWith(clearCustom: true);
    _saveCustomBindings();
  }

  /// Reset all keybindings to defaults.
  void resetAll() {
    _bindings = List.from(defaultKeyBindings);
    _prefs.remove(_prefsKey);
  }

  /// Get all bindings grouped by category.
  Map<String, List<KeyBinding>> get groupedBindings {
    final map = <String, List<KeyBinding>>{};
    for (final kb in _bindings) {
      map.putIfAbsent(kb.category, () => []).add(kb);
    }
    return map;
  }

  void _loadCustomBindings() {
    final raw = _prefs.getString(_prefsKey);
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in map.entries) {
        final index = _bindings.indexWhere((b) => b.id == entry.key);
        if (index == -1) continue;
        final bindingData = entry.value as Map<String, dynamic>;
        final keyId = bindingData['key'] as int?;
        if (keyId == null) continue;
        final key = LogicalKeyboardKey(keyId);
        final binding = SingleActivator(
          key,
          control: bindingData['ctrl'] as bool? ?? false,
          shift: bindingData['shift'] as bool? ?? false,
          alt: bindingData['alt'] as bool? ?? false,
          meta: bindingData['meta'] as bool? ?? false,
        );
        _bindings[index] = _bindings[index].copyWith(customBinding: binding);
      }
    } catch (_) {
      // Ignore corrupt data
    }
  }

  void _saveCustomBindings() {
    final map = <String, dynamic>{};
    for (final kb in _bindings) {
      if (kb.isCustomized) {
        map[kb.id] = {
          'key': kb.customBinding!.trigger.keyId,
          'ctrl': kb.customBinding!.control,
          'shift': kb.customBinding!.shift,
          'alt': kb.customBinding!.alt,
          'meta': kb.customBinding!.meta,
        };
      }
    }
    if (map.isEmpty) {
      _prefs.remove(_prefsKey);
    } else {
      _prefs.setString(_prefsKey, jsonEncode(map));
    }
  }
}
