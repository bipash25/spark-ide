import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_ide/providers/settings_provider.dart';
import 'package:spark_ide/providers/tab_provider.dart';
import 'package:spark_ide/providers/file_tree_provider.dart';
import 'package:spark_ide/services/session/session_service.dart';

/// Provides the SessionService (depends on SharedPreferences).
final sessionServiceProvider = Provider<SessionService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SessionService(prefs);
});

/// Provides the loaded session data (read once at startup).
final sessionDataProvider = Provider<SessionData>((ref) {
  final service = ref.watch(sessionServiceProvider);
  return service.load();
});

/// Saves the current IDE state as a session snapshot.
/// Call this from the UI whenever relevant state changes.
void saveSession(WidgetRef ref) {
  final tabState = ref.read(tabProvider);
  final fileTreeState = ref.read(fileTreeProvider);
  final sidebarWidth = ref.read(sidebarWidthProvider);
  final bottomPanelHeight = ref.read(bottomPanelHeightProvider);
  final sidebarVisible = ref.read(sidebarVisibleProvider);
  final bottomPanelVisible = ref.read(bottomPanelVisibleProvider);

  final sessionTabs = tabState.tabs
      .map((t) => SessionTab(filePath: t.filePath, fileName: t.fileName))
      .toList();

  final data = SessionData(
    workspacePath: fileTreeState.rootPath,
    openTabs: sessionTabs,
    activeTabIndex: tabState.activeIndex,
    sidebarWidth: sidebarWidth,
    bottomPanelHeight: bottomPanelHeight,
    sidebarVisible: sidebarVisible,
    bottomPanelVisible: bottomPanelVisible,
  );

  ref.read(sessionServiceProvider).save(data);
}
