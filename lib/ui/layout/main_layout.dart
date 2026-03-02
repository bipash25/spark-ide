import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_ide/core/constants/app_constants.dart';
import 'package:spark_ide/core/theme/theme_provider.dart';
import 'package:spark_ide/core/theme/spark_theme.dart';
import 'package:spark_ide/providers/tab_provider.dart';
import 'package:spark_ide/providers/settings_provider.dart';
import 'package:spark_ide/providers/file_tree_provider.dart';
import 'package:spark_ide/providers/output_provider.dart';
import 'package:spark_ide/ui/layout/activity_bar.dart';
import 'package:spark_ide/ui/layout/status_bar.dart';
import 'package:spark_ide/ui/file_explorer/file_explorer.dart';
import 'package:spark_ide/ui/search/search_panel.dart';
import 'package:spark_ide/ui/tabs/tab_bar.dart';
import 'package:spark_ide/ui/editor/code_editor.dart';
import 'package:spark_ide/ui/editor/breadcrumb_bar.dart';
import 'package:spark_ide/ui/terminal/terminal_panel.dart';
import 'package:spark_ide/ui/welcome/welcome_screen.dart';
import 'package:spark_ide/ui/widgets/command_palette.dart';
import 'package:spark_ide/ui/widgets/unsaved_dialog.dart';
import 'package:spark_ide/ui/classroom/classroom_panel.dart';
import 'package:spark_ide/providers/lsp_provider.dart';
import 'package:spark_ide/providers/session_provider.dart';
import 'package:spark_ide/services/lsp/lsp_client.dart';
import 'package:file_picker/file_picker.dart';

/// The main IDE layout - activity bar + sidebar + editor area + bottom panel + status bar
class MainLayout extends ConsumerStatefulWidget {
  const MainLayout({super.key});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  bool _isDraggingSidebar = false;
  bool _isDraggingPanel = false;
  bool _isHoveringSidebarHandle = false;
  bool _isHoveringPanelHandle = false;
  bool _sessionRestored = false;
  Timer? _sessionSaveTimer;

