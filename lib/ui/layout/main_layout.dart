import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_ide/core/constants/app_constants.dart';
import 'package:spark_ide/core/theme/theme_provider.dart';
import 'package:spark_ide/core/theme/spark_theme.dart';
import 'package:spark_ide/providers/tab_provider.dart';
import 'package:spark_ide/providers/settings_provider.dart';
import 'package:spark_ide/providers/file_tree_provider.dart';
import 'package:spark_ide/ui/layout/activity_bar.dart';
import 'package:spark_ide/ui/layout/status_bar.dart';
import 'package:spark_ide/ui/file_explorer/file_explorer.dart';
import 'package:spark_ide/ui/search/search_panel.dart';
import 'package:spark_ide/ui/tabs/tab_bar.dart';
import 'package:spark_ide/ui/editor/code_editor.dart';
import 'package:spark_ide/ui/welcome/welcome_screen.dart';
import 'package:spark_ide/ui/widgets/command_palette.dart';
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

    return CallbackShortcuts(
      bindings: _buildShortcuts(ref),
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: colors.background,
          body: Column(
            children: [
              // Main content area
              Expanded(
                child: Row(
                  children: [
                    // Activity bar (hidden on mobile)
                    if (!isMobile) const ActivityBar(),

                    // Sidebar
                    if (sidebarVisible) ...[
                      SizedBox(
                        width: isMobile
                            ? MediaQuery.of(context).size.width * 0.7
                            : sidebarWidth,
                        child: _buildSidebarContent(sidebarPanel),
                      ),

                      // Sidebar resize handle
                      if (!isMobile)
                        MouseRegion(
                          cursor: SystemMouseCursors.resizeColumn,
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
                            child: Container(
                              width: 3,
                              color: _isDraggingSidebar
                                  ? colors.borderFocused
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
                                child: Container(
                                  height: 3,
                                  color: _isDraggingPanel
                                      ? colors.borderFocused
                                      : colors.panelBorder,
                                ),
                              ),
                            ),

                          // Bottom panel
                          if (bottomPanelVisible)
                            SizedBox(
                              height: bottomPanelHeight,
                              child: _BottomPanelArea(),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Status bar
              const StatusBar(),
            ],
          ),

          // Mobile FAB for actions
          floatingActionButton: isMobile
              ? FloatingActionButton.small(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.buttonForeground,
                  onPressed: () => _showMobileActions(context, ref),
                  child: const Icon(Icons.add, size: 20),
                )
              : null,
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
    }
  }

  Map<ShortcutActivator, VoidCallback> _buildShortcuts(WidgetRef ref) {
    return {
      // Ctrl+S: Save
      const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
        ref.read(tabProvider.notifier).saveActiveTab();
      },

      // Ctrl+Shift+S: Save All
      const SingleActivator(LogicalKeyboardKey.keyS, control: true, shift: true): () {
        ref.read(tabProvider.notifier).saveAll();
      },

      // Ctrl+W: Close tab
      const SingleActivator(LogicalKeyboardKey.keyW, control: true): () {
        final tabState = ref.read(tabProvider);
        if (tabState.activeIndex >= 0) {
          ref.read(tabProvider.notifier).closeTab(tabState.activeIndex);
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
    };
  }

  void _showMobileActions(BuildContext context, WidgetRef ref) {
    final colors = ref.read(themeColorsProvider);
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
                    await ref
                        .read(fileTreeProvider.notifier)
                        .openFolder(result);
                    ref.read(sidebarVisibleProvider.notifier).state = true;
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
                  final tabState = ref.read(tabProvider);
                  final count = tabState.tabs
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
                icon: Icons.view_sidebar_outlined,
                label: 'Toggle Sidebar',
                color: colors,
                onTap: () {
                  Navigator.pop(context);
                  final current = ref.read(sidebarVisibleProvider);
                  ref.read(sidebarVisibleProvider.notifier).state = !current;
                },
              ),
              _MobileActionTile(
                icon: Icons.terminal,
                label: 'Toggle Terminal',
                color: colors,
                onTap: () {
                  Navigator.pop(context);
                  final current = ref.read(bottomPanelVisibleProvider);
                  ref.read(bottomPanelVisibleProvider.notifier).state =
                      !current;
                },
              ),
            ],
          ),
        ),
      ),
    );
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

/// Bottom panel area (Terminal placeholder, Output, Problems)
class _BottomPanelArea extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeColorsProvider);
    final activePanel = ref.watch(bottomPanelProvider);

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
        return Container(
          color: colors.terminalBackground,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Terminal will be available in the next update.',
                style: TextStyle(
                  color: colors.terminalForeground.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontFamily: 'JetBrainsMono',
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '\$ ',
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 13,
                      fontFamily: 'JetBrainsMono',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Container(
                    width: 8,
                    height: 16,
                    color: colors.editorCursorColor.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ],
          ),
        );
      case BottomPanel.output:
        return Container(
          color: colors.panelBackground,
          padding: const EdgeInsets.all(12),
          child: Text(
            'No output yet.',
            style: TextStyle(
              color: colors.foreground.withValues(alpha: 0.4),
              fontSize: 12,
              fontFamily: 'JetBrainsMono',
            ),
          ),
        );
      case BottomPanel.problems:
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
  }
}

class _PanelTab extends ConsumerStatefulWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _PanelTab({
    required this.label,
    required this.isActive,
    required this.onTap,
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
          child: Text(
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
        ),
      ),
    );
  }
}
