import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_ide/core/theme/theme_provider.dart';
import 'package:spark_ide/core/theme/spark_theme.dart';
import 'package:spark_ide/providers/tab_provider.dart';
import 'package:spark_ide/providers/settings_provider.dart';
import 'package:spark_ide/providers/file_tree_provider.dart';
import 'package:spark_ide/providers/output_provider.dart';
import 'package:spark_ide/providers/lsp_provider.dart';
import 'package:spark_ide/providers/auth_provider.dart';
import 'package:spark_ide/ui/auth/auth_dialog.dart';
import 'package:file_picker/file_picker.dart';

/// Command palette widget (Ctrl+Shift+P)
class CommandPalette extends ConsumerStatefulWidget {
  const CommandPalette({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black38,
      builder: (context) => const CommandPalette(),
    );
  }

  @override
  ConsumerState<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends ConsumerState<CommandPalette> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<_Command> _filteredCommands = [];
  int _selectedIndex = 0;

  late final List<_Command> _allCommands;

  @override
  void initState() {
    super.initState();
    _allCommands = _buildCommands();
    _filteredCommands = _allCommands;
    _controller.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _controller.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCommands = _allCommands;
      } else {
        _filteredCommands = _allCommands
            .where((cmd) =>
                cmd.label.toLowerCase().contains(query) ||
                cmd.category.toLowerCase().contains(query))
            .toList();
      }
      _selectedIndex = 0;
    });
  }

  List<_Command> _buildCommands() {
    return [
      // File commands
      _Command(
        label: 'New File',
        category: 'File',
        shortcut: 'Ctrl+N',
        icon: Icons.note_add_outlined,
        action: () {
          Navigator.pop(context);
          final tabState = ref.read(tabProvider);
          final count = tabState.tabs
              .where((t) => t.filePath.startsWith('untitled'))
              .length;
          final name = 'untitled-${count + 1}';
          ref.read(tabProvider.notifier).openFile(name, name);
        },
      ),
      _Command(
        label: 'Open File',
        category: 'File',
        shortcut: 'Ctrl+O',
        icon: Icons.file_open_outlined,
        action: () async {
          Navigator.pop(context);
          final result = await FilePicker.platform.pickFiles();
          if (result != null && result.files.single.path != null) {
            final path = result.files.single.path!;
            final name = result.files.single.name;
            ref.read(tabProvider.notifier).openFile(path, name);
          }
        },
      ),
      _Command(
        label: 'Open Folder',
        category: 'File',
        shortcut: 'Ctrl+Shift+O',
        icon: Icons.folder_open,
        action: () async {
          Navigator.pop(context);
          final result = await FilePicker.platform.getDirectoryPath();
          if (result != null) {
            await ref.read(fileTreeProvider.notifier).openFolder(result);
            ref.read(sidebarVisibleProvider.notifier).state = true;
          }
        },
      ),
      _Command(
        label: 'Save',
        category: 'File',
        shortcut: 'Ctrl+S',
        icon: Icons.save,
        action: () {
          Navigator.pop(context);
          ref.read(tabProvider.notifier).saveActiveTab();
        },
      ),
      _Command(
        label: 'Save All',
        category: 'File',
        shortcut: 'Ctrl+Shift+S',
        icon: Icons.save_alt,
        action: () {
          Navigator.pop(context);
          ref.read(tabProvider.notifier).saveAll();
        },
      ),
      _Command(
        label: 'Close Tab',
        category: 'File',
        shortcut: 'Ctrl+W',
        icon: Icons.close,
        action: () {
          Navigator.pop(context);
          final tabState = ref.read(tabProvider);
          if (tabState.activeIndex >= 0) {
            ref.read(tabProvider.notifier).closeTab(tabState.activeIndex);
          }
        },
      ),
      _Command(
        label: 'Close All Tabs',
        category: 'File',
        icon: Icons.close_fullscreen,
        action: () {
          Navigator.pop(context);
          ref.read(tabProvider.notifier).closeAll();
        },
      ),

      // View commands
      _Command(
        label: 'Toggle Sidebar',
        category: 'View',
        shortcut: 'Ctrl+B',
        icon: Icons.view_sidebar_outlined,
        action: () {
          Navigator.pop(context);
          final current = ref.read(sidebarVisibleProvider);
          ref.read(sidebarVisibleProvider.notifier).state = !current;
        },
      ),
      _Command(
        label: 'Toggle Terminal',
        category: 'View',
        shortcut: 'Ctrl+`',
        icon: Icons.terminal,
        action: () {
          Navigator.pop(context);
          final current = ref.read(bottomPanelVisibleProvider);
          ref.read(bottomPanelVisibleProvider.notifier).state = !current;
        },
      ),
      _Command(
        label: 'Explorer',
        category: 'View',
        icon: Icons.file_copy_outlined,
        action: () {
          Navigator.pop(context);
          ref.read(sidebarPanelProvider.notifier).state =
              SidebarPanel.explorer;
          ref.read(sidebarVisibleProvider.notifier).state = true;
        },
      ),
      _Command(
        label: 'Search',
        category: 'View',
        shortcut: 'Ctrl+Shift+F',
        icon: Icons.search,
        action: () {
          Navigator.pop(context);
          ref.read(sidebarPanelProvider.notifier).state = SidebarPanel.search;
          ref.read(sidebarVisibleProvider.notifier).state = true;
        },
      ),
      _Command(
        label: 'Zoom In',
        category: 'View',
        shortcut: 'Ctrl+=',
        icon: Icons.zoom_in,
        action: () {
          Navigator.pop(context);
          ref.read(settingsProvider.notifier).increaseFontSize();
        },
      ),
      _Command(
        label: 'Zoom Out',
        category: 'View',
        shortcut: 'Ctrl+-',
        icon: Icons.zoom_out,
        action: () {
          Navigator.pop(context);
          ref.read(settingsProvider.notifier).decreaseFontSize();
        },
      ),

      // Editor commands
      _Command(
        label: 'Toggle Word Wrap',
        category: 'Editor',
        icon: Icons.wrap_text,
        action: () {
          Navigator.pop(context);
          ref.read(settingsProvider.notifier).toggleWordWrap();
        },
      ),
      _Command(
        label: 'Toggle Line Numbers',
        category: 'Editor',
        icon: Icons.format_list_numbered,
        action: () {
          Navigator.pop(context);
          ref.read(settingsProvider.notifier).toggleLineNumbers();
        },
      ),
      _Command(
        label: 'Toggle Minimap',
        category: 'Editor',
        icon: Icons.map_outlined,
        action: () {
          Navigator.pop(context);
          ref.read(settingsProvider.notifier).toggleMinimap();
        },
      ),
      _Command(
        label: 'Toggle Indent Guides',
        category: 'Editor',
        icon: Icons.format_indent_increase,
        action: () {
          Navigator.pop(context);
          ref.read(settingsProvider.notifier).toggleIndentGuides();
        },
      ),

      // Theme commands
      _Command(
        label: 'Theme: Spark Dark',
        category: 'Preferences',
        icon: Icons.dark_mode_outlined,
        action: () {
          Navigator.pop(context);
          ref.read(selectedThemeProvider.notifier).setTheme('spark_dark');
        },
      ),
      _Command(
        label: 'Theme: Spark Light',
        category: 'Preferences',
        icon: Icons.light_mode_outlined,
        action: () {
          Navigator.pop(context);
          ref.read(selectedThemeProvider.notifier).setTheme('spark_light');
        },
      ),
      _Command(
        label: 'Theme: Monokai',
        category: 'Preferences',
        icon: Icons.palette_outlined,
        action: () {
          Navigator.pop(context);
          ref.read(selectedThemeProvider.notifier).setTheme('monokai');
        },
      ),
      _Command(
        label: 'Theme: Dracula',
        category: 'Preferences',
        icon: Icons.palette_outlined,
        action: () {
          Navigator.pop(context);
          ref.read(selectedThemeProvider.notifier).setTheme('dracula');
        },
      ),
      _Command(
        label: 'Theme: One Dark',
        category: 'Preferences',
        icon: Icons.palette_outlined,
        action: () {
          Navigator.pop(context);
          ref.read(selectedThemeProvider.notifier).setTheme('one_dark');
        },
      ),
      _Command(
        label: 'Theme: Solarized Dark',
        category: 'Preferences',
        icon: Icons.palette_outlined,
        action: () {
          Navigator.pop(context);
          ref.read(selectedThemeProvider.notifier).setTheme('solarized_dark');
        },
      ),

      // Tab size
      _Command(
        label: 'Set Tab Size: 2',
        category: 'Editor',
        icon: Icons.space_bar,
        action: () {
          Navigator.pop(context);
          ref.read(settingsProvider.notifier).setTabSize(2);
        },
      ),
      _Command(
        label: 'Set Tab Size: 4',
        category: 'Editor',
        icon: Icons.space_bar,
        action: () {
          Navigator.pop(context);
          ref.read(settingsProvider.notifier).setTabSize(4);
        },
      ),

      // Run commands
      _Command(
        label: 'Run File',
        category: 'Run',
        shortcut: 'F5',
        icon: Icons.play_arrow,
        action: () {
          Navigator.pop(context);
          final tabState = ref.read(tabProvider);
          final activeTab = tabState.activeTab;
          if (activeTab != null && !activeTab.filePath.startsWith('untitled')) {
            ref.read(tabProvider.notifier).saveActiveTab().then((_) {
              final workDir = ref.read(fileTreeProvider).rootPath;
              ref.read(outputProvider.notifier).runFile(
                activeTab.filePath,
                workingDirectory: workDir,
              );
              ref.read(bottomPanelProvider.notifier).state = BottomPanel.output;
              ref.read(bottomPanelVisibleProvider.notifier).state = true;
            });
          }
        },
      ),
      _Command(
        label: 'Clear Output',
        category: 'Run',
        icon: Icons.delete_outline,
        action: () {
          Navigator.pop(context);
          ref.read(outputProvider.notifier).clear();
        },
      ),

      // Edit commands
      _Command(
        label: 'Duplicate Line',
        category: 'Edit',
        shortcut: 'Ctrl+D',
        icon: Icons.content_copy,
        action: () {
          Navigator.pop(context);
        },
      ),
      _Command(
        label: 'Toggle Comment',
        category: 'Edit',
        shortcut: 'Ctrl+/',
        icon: Icons.comment_outlined,
        action: () {
          Navigator.pop(context);
        },
      ),
      _Command(
        label: 'Select Line',
        category: 'Edit',
        shortcut: 'Ctrl+L',
        icon: Icons.select_all,
        action: () {
          Navigator.pop(context);
        },
      ),
      _Command(
        label: 'Move Line Up',
        category: 'Edit',
        shortcut: 'Alt+Up',
        icon: Icons.arrow_upward,
        action: () {
          Navigator.pop(context);
        },
      ),
      _Command(
        label: 'Move Line Down',
        category: 'Edit',
        shortcut: 'Alt+Down',
        icon: Icons.arrow_downward,
        action: () {
          Navigator.pop(context);
        },
      ),
      _Command(
        label: 'Delete Line',
        category: 'Edit',
        shortcut: 'Ctrl+Shift+K',
        icon: Icons.remove_circle_outline,
        action: () {
          Navigator.pop(context);
        },
      ),
      _Command(
        label: 'Trigger Suggest',
        category: 'Edit',
        shortcut: 'Ctrl+Space',
        icon: Icons.auto_fix_high,
        action: () {
          Navigator.pop(context);
        },
      ),

      // Navigation commands
      _Command(
        label: 'Go to Line',
        category: 'Navigation',
        shortcut: 'Ctrl+G',
        icon: Icons.format_list_numbered,
        action: () {
          Navigator.pop(context);
        },
      ),
      _Command(
        label: 'Find in File',
        category: 'Navigation',
        shortcut: 'Ctrl+F',
        icon: Icons.find_in_page,
        action: () {
          Navigator.pop(context);
        },
      ),

      // LSP commands
      _Command(
        label: 'Toggle LSP',
        category: 'LSP',
        icon: Icons.code,
        action: () {
          Navigator.pop(context);
          ref.read(lspProvider.notifier).toggleEnabled();
        },
      ),
      _Command(
        label: 'Restart LSP Server',
        category: 'LSP',
        icon: Icons.refresh,
        action: () async {
          Navigator.pop(context);
          final tabState = ref.read(tabProvider);
          final activeTab = tabState.activeTab;
          if (activeTab != null) {
            await ref.read(lspProvider.notifier).stopClient(activeTab.languageId);
            await ref.read(lspProvider.notifier).startClient(activeTab.languageId);
          }
        },
      ),

      // Navigation / LSP commands
      _Command(
        label: 'Go to Definition',
        category: 'Navigation',
        shortcut: 'F12',
        icon: Icons.open_in_new,
        action: () {
          Navigator.pop(context);
          // F12 is handled by the editor's CallbackShortcuts
        },
      ),

      // Auth & Classroom commands
      _Command(
        label: 'Sign In / Account',
        category: 'Account',
        icon: Icons.person_outline,
        action: () {
          Navigator.pop(context);
          AuthDialog.show(context);
        },
      ),
      _Command(
        label: 'Sign Out',
        category: 'Account',
        icon: Icons.logout,
        action: () {
          Navigator.pop(context);
          ref.read(authProvider.notifier).signOut();
        },
      ),
      _Command(
        label: 'Open Classrooms',
        category: 'Classroom',
        icon: Icons.school_outlined,
        action: () {
          Navigator.pop(context);
          ref.read(sidebarPanelProvider.notifier).state =
              SidebarPanel.classroom;
          ref.read(sidebarVisibleProvider.notifier).state = true;
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeColorsProvider);

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            setState(() {
              _selectedIndex =
                  (_selectedIndex + 1).clamp(0, _filteredCommands.length - 1);
            });
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            setState(() {
              _selectedIndex =
                  (_selectedIndex - 1).clamp(0, _filteredCommands.length - 1);
            });
          } else if (event.logicalKey == LogicalKeyboardKey.enter) {
            if (_filteredCommands.isNotEmpty) {
              _filteredCommands[_selectedIndex].action();
            }
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.pop(context);
          }
        }
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 100, vertical: 60),
        alignment: Alignment.topCenter,
        child: Container(
          width: 550,
          constraints: const BoxConstraints(maxHeight: 400),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search input
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: colors.border),
                  ),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: TextStyle(
                    color: colors.foreground,
                    fontSize: 14,
                    fontFamily: 'JetBrainsMono',
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type a command...',
                    hintStyle: TextStyle(
                      color: colors.foreground.withValues(alpha: 0.4),
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: colors.primary,
                    ),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  ),
                ),
              ),

              // Results
              if (_filteredCommands.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No commands found',
                    style: TextStyle(
                      color: colors.foreground.withValues(alpha: 0.4),
                      fontSize: 13,
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredCommands.length,
                    itemExtent: 36,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemBuilder: (context, index) {
                      final cmd = _filteredCommands[index];
                      final isSelected = index == _selectedIndex;
                      return _CommandItem(
                        command: cmd,
                        isSelected: isSelected,
                        colors: colors,
                        onTap: () => cmd.action(),
                        onHover: () => setState(() => _selectedIndex = index),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Command {
  final String label;
  final String category;
  final String? shortcut;
  final IconData icon;
  final VoidCallback action;

  const _Command({
    required this.label,
    required this.category,
    this.shortcut,
    required this.icon,
    required this.action,
  });
}

class _CommandItem extends StatefulWidget {
  final _Command command;
  final bool isSelected;
  final ThemeColors colors;
  final VoidCallback onTap;
  final VoidCallback onHover;

  const _CommandItem({
    required this.command,
    required this.isSelected,
    required this.colors,
    required this.onTap,
    required this.onHover,
  });

  @override
  State<_CommandItem> createState() => _CommandItemState();
}

class _CommandItemState extends State<_CommandItem> {
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => widget.onHover(),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          color: widget.isSelected
              ? widget.colors.listActiveBackground
              : Colors.transparent,
          child: Row(
            children: [
              Icon(
                widget.command.icon,
                size: 16,
                color: widget.colors.foreground.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 10),
              // Category badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: widget.colors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  widget.command.category,
                  style: TextStyle(
                    color: widget.colors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Command label
              Expanded(
                child: Text(
                  widget.command.label,
                  style: TextStyle(
                    color: widget.colors.foreground,
                    fontSize: 13,
                    fontFamily: 'JetBrainsMono',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Shortcut
              if (widget.command.shortcut != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.colors.surface,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                        color: widget.colors.border.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    widget.command.shortcut!,
                    style: TextStyle(
                      color: widget.colors.foreground.withValues(alpha: 0.5),
                      fontSize: 10,
                      fontFamily: 'JetBrainsMono',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
