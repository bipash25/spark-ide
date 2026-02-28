import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_ide/core/theme/theme_provider.dart';
import 'package:spark_ide/core/theme/spark_theme.dart';
import 'package:spark_ide/providers/tab_provider.dart';
import 'package:spark_ide/providers/settings_provider.dart';
import 'package:spark_ide/services/syntax/syntax_highlighter.dart';

/// The main code editor widget with syntax highlighting and in-editor search
class CodeEditor extends ConsumerStatefulWidget {
  const CodeEditor({super.key});

  @override
  ConsumerState<CodeEditor> createState() => _CodeEditorState();
}

class _CodeEditorState extends ConsumerState<CodeEditor> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late ScrollController _scrollController;
  late ScrollController _gutterScrollController;
  int _currentLine = 1;
  int _currentColumn = 1;
  bool _showFindBar = false;
  final _findController = TextEditingController();
  final _replaceController = TextEditingController();
  final _findFocusNode = FocusNode();
  bool _showReplace = false;
  List<_FindMatch> _findMatches = [];
  int _currentMatchIndex = -1;
  String? _lastSyncedTabId;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _scrollController = ScrollController();
    _gutterScrollController = ScrollController();
    _controller.addListener(_onTextChanged);

    // Link gutter scroll to editor scroll
    _scrollController.addListener(() {
      if (_gutterScrollController.hasClients &&
          _gutterScrollController.offset != _scrollController.offset) {
        _gutterScrollController.jumpTo(_scrollController.offset);
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _gutterScrollController.dispose();
    _findController.dispose();
    _replaceController.dispose();
    _findFocusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final tabState = ref.read(tabProvider);
    if (tabState.activeTab == null) return;

    if (_controller.text != tabState.activeTab!.content) {
      ref.read(tabProvider.notifier).updateContent(_controller.text);
      // Re-run find if active
      if (_showFindBar && _findController.text.isNotEmpty) {
        _performFind();
      }
    }

    _updateCursorPosition();
  }

  void _updateCursorPosition() {
    final text = _controller.text;
    final offset = _controller.selection.baseOffset;
    if (offset < 0) return;

    final clampedOffset = offset.clamp(0, text.length);
    final textBefore = text.substring(0, clampedOffset);
    final line = textBefore.split('\n').length;
    final lastNewline = textBefore.lastIndexOf('\n');
    final column = lastNewline == -1 ? clampedOffset + 1 : clampedOffset - lastNewline;

    if (line != _currentLine || column != _currentColumn) {
      setState(() {
        _currentLine = line;
        _currentColumn = column;
      });
      ref.read(tabProvider.notifier).updateCursorPosition(line, column);
    }
  }

  void _toggleFindBar() {
    setState(() {
      _showFindBar = !_showFindBar;
      if (_showFindBar) {
        // Pre-fill with selected text if any
        final selection = _controller.selection;
        if (selection.isValid &&
            !selection.isCollapsed &&
            selection.end <= _controller.text.length) {
          _findController.text = _controller.text.substring(
            selection.start,
            selection.end,
          );
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _findFocusNode.requestFocus();
        });
        _performFind();
      } else {
        _findMatches = [];
        _currentMatchIndex = -1;
        _focusNode.requestFocus();
      }
    });
  }

  void _performFind() {
    final query = _findController.text;
    if (query.isEmpty) {
      setState(() {
        _findMatches = [];
        _currentMatchIndex = -1;
      });
      return;
    }

    final text = _controller.text;
    final matches = <_FindMatch>[];
    int start = 0;
    while (true) {
      final index = text.indexOf(query, start);
      if (index == -1) break;
      matches.add(_FindMatch(start: index, end: index + query.length));
      start = index + 1;
    }

    setState(() {
      _findMatches = matches;
      if (matches.isNotEmpty) {
        // Find the nearest match to current cursor
        final cursor = _controller.selection.baseOffset;
        _currentMatchIndex = 0;
        for (int i = 0; i < matches.length; i++) {
          if (matches[i].start >= cursor) {
            _currentMatchIndex = i;
            break;
          }
        }
        _selectCurrentMatch();
      } else {
        _currentMatchIndex = -1;
      }
    });
  }

  void _findNext() {
    if (_findMatches.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _findMatches.length;
    });
    _selectCurrentMatch();
  }

  void _findPrevious() {
    if (_findMatches.isEmpty) return;
    setState(() {
      _currentMatchIndex =
          (_currentMatchIndex - 1 + _findMatches.length) % _findMatches.length;
    });
    _selectCurrentMatch();
  }

  void _selectCurrentMatch() {
    if (_currentMatchIndex < 0 || _currentMatchIndex >= _findMatches.length) {
      return;
    }
    final match = _findMatches[_currentMatchIndex];
    _controller.selection = TextSelection(
      baseOffset: match.start,
      extentOffset: match.end,
    );
    _focusNode.requestFocus();
  }

  void _replaceCurrent() {
    if (_currentMatchIndex < 0 || _currentMatchIndex >= _findMatches.length) {
      return;
    }
    final match = _findMatches[_currentMatchIndex];
    final text = _controller.text;
    final newText = text.replaceRange(match.start, match.end, _replaceController.text);
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(
      offset: match.start + _replaceController.text.length,
    );
    _performFind();
  }

  void _replaceAll() {
    if (_findController.text.isEmpty) return;
    final newText =
        _controller.text.replaceAll(_findController.text, _replaceController.text);
    _controller.text = newText;
    _performFind();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeColorsProvider);
    final tokenColors = ref.watch(tokenColorsProvider);
    final tabState = ref.watch(tabProvider);
    final settings = ref.watch(settingsProvider);
    final activeTab = tabState.activeTab;

    if (activeTab == null) {
      return const SizedBox.shrink();
    }

    // Sync controller with tab content when switching tabs
    if (_lastSyncedTabId != activeTab.id) {
      _lastSyncedTabId = activeTab.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _controller.removeListener(_onTextChanged);
          _controller.text = activeTab.content;
          _controller.selection = TextSelection.collapsed(
            offset: activeTab.content.length.clamp(0, activeTab.content.length),
          );
          _controller.addListener(_onTextChanged);
          setState(() {
            _currentLine = 1;
            _currentColumn = 1;
          });
        }
      });
    }

    final highlighter = SyntaxHighlighter(tokenColors);
    final lineCount = activeTab.content.split('\n').length;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): _toggleFindBar,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          ref.read(tabProvider.notifier).saveActiveTab();
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_showFindBar) _toggleFindBar();
        },
      },
      child: Focus(
        autofocus: true,
        child: Container(
          color: colors.editorBackground,
          child: Column(
            children: [
              // Find/Replace bar
              if (_showFindBar)
                _FindBar(
                  findController: _findController,
                  replaceController: _replaceController,
                  findFocusNode: _findFocusNode,
                  showReplace: _showReplace,
                  matchCount: _findMatches.length,
                  currentMatch: _currentMatchIndex,
                  colors: colors,
                  onToggleReplace: () =>
                      setState(() => _showReplace = !_showReplace),
                  onFind: _performFind,
                  onFindNext: _findNext,
                  onFindPrevious: _findPrevious,
                  onReplace: _replaceCurrent,
                  onReplaceAll: _replaceAll,
                  onClose: _toggleFindBar,
                ),

              // Editor area
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Line numbers gutter
                    if (settings.lineNumbers)
                      _LineNumberGutter(
                        lineCount: lineCount,
                        currentLine: _currentLine,
                        fontSize: settings.fontSize,
                        scrollController: _gutterScrollController,
                        colors: colors,
                        highlightActiveLine: settings.highlightActiveLine,
                      ),

                    // Editor content
                    Expanded(
                      child: _HighlightedEditor(
                        controller: _controller,
                        focusNode: _focusNode,
                        scrollController: _scrollController,
                        highlighter: highlighter,
                        languageId: activeTab.languageId,
                        settings: settings,
                        colors: colors,
                        currentLine: _currentLine,
                        onTap: _updateCursorPosition,
                      ),
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

/// Line number gutter widget
class _LineNumberGutter extends StatelessWidget {
  final int lineCount;
  final int currentLine;
  final double fontSize;
  final ScrollController scrollController;
  final ThemeColors colors;
  final bool highlightActiveLine;

  const _LineNumberGutter({
    required this.lineCount,
    required this.currentLine,
    required this.fontSize,
    required this.scrollController,
    required this.colors,
    required this.highlightActiveLine,
  });

  @override
  Widget build(BuildContext context) {
    final digits = lineCount.toString().length;
    final gutterWidth = (digits * 9.0 + 28).clamp(50.0, 100.0);

    return Container(
      width: gutterWidth,
      color: colors.editorGutterBackground,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: ListView.builder(
          controller: scrollController,
          itemCount: lineCount,
          itemExtent: fontSize * 1.6,
          padding: const EdgeInsets.only(top: 8),
          itemBuilder: (context, index) {
            final lineNum = index + 1;
            final isActive = lineNum == currentLine;
            return Container(
              height: fontSize * 1.6,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 12, left: 8),
              color: isActive && highlightActiveLine
                  ? colors.editorLineHighlight
                  : null,
              child: Text(
                '$lineNum',
                style: TextStyle(
                  fontSize: fontSize,
                  fontFamily: 'JetBrainsMono',
                  color: isActive
                      ? colors.editorLineNumberActiveForeground
                      : colors.editorLineNumberForeground,
                  height: 1.0,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Editor with syntax-aware text rendering
class _HighlightedEditor extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ScrollController scrollController;
  final SyntaxHighlighter highlighter;
  final String languageId;
  final SettingsState settings;
  final ThemeColors colors;
  final int currentLine;
  final VoidCallback onTap;

  const _HighlightedEditor({
    required this.controller,
    required this.focusNode,
    required this.scrollController,
    required this.highlighter,
    required this.languageId,
    required this.settings,
    required this.colors,
    required this.currentLine,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontSize: settings.fontSize,
      fontFamily: 'JetBrainsMono',
      color: colors.editorForeground,
      height: 1.6,
    );

    return TextField(
      controller: controller,
      focusNode: focusNode,
      scrollController: scrollController,
      maxLines: null,
      expands: true,
      style: baseStyle,
      cursorColor: colors.editorCursorColor,
      cursorWidth: 2,
      decoration: const InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.only(left: 8, top: 8, right: 8),
        isCollapsed: true,
      ),
      selectionControls: MaterialTextSelectionControls(),
      onTap: onTap,
    );
  }
}

/// In-editor find/replace bar
class _FindBar extends StatelessWidget {
  final TextEditingController findController;
  final TextEditingController replaceController;
  final FocusNode findFocusNode;
  final bool showReplace;
  final int matchCount;
  final int currentMatch;
  final ThemeColors colors;
  final VoidCallback onToggleReplace;
  final VoidCallback onFind;
  final VoidCallback onFindNext;
  final VoidCallback onFindPrevious;
  final VoidCallback onReplace;
  final VoidCallback onReplaceAll;
  final VoidCallback onClose;

  const _FindBar({
    required this.findController,
    required this.replaceController,
    required this.findFocusNode,
    required this.showReplace,
    required this.matchCount,
    required this.currentMatch,
    required this.colors,
    required this.onToggleReplace,
    required this.onFind,
    required this.onFindNext,
    required this.onFindPrevious,
    required this.onReplace,
    required this.onReplaceAll,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Find row
          Row(
            children: [
              // Toggle replace
              _SmallIconBtn(
                icon: showReplace
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_right,
                onTap: onToggleReplace,
                color: colors.foreground,
              ),
              const SizedBox(width: 4),
              // Find input
              Expanded(
                child: SizedBox(
                  height: 26,
                  child: TextField(
                    controller: findController,
                    focusNode: findFocusNode,
                    onChanged: (_) => onFind(),
                    onSubmitted: (_) => onFindNext(),
                    style: TextStyle(
                      color: colors.inputForeground,
                      fontSize: 12,
                      fontFamily: 'JetBrainsMono',
                    ),
                    decoration: InputDecoration(
                      hintText: 'Find',
                      hintStyle: TextStyle(
                        color: colors.inputForeground.withValues(alpha: 0.4),
                        fontSize: 12,
                      ),
                      filled: true,
                      fillColor: colors.inputBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(color: colors.inputBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(color: colors.borderFocused),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      isCollapsed: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Match count
              Text(
                matchCount > 0
                    ? '${currentMatch + 1}/$matchCount'
                    : 'No results',
                style: TextStyle(
                  color: colors.foreground.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontFamily: 'JetBrainsMono',
                ),
              ),
              const SizedBox(width: 4),
              // Navigation buttons
              _SmallIconBtn(
                icon: Icons.keyboard_arrow_up,
                onTap: onFindPrevious,
                color: colors.foreground,
                tooltip: 'Previous Match',
              ),
              _SmallIconBtn(
                icon: Icons.keyboard_arrow_down,
                onTap: onFindNext,
                color: colors.foreground,
                tooltip: 'Next Match',
              ),
              const SizedBox(width: 4),
              // Close
              _SmallIconBtn(
                icon: Icons.close,
                onTap: onClose,
                color: colors.foreground,
                tooltip: 'Close',
              ),
            ],
          ),

          // Replace row
          if (showReplace)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const SizedBox(width: 24),
                  Expanded(
                    child: SizedBox(
                      height: 26,
                      child: TextField(
                        controller: replaceController,
                        onSubmitted: (_) => onReplace(),
                        style: TextStyle(
                          color: colors.inputForeground,
                          fontSize: 12,
                          fontFamily: 'JetBrainsMono',
                        ),
                        decoration: InputDecoration(
                          hintText: 'Replace',
                          hintStyle: TextStyle(
                            color: colors.inputForeground.withValues(alpha: 0.4),
                            fontSize: 12,
                          ),
                          filled: true,
                          fillColor: colors.inputBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(color: colors.inputBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide:
                                BorderSide(color: colors.borderFocused),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          isCollapsed: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _SmallIconBtn(
                    icon: Icons.find_replace,
                    onTap: onReplace,
                    color: colors.foreground,
                    tooltip: 'Replace',
                  ),
                  _SmallIconBtn(
                    icon: Icons.done_all,
                    onTap: onReplaceAll,
                    color: colors.foreground,
                    tooltip: 'Replace All',
                  ),
                  // Spacer to match close button width
                  const SizedBox(width: 28),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SmallIconBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final String? tooltip;

  const _SmallIconBtn({
    required this.icon,
    required this.onTap,
    required this.color,
    this.tooltip,
  });

  @override
  State<_SmallIconBtn> createState() => _SmallIconBtnState();
}

class _SmallIconBtnState extends State<_SmallIconBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final btn = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: _hovered
                ? widget.color.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            widget.icon,
            size: 16,
            color: widget.color.withValues(alpha: 0.7),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: btn);
    }
    return btn;
  }
}

class _FindMatch {
  final int start;
  final int end;

  const _FindMatch({required this.start, required this.end});
}
