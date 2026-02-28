import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_ide/models/editor_tab.dart';
import 'package:spark_ide/services/file_system/file_system_service.dart';
import 'package:uuid/uuid.dart';

/// State for managing editor tabs
class TabState {
  final List<EditorTab> tabs;
  final int activeIndex;

  const TabState({
    this.tabs = const [],
    this.activeIndex = -1,
  });

  EditorTab? get activeTab =>
      activeIndex >= 0 && activeIndex < tabs.length ? tabs[activeIndex] : null;

  bool get hasOpenTabs => tabs.isNotEmpty;

  TabState copyWith({
    List<EditorTab>? tabs,
    int? activeIndex,
  }) {
    return TabState(
      tabs: tabs ?? this.tabs,
      activeIndex: activeIndex ?? this.activeIndex,
    );
  }
}

/// Manages editor tabs (open, close, switch, save)
class TabNotifier extends StateNotifier<TabState> {
  final FileSystemService _fileService;
  static const _uuid = Uuid();

  TabNotifier(this._fileService) : super(const TabState());

  /// Open a file in a new tab or switch to existing tab
  Future<void> openFile(String filePath, String fileName) async {
    // Check if already open
    final existingIndex =
        state.tabs.indexWhere((t) => t.filePath == filePath);
    if (existingIndex != -1) {
      state = state.copyWith(activeIndex: existingIndex);
      return;
    }

    // Read file content
    String content;
    try {
      content = await _fileService.readFile(filePath);
    } catch (e) {
      content = '';
    }

    final tab = EditorTab(
      id: _uuid.v4(),
      filePath: filePath,
      fileName: fileName,
      content: content,
      savedContent: content,
    );

    final newTabs = [...state.tabs, tab];
    state = state.copyWith(
      tabs: newTabs,
      activeIndex: newTabs.length - 1,
    );
  }

  /// Close a tab by index
  void closeTab(int index) {
    if (index < 0 || index >= state.tabs.length) return;

    final newTabs = [...state.tabs]..removeAt(index);
    int newActive = state.activeIndex;

    if (newTabs.isEmpty) {
      newActive = -1;
    } else if (index <= state.activeIndex) {
      newActive = (state.activeIndex - 1).clamp(0, newTabs.length - 1);
    }

    state = state.copyWith(tabs: newTabs, activeIndex: newActive);
  }

  /// Close tab by ID
  void closeTabById(String id) {
    final index = state.tabs.indexWhere((t) => t.id == id);
    if (index != -1) closeTab(index);
  }

  /// Switch to tab by index
  void setActiveTab(int index) {
    if (index >= 0 && index < state.tabs.length) {
      state = state.copyWith(activeIndex: index);
    }
  }

  /// Update content for active tab
  void updateContent(String content) {
    if (state.activeTab == null) return;

    final newTabs = [...state.tabs];
    newTabs[state.activeIndex] =
        newTabs[state.activeIndex].copyWith(content: content);
    state = state.copyWith(tabs: newTabs);
  }

  /// Save active tab
  Future<void> saveActiveTab() async {
    final tab = state.activeTab;
    if (tab == null || !tab.isDirty) return;

    await _fileService.writeFile(tab.filePath, tab.content);

    final newTabs = [...state.tabs];
    newTabs[state.activeIndex] =
        newTabs[state.activeIndex].copyWith(savedContent: tab.content);
    state = state.copyWith(tabs: newTabs);
  }

  /// Save all open tabs
  Future<void> saveAll() async {
    final newTabs = <EditorTab>[];
    for (final tab in state.tabs) {
      if (tab.isDirty) {
        await _fileService.writeFile(tab.filePath, tab.content);
        newTabs.add(tab.copyWith(savedContent: tab.content));
      } else {
        newTabs.add(tab);
      }
    }
    state = state.copyWith(tabs: newTabs);
  }

  /// Close all tabs
  void closeAll() {
    state = const TabState();
  }

  /// Close all tabs except the given index
  void closeOthers(int keepIndex) {
    if (keepIndex < 0 || keepIndex >= state.tabs.length) return;
    final kept = state.tabs[keepIndex];
    state = state.copyWith(tabs: [kept], activeIndex: 0);
  }

  /// Reorder tabs
  void reorderTab(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    final newTabs = [...state.tabs];
    final tab = newTabs.removeAt(oldIndex);
    newTabs.insert(newIndex, tab);

    int newActive = state.activeIndex;
    if (oldIndex == state.activeIndex) {
      newActive = newIndex;
    } else if (oldIndex < state.activeIndex && newIndex >= state.activeIndex) {
      newActive--;
    } else if (oldIndex > state.activeIndex && newIndex <= state.activeIndex) {
      newActive++;
    }

    state = state.copyWith(tabs: newTabs, activeIndex: newActive);
  }

  /// Update cursor position for active tab
  void updateCursorPosition(int line, int column) {
    if (state.activeTab == null) return;
    final newTabs = [...state.tabs];
    newTabs[state.activeIndex] = newTabs[state.activeIndex].copyWith(
      cursorLine: line,
      cursorColumn: column,
    );
    state = state.copyWith(tabs: newTabs);
  }
}

final fileSystemServiceProvider = Provider<FileSystemService>((ref) {
  return FileSystemService();
});

final tabProvider = StateNotifierProvider<TabNotifier, TabState>((ref) {
  final fileService = ref.watch(fileSystemServiceProvider);
  return TabNotifier(fileService);
});