  @override
  void initState() {
    super.initState();
    // Restore session after first frame so providers are available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreSession();
    });
  }

  @override
  void dispose() {
    _sessionSaveTimer?.cancel();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    if (_sessionRestored) return;
    _sessionRestored = true;

    final session = ref.read(sessionDataProvider);

    // Restore layout state
    ref.read(sidebarWidthProvider.notifier).state = session.sidebarWidth;
    ref.read(bottomPanelHeightProvider.notifier).state = session.bottomPanelHeight;
    ref.read(sidebarVisibleProvider.notifier).state = session.sidebarVisible;
    ref.read(bottomPanelVisibleProvider.notifier).state = session.bottomPanelVisible;

    // Restore workspace folder
    if (session.workspacePath != null && session.workspacePath!.isNotEmpty) {
      await ref.read(fileTreeProvider.notifier).openFolder(session.workspacePath!);
    }

    // Restore open tabs
    if (session.openTabs.isNotEmpty) {
      final tabs = session.openTabs
          .map((t) => (filePath: t.filePath, fileName: t.fileName))
          .toList();
      await ref.read(tabProvider.notifier).restoreTabs(tabs, session.activeTabIndex);
    }
  }

  /// Debounced session save — coalesces rapid state changes (e.g. drag resize)
  /// into a single write after 500ms of inactivity.
  void _saveSession() {
    _sessionSaveTimer?.cancel();
    _sessionSaveTimer = Timer(const Duration(milliseconds: 500), () {
      saveSession(ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeColorsProvider);
    final sidebarVisible = ref.watch(sidebarVisibleProvider);
    final sidebarWidth = ref.watch(sidebarWidthProvider);
    final bottomPanelVisible = ref.watch(bottomPanelVisibleProvider);
    final bottomPanelHeight = ref.watch(bottomPanelHeightProvider);
    final sidebarPanel = ref.watch(sidebarPanelProvider);
    final tabState = ref.watch(tabProvider);
    final isMobile = MediaQuery.of(context).size.width < 600;

    // Auto-save session when key state changes
    ref.listen(tabProvider, (prev, next) => _saveSession());
    ref.listen(fileTreeProvider, (prev, next) => _saveSession());
    ref.listen(sidebarVisibleProvider, (prev, next) => _saveSession());
    ref.listen(bottomPanelVisibleProvider, (prev, next) => _saveSession());
    ref.listen(sidebarWidthProvider, (prev, next) => _saveSession());
    ref.listen(bottomPanelHeightProvider, (prev, next) => _saveSession());

    return CallbackShortcuts(
      bindings: _buildShortcuts(ref),
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: colors.background,
          // Mobile drawer for sidebar
          drawer: isMobile
              ? Drawer(
                  backgroundColor: colors.sidebarBackground,
                  width: MediaQuery.of(context).size.width * 0.8,
                  shape: const RoundedRectangleBorder(),
                  child: SafeArea(
                    child: _buildSidebarContent(sidebarPanel),
                  ),
                )
              : null,
          body: Column(
            children: [
              // Main content area
              Expanded(
                child: Row(
                  children: [
                    // Activity bar (hidden on mobile)
                    if (!isMobile) const ActivityBar(),

                    // Sidebar (desktop only — mobile uses drawer)
                    if (!isMobile && sidebarVisible) ...[
                      SizedBox(
                        width: sidebarWidth,
                        child: _buildSidebarContent(sidebarPanel),
                      ),

                      // Sidebar resize handle
                      MouseRegion(
                        cursor: SystemMouseCursors.resizeColumn,
                        onEnter: (_) =>
                            setState(() => _isHoveringSidebarHandle = true),
                        onExit: (_) =>
                            setState(() => _isHoveringSidebarHandle = false),
                        child: GestureDetector(
                          onHorizontalDragStart: (_) =>
                              setState(() => _isDraggingSidebar = true),
                          onHorizontalDragEnd: (_) =>
                              setState(() => _isDraggingSidebar = false),
                          onHorizontalDragUpdate: (details) {
                            final newWidth =
                                sidebarWidth + details.delta.dx;
                            ref.read(sidebarWidthProvider.notifier).state =
                                newWidth.clamp(
                                  AppSizes.sidebarMinWidth,
                                  AppSizes.sidebarMaxWidth,
                                );
                          },
                          child: AnimatedContainer(
                            duration: AppDurations.fast,
                            width: _isDraggingSidebar || _isHoveringSidebarHandle ? 4 : 1,
                            color: _isDraggingSidebar
                                ? colors.borderFocused
                                : _isHoveringSidebarHandle
                                    ? colors.borderFocused.withValues(alpha: 0.6)
                                    : colors.border.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ],

                    // Editor area
                    Expanded(
                      child: Column(
                        children: [
                          // Tab bar
                          const EditorTabBar(),

                          // Breadcrumb bar (only when a file is open)
                          if (tabState.hasOpenTabs)
                            const BreadcrumbBar(),

                          // Editor / Welcome
                          Expanded(
                            child: tabState.hasOpenTabs
                                ? const CodeEditor()
                                : const WelcomeScreen(),
                          ),

                          // Bottom panel resize handle
                          if (bottomPanelVisible)
                            MouseRegion(
                              cursor: SystemMouseCursors.resizeRow,
                              onEnter: (_) =>
                                  setState(() => _isHoveringPanelHandle = true),
                              onExit: (_) =>
                                  setState(() => _isHoveringPanelHandle = false),
                              child: GestureDetector(
                                onVerticalDragStart: (_) =>
                                    setState(() => _isDraggingPanel = true),
                                onVerticalDragEnd: (_) =>
                                    setState(() => _isDraggingPanel = false),
                                onVerticalDragUpdate: (details) {
                                  final newHeight =
                                      bottomPanelHeight - details.delta.dy;
                                  ref
                                      .read(bottomPanelHeightProvider.notifier)
                                      .state = newHeight.clamp(
                                    AppSizes.panelMinHeight,
                                    MediaQuery.of(context).size.height * 0.5,
                                  );
                                },
                                child: AnimatedContainer(
                                  duration: AppDurations.fast,
                                  height: _isDraggingPanel || _isHoveringPanelHandle ? 4 : 1,
                                  color: _isDraggingPanel
                                      ? colors.borderFocused
                                      : _isHoveringPanelHandle
                                          ? colors.borderFocused.withValues(alpha: 0.6)
                                          : colors.panelBorder,
                                ),
                              ),
                            ),

                          // Bottom panel
                          if (bottomPanelVisible)
                            SizedBox(
                              height: isMobile
                                  ? MediaQuery.of(context).size.height * 0.35
                                  : bottomPanelHeight,
                              child: _BottomPanelArea(),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Status bar (desktop) / Bottom nav bar (mobile)
              if (isMobile)
                _MobileBottomNav(
                  colors: colors,
                  sidebarPanel: sidebarPanel,
                  bottomPanelVisible: bottomPanelVisible,
                  tabState: tabState,
                )
              else
                const StatusBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarContent(SidebarPanel panel) {
    switch (panel) {
      case SidebarPanel.explorer:
        return const FileExplorer();
      case SidebarPanel.search:
        return const SearchPanel();
      case SidebarPanel.classroom:
        return const ClassroomPanel();
    }
  }

  Map<ShortcutActivator, VoidCallback> _buildShortcuts(WidgetRef ref) {
    return {
      // Ctrl+S: Save
      const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
        final tab = ref.read(tabProvider).activeTab;
        ref.read(tabProvider.notifier).saveActiveTab().then((_) {
          if (tab != null && !tab.filePath.startsWith('untitled')) {
            ref.read(lspProvider.notifier).didSaveDocument(
              tab.filePath,
              tab.languageId,
              tab.content,
            );
          }
        });
      },

      // Ctrl+Shift+S: Save All
      const SingleActivator(LogicalKeyboardKey.keyS, control: true, shift: true): () {
        ref.read(tabProvider.notifier).saveAll();
      },

      // Ctrl+W: Close tab (with unsaved changes confirmation)
      const SingleActivator(LogicalKeyboardKey.keyW, control: true): () {
        final tabState = ref.read(tabProvider);
        if (tabState.activeIndex >= 0) {
          confirmCloseTab(context, ref, tabState.activeIndex);
        }
      },

      // Ctrl+B: Toggle sidebar
      const SingleActivator(LogicalKeyboardKey.keyB, control: true): () {
        final current = ref.read(sidebarVisibleProvider);
        ref.read(sidebarVisibleProvider.notifier).state = !current;
      },

      // Ctrl+`: Toggle bottom panel
      const SingleActivator(LogicalKeyboardKey.backquote, control: true): () {
        final current = ref.read(bottomPanelVisibleProvider);
        ref.read(bottomPanelVisibleProvider.notifier).state = !current;
      },

      // Ctrl+O: Open file
      const SingleActivator(LogicalKeyboardKey.keyO, control: true): () async {
        final result = await FilePicker.platform.pickFiles();
        if (result != null && result.files.single.path != null) {
          final path = result.files.single.path!;
          final name = result.files.single.name;
          ref.read(tabProvider.notifier).openFile(path, name);
        }
      },

      // Ctrl+Shift+O: Open folder
      const SingleActivator(LogicalKeyboardKey.keyO, control: true, shift: true): () async {
        final result = await FilePicker.platform.getDirectoryPath();
        if (result != null) {
          await ref.read(fileTreeProvider.notifier).openFolder(result);
          ref.read(sidebarVisibleProvider.notifier).state = true;
          // Initialize LSP workspace
          ref.read(lspProvider.notifier).setWorkspace(result);
        }
      },

      // Ctrl+N: New untitled file
      const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
        final tabState = ref.read(tabProvider);
        final count = tabState.tabs
            .where((t) => t.filePath.startsWith('untitled'))
            .length;
        final name = 'untitled-${count + 1}';
        ref.read(tabProvider.notifier).openFile(name, name);
      },

      // Ctrl+Plus: Increase font size
      const SingleActivator(LogicalKeyboardKey.equal, control: true): () {
        ref.read(settingsProvider.notifier).increaseFontSize();
      },

      // Ctrl+Minus: Decrease font size
      const SingleActivator(LogicalKeyboardKey.minus, control: true): () {
        ref.read(settingsProvider.notifier).decreaseFontSize();
      },

      // Ctrl+Tab: Next tab
      const SingleActivator(LogicalKeyboardKey.tab, control: true): () {
        final tabState = ref.read(tabProvider);
        if (tabState.tabs.length > 1) {
          final next = (tabState.activeIndex + 1) % tabState.tabs.length;
          ref.read(tabProvider.notifier).setActiveTab(next);
        }
      },

      // Ctrl+Shift+Tab: Previous tab
      const SingleActivator(LogicalKeyboardKey.tab, control: true, shift: true): () {
        final tabState = ref.read(tabProvider);
        if (tabState.tabs.length > 1) {
          final prev = (tabState.activeIndex - 1 + tabState.tabs.length) %
              tabState.tabs.length;
          ref.read(tabProvider.notifier).setActiveTab(prev);
        }
      },

      // Ctrl+Shift+P: Command palette
      const SingleActivator(LogicalKeyboardKey.keyP, control: true, shift: true): () {
        CommandPalette.show(context);
      },

      // Ctrl+F: Find in file (handled by editor, but also opens search sidebar as fallback)
      const SingleActivator(LogicalKeyboardKey.keyF, control: true, shift: true): () {
        ref.read(sidebarPanelProvider.notifier).state = SidebarPanel.search;
        ref.read(sidebarVisibleProvider.notifier).state = true;
      },

      // F5: Run current file
      const SingleActivator(LogicalKeyboardKey.f5): () {
        final tabState = ref.read(tabProvider);
        final activeTab = tabState.activeTab;
        if (activeTab != null && !activeTab.filePath.startsWith('untitled')) {
          // Save first, then run
          ref.read(tabProvider.notifier).saveActiveTab().then((_) {
            // Notify LSP of save
            ref.read(lspProvider.notifier).didSaveDocument(
              activeTab.filePath,
              activeTab.languageId,
              activeTab.content,
            );
            final workDir = ref.read(fileTreeProvider).rootPath;
            ref.read(outputProvider.notifier).runFile(
              activeTab.filePath,
              workingDirectory: workDir,
            );
            // Switch to output panel
            ref.read(bottomPanelProvider.notifier).state = BottomPanel.output;
            ref.read(bottomPanelVisibleProvider.notifier).state = true;
          });
        }
      },
    };
  }
}

class _MobileActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final ThemeColors color;
  final VoidCallback onTap;

  const _MobileActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color.foreground, size: 22),
      title: Text(
        label,
        style: TextStyle(
          color: color.foreground,
          fontSize: 14,
          fontFamily: 'JetBrainsMono',
        ),
      ),
      onTap: onTap,
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Mobile bottom navigation bar — replaces the activity bar + status bar on small screens.
class _MobileBottomNav extends ConsumerWidget {
  final ThemeColors colors;
  final SidebarPanel sidebarPanel;
  final bool bottomPanelVisible;
  final TabState tabState;

  const _MobileBottomNav({
    required this.colors,
    required this.sidebarPanel,
    required this.bottomPanelVisible,
    required this.tabState,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: colors.statusBarBackground,
        border: Border(
          top: BorderSide(color: colors.border, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _MobileNavButton(
              icon: Icons.file_copy_outlined,
              label: 'Files',
              color: colors,
              onTap: () {
                ref.read(sidebarPanelProvider.notifier).state =
                    SidebarPanel.explorer;
                Scaffold.of(context).openDrawer();
              },
            ),
            _MobileNavButton(
              icon: Icons.search,
              label: 'Search',
              color: colors,
              onTap: () {
                ref.read(sidebarPanelProvider.notifier).state =
                    SidebarPanel.search;
                Scaffold.of(context).openDrawer();
              },
            ),
            _MobileNavButton(
              icon: Icons.play_arrow,
              label: 'Run',
              color: colors,
              isAccent: true,
              onTap: () {
                final activeTab = tabState.activeTab;
                if (activeTab != null &&
                    !activeTab.filePath.startsWith('untitled')) {
                  ref.read(tabProvider.notifier).saveActiveTab().then((_) {
                    ref.read(lspProvider.notifier).didSaveDocument(
                      activeTab.filePath,
                      activeTab.languageId,
                      activeTab.content,
                    );
                    final workDir = ref.read(fileTreeProvider).rootPath;
                    ref.read(outputProvider.notifier).runFile(
                      activeTab.filePath,
                      workingDirectory: workDir,
                    );
                    ref.read(bottomPanelProvider.notifier).state =
                        BottomPanel.output;
                    ref.read(bottomPanelVisibleProvider.notifier).state = true;
                  });
                }
              },
            ),
            _MobileNavButton(
              icon: Icons.terminal,
              label: 'Terminal',
              color: colors,
              isActive: bottomPanelVisible,
              onTap: () {
                ref.read(bottomPanelProvider.notifier).state =
                    BottomPanel.terminal;
                ref.read(bottomPanelVisibleProvider.notifier).state =
                    !bottomPanelVisible;
              },
            ),
            _MobileNavButton(
              icon: Icons.more_horiz,
              label: 'More',
              color: colors,
              onTap: () => _showMobileMore(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  void _showMobileMore(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.foreground.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              _MobileActionTile(
                icon: Icons.folder_open,
                label: 'Open Folder',
                color: colors,
                onTap: () async {
                  Navigator.pop(context);
                  final result = await FilePicker.platform.getDirectoryPath();
                  if (result != null) {
                    await ref.read(fileTreeProvider.notifier).openFolder(result);
                    ref.read(lspProvider.notifier).setWorkspace(result);
                  }
                },
              ),
              _MobileActionTile(
                icon: Icons.file_open_outlined,
                label: 'Open File',
                color: colors,
                onTap: () async {
                  Navigator.pop(context);
                  final result = await FilePicker.platform.pickFiles();
                  if (result != null && result.files.single.path != null) {
                    final path = result.files.single.path!;
                    final name = result.files.single.name;
                    ref.read(tabProvider.notifier).openFile(path, name);
                  }
                },
              ),
              _MobileActionTile(
                icon: Icons.note_add_outlined,
                label: 'New File',
                color: colors,
                onTap: () {
                  Navigator.pop(context);
                  final ts = ref.read(tabProvider);
                  final count = ts.tabs
                      .where((t) => t.filePath.startsWith('untitled'))
                      .length;
                  final name = 'untitled-${count + 1}';
                  ref.read(tabProvider.notifier).openFile(name, name);
                },
              ),
              _MobileActionTile(
                icon: Icons.save,
                label: 'Save',
                color: colors,
                onTap: () {
                  Navigator.pop(context);
                  ref.read(tabProvider.notifier).saveActiveTab();
                },
              ),
              _MobileActionTile(
                icon: Icons.school_outlined,
                label: 'Classrooms',
                color: colors,
                onTap: () {
                  Navigator.pop(context);
                  ref.read(sidebarPanelProvider.notifier).state =
                      SidebarPanel.classroom;
                  Scaffold.of(context).openDrawer();
                },
              ),
              _MobileActionTile(
                icon: Icons.settings_outlined,
                label: 'Settings',
                color: colors,
                onTap: () {
                  Navigator.pop(context);
                  final c = ref.read(themeColorsProvider);
                  showDialog(
                    context: context,
                    builder: (ctx) => SettingsDialog(colors: c),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileNavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final ThemeColors color;
  final VoidCallback onTap;
  final bool isActive;
  final bool isAccent;

  const _MobileNavButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isActive = false,
    this.isAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isAccent
        ? color.primary
        : isActive
            ? color.activityBarActiveForeground
            : color.statusBarForeground.withValues(alpha: 0.6);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        height: 48,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 9,
                fontFamily: 'JetBrainsMono',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom panel area (Terminal placeholder, Output, Problems)
class _BottomPanelArea extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeColorsProvider);
    final activePanel = ref.watch(bottomPanelProvider);
    final lspState = ref.watch(lspProvider);
    final totalProblems = lspState.errorCount + lspState.warningCount;

    return Container(
      color: colors.panelBackground,
      child: Column(
        children: [
          // Panel tab bar
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                _PanelTab(
                  label: 'TERMINAL',
                  isActive: activePanel == BottomPanel.terminal,
                  onTap: () => ref.read(bottomPanelProvider.notifier).state =
                      BottomPanel.terminal,
                ),
                _PanelTab(
                  label: 'OUTPUT',
                  isActive: activePanel == BottomPanel.output,
                  onTap: () => ref.read(bottomPanelProvider.notifier).state =
                      BottomPanel.output,
                ),
                _PanelTab(
                  label: 'PROBLEMS',
                  isActive: activePanel == BottomPanel.problems,
                  onTap: () => ref.read(bottomPanelProvider.notifier).state =
                      BottomPanel.problems,
                  badge: totalProblems > 0 ? totalProblems : null,
                  badgeColor: lspState.errorCount > 0
                      ? colors.error
                      : colors.warning,
                ),
                const Spacer(),
                // Close button
                GestureDetector(
                  onTap: () =>
                      ref.read(bottomPanelVisibleProvider.notifier).state =
                          false,
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: colors.foreground.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),

          // Panel content
          Expanded(
            child: _buildPanelContent(activePanel, colors),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelContent(BottomPanel panel, ThemeColors colors) {
    switch (panel) {
      case BottomPanel.terminal:
        return const TerminalPanel();
      case BottomPanel.output:
        return const _OutputPanel();
      case BottomPanel.problems:
        return const _ProblemsPanel();
    }
  }
}

/// Output panel that displays code execution results
class _OutputPanel extends ConsumerWidget {
  const _OutputPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeColorsProvider);
    final outputState = ref.watch(outputProvider);

    return Container(
      color: colors.panelBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toolbar
          Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: colors.border.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                if (outputState.isRunning) ...[
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Running...',
                    style: TextStyle(
                      color: colors.foreground.withValues(alpha: 0.6),
                      fontSize: 11,
                      fontFamily: 'JetBrainsMono',
                    ),
                  ),
                ] else if (outputState.exitCode != null) ...[
                  Icon(
                    outputState.exitCode == 0
                        ? Icons.check_circle_outline
                        : Icons.error_outline,
                    size: 14,
                    color: outputState.exitCode == 0
                        ? colors.success
                        : colors.error,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    outputState.exitCode == 0 ? 'Success' : 'Failed',
                    style: TextStyle(
                      color: outputState.exitCode == 0
                          ? colors.success
                          : colors.error,
                      fontSize: 11,
                      fontFamily: 'JetBrainsMono',
                    ),
                  ),
                ],
                const Spacer(),
                // Clear button
                if (outputState.hasOutput)
                  GestureDetector(
                    onTap: () => ref.read(outputProvider.notifier).clear(),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Icon(
                        Icons.delete_outline,
                        size: 14,
                        color: colors.foreground.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Output content
          Expanded(
            child: outputState.hasOutput
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(8),
                    child: SelectableText(
                      outputState.output,
                      style: TextStyle(
                        color: colors.foreground.withValues(alpha: 0.85),
                        fontSize: 12,
                        fontFamily: 'JetBrainsMono',
                        height: 1.5,
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'No output yet. Press F5 to run the current file.',
                      style: TextStyle(
                        color: colors.foreground.withValues(alpha: 0.4),
                        fontSize: 12,
                        fontFamily: 'JetBrainsMono',
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Problems panel showing live LSP diagnostics
class _ProblemsPanel extends ConsumerWidget {
  const _ProblemsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeColorsProvider);
    final lspState = ref.watch(lspProvider);
    final diagnostics = lspState.diagnostics;

    // Flatten all diagnostics into a list grouped by file
    final allEntries = <_DiagnosticEntry>[];
    for (final entry in diagnostics.entries) {
      final filePath = entry.key.startsWith('file://')
          ? entry.key.substring(7)
          : entry.key;
      for (final diag in entry.value) {
        allEntries.add(_DiagnosticEntry(filePath: filePath, diagnostic: diag));
      }
    }

    // Sort: errors first, then warnings, then info/hints
    allEntries.sort((a, b) =>
        a.diagnostic.severity.compareTo(b.diagnostic.severity));

    if (allEntries.isEmpty) {
      return Container(
        color: colors.panelBackground,
        padding: const EdgeInsets.all(12),
        child: Text(
          'No problems detected.',
          style: TextStyle(
            color: colors.foreground.withValues(alpha: 0.4),
            fontSize: 12,
            fontFamily: 'JetBrainsMono',
          ),
        ),
      );
    }

    return Container(
      color: colors.panelBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary bar
          Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: colors.border.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 13, color: colors.error),
                const SizedBox(width: 4),
                Text(
                  '${lspState.errorCount} errors',
                  style: TextStyle(
                    color: lspState.errorCount > 0
                        ? colors.error
                        : colors.foreground.withValues(alpha: 0.5),
                    fontSize: 11,
                    fontFamily: 'JetBrainsMono',
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.warning_amber, size: 13, color: colors.warning),
                const SizedBox(width: 4),
                Text(
                  '${lspState.warningCount} warnings',
                  style: TextStyle(
                    color: lspState.warningCount > 0
                        ? colors.warning
                        : colors.foreground.withValues(alpha: 0.5),
                    fontSize: 11,
                    fontFamily: 'JetBrainsMono',
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
          // Diagnostics list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 2),
              itemCount: allEntries.length,
              itemExtent: 44,
              itemBuilder: (context, index) {
                final entry = allEntries[index];
                final diag = entry.diagnostic;
                final fileName = entry.filePath.split('/').last;

                Color severityColor;
                IconData severityIcon;
                if (diag.isError) {
                  severityColor = colors.error;
                  severityIcon = Icons.error_outline;
                } else if (diag.isWarning) {
                  severityColor = colors.warning;
                  severityIcon = Icons.warning_amber;
                } else if (diag.isInfo) {
                  severityColor = colors.primary;
                  severityIcon = Icons.info_outline;
                } else {
                  severityColor =
                      colors.foreground.withValues(alpha: 0.5);
                  severityIcon = Icons.lightbulb_outline;
                }

                return _DiagnosticRow(
                  fileName: fileName,
                  filePath: entry.filePath,
                  message: diag.message,
                  line: diag.startLine + 1,
                  column: diag.startCharacter + 1,
                  source: diag.source,
                  code: diag.code,
                  severityColor: severityColor,
                  severityIcon: severityIcon,
                  colors: colors,
                  onTap: () async {
                    // Open the file and go to the diagnostic location
                    await ref.read(tabProvider.notifier).openFile(
                      entry.filePath,
                      fileName,
                    );
                    // Navigate to the diagnostic line after the file loads
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final tabState = ref.read(tabProvider);
                      final tab = tabState.activeTab;
                      if (tab == null) return;

                      final text = tab.content;
                      final lines = text.split('\n');
                      final targetLine = diag.startLine; // 0-indexed
                      final targetChar = diag.startCharacter;

                      if (targetLine >= lines.length) return;

                      // Calculate offset
                      int offset = 0;
                      for (int i = 0; i < targetLine; i++) {
                        offset += lines[i].length + 1;
                      }
                      offset += targetChar.clamp(0, lines[targetLine].length);
                      offset = offset.clamp(0, text.length);

                      // Update cursor position in tab provider
                      ref.read(tabProvider.notifier).updateCursorPosition(
                        targetLine + 1,
                        targetChar + 1,
                      );
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticEntry {
  final String filePath;
  final LspDiagnostic diagnostic;

  const _DiagnosticEntry({
    required this.filePath,
    required this.diagnostic,
  });
}

class _DiagnosticRow extends StatefulWidget {
  final String fileName;
  final String filePath;
  final String message;
  final int line;
  final int column;
  final String? source;
  final String? code;
  final Color severityColor;
  final IconData severityIcon;
  final ThemeColors colors;
  final VoidCallback onTap;

  const _DiagnosticRow({
    required this.fileName,
    required this.filePath,
    required this.message,
    required this.line,
    required this.column,
    this.source,
    this.code,
    required this.severityColor,
    required this.severityIcon,
    required this.colors,
    required this.onTap,
  });

  @override
  State<_DiagnosticRow> createState() => _DiagnosticRowState();
}

class _DiagnosticRowState extends State<_DiagnosticRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: _isHovered
              ? widget.colors.foreground.withValues(alpha: 0.04)
              : Colors.transparent,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                widget.severityIcon,
                size: 14,
                color: widget.severityColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.message,
                      style: TextStyle(
                        color: widget.colors.foreground.withValues(alpha: 0.85),
                        fontSize: 12,
                        fontFamily: 'JetBrainsMono',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          widget.fileName,
                          style: TextStyle(
                            color: widget.colors.foreground
                                .withValues(alpha: 0.5),
                            fontSize: 10,
                            fontFamily: 'JetBrainsMono',
                          ),
                        ),
                        Text(
                          ' [${widget.line}, ${widget.column}]',
                          style: TextStyle(
                            color: widget.colors.foreground
                                .withValues(alpha: 0.35),
                            fontSize: 10,
                            fontFamily: 'JetBrainsMono',
                          ),
                        ),
                        if (widget.source != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            widget.source!,
                            style: TextStyle(
                              color: widget.colors.foreground
                                  .withValues(alpha: 0.35),
                              fontSize: 10,
                              fontFamily: 'JetBrainsMono',
                            ),
                          ),
                        ],
                        if (widget.code != null) ...[
                          Text(
                            '(${widget.code})',
                            style: TextStyle(
                              color: widget.colors.foreground
                                  .withValues(alpha: 0.3),
                              fontSize: 10,
                              fontFamily: 'JetBrainsMono',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelTab extends ConsumerStatefulWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final int? badge;
  final Color? badgeColor;

  const _PanelTab({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badge,
    this.badgeColor,
  });

  @override
  ConsumerState<_PanelTab> createState() => _PanelTabState();
}

class _PanelTabState extends ConsumerState<_PanelTab> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeColorsProvider);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: widget.isActive
                    ? colors.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.isActive
                      ? colors.foreground
                      : _isHovered
                          ? colors.foreground.withValues(alpha: 0.8)
                          : colors.foreground.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  fontFamily: 'JetBrainsMono',
                ),
              ),
              if (widget.badge != null && widget.badge! > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: widget.badgeColor?.withValues(alpha: 0.2) ??
                        colors.error.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${widget.badge}',
                    style: TextStyle(
                      color: widget.badgeColor ?? colors.error,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'JetBrainsMono',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
