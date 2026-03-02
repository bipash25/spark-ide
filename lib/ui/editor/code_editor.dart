import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_ide/core/theme/theme_provider.dart';
import 'package:spark_ide/core/theme/spark_theme.dart';
import 'package:spark_ide/providers/tab_provider.dart';
import 'package:spark_ide/providers/settings_provider.dart';
import 'package:spark_ide/providers/lsp_provider.dart';
import 'package:spark_ide/services/lsp/lsp_client.dart';
import 'package:spark_ide/services/syntax/syntax_highlighter.dart';
import 'package:spark_ide/ui/editor/highlighted_text_controller.dart';
import 'package:spark_ide/ui/editor/auto_edit_formatter.dart';
import 'package:spark_ide/services/autocomplete/autocomplete_service.dart';

/// The main code editor widget with syntax highlighting and in-editor search
class CodeEditor extends ConsumerStatefulWidget {
  const CodeEditor({super.key});

  @override
  ConsumerState<CodeEditor> createState() => _CodeEditorState();
}

class _CodeEditorState extends ConsumerState<CodeEditor> {
  late HighlightedTextController _controller;
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
  bool _showGoToLine = false;
  final _goToLineController = TextEditingController();
  final _goToLineFocusNode = FocusNode();

  // Auto-complete state
  List<CompletionItem> _suggestions = [];
  int _selectedSuggestion = 0;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  bool _isAcceptingSuggestion = false;

  // LSP document sync state
  int _lspDocVersion = 1;
  Timer? _lspChangeDebounce;

  // Hover tooltip state
  Timer? _hoverDebounce;
  OverlayEntry? _hoverOverlay;
  String? _hoverContent;
  Offset _hoverPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _controller = HighlightedTextController();
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
    _lspChangeDebounce?.cancel();
    _hoverDebounce?.cancel();
    _removeHoverOverlay();
    _removeOverlay();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _gutterScrollController.dispose();
    _findController.dispose();
    _replaceController.dispose();
    _findFocusNode.dispose();
    _goToLineController.dispose();
    _goToLineFocusNode.dispose();
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

      // Notify LSP of document change (debounced to avoid flooding)
      _lspChangeDebounce?.cancel();
      _lspChangeDebounce = Timer(const Duration(milliseconds: 300), () {
        final tab = ref.read(tabProvider).activeTab;
        if (tab != null && !tab.filePath.startsWith('untitled')) {
          _lspDocVersion++;
          ref.read(lspProvider.notifier).didChangeDocument(
            tab.filePath,
            tab.languageId,
            _controller.text,
            _lspDocVersion,
          );
        }
      });
    }

    _updateCursorPosition();

    // Trigger auto-complete
    if (!_isAcceptingSuggestion) {
      _triggerAutoComplete();
    }
  }

  void _triggerAutoComplete() {
    final tabState = ref.read(tabProvider);
    final activeTab = tabState.activeTab;
    if (activeTab == null) return;

    final text = _controller.text;
    final selection = _controller.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      _removeOverlay();
      return;
    }

    final cursor = selection.baseOffset;
    final prefix = AutoCompleteService.getCurrentPrefix(text, cursor);

    if (prefix == null) {
      _removeOverlay();
      return;
    }

    // Get word-based suggestions immediately
    final wordSuggestions = AutoCompleteService.getSuggestions(
      text: text,
      prefix: prefix,
      languageId: activeTab.languageId,
      cursorOffset: cursor,
    );

    if (wordSuggestions.isEmpty) {
      _removeOverlay();
    } else {
      setState(() {
        _suggestions = wordSuggestions;
        _selectedSuggestion = 0;
      });
      _showOrUpdateOverlay();
    }

    // Also request LSP completions asynchronously
    _requestLspCompletions(activeTab, text, cursor, prefix, wordSuggestions);
  }

  /// Asynchronously fetch LSP completions and merge with existing suggestions.
  Future<void> _requestLspCompletions(
    dynamic activeTab,
    String text,
    int cursor,
    String prefix,
    List<CompletionItem> wordSuggestions,
  ) async {
    if (activeTab.filePath.startsWith('untitled')) return;

    final lspState = ref.read(lspProvider);
    final client = lspState.clients[activeTab.languageId];
    if (client == null || !client.isRunning) return;

    // Calculate line/character from cursor offset
    final textBefore = text.substring(0, cursor);
    final line = textBefore.split('\n').length - 1;
    final lastNewline = textBefore.lastIndexOf('\n');
    final character = lastNewline == -1 ? cursor : cursor - lastNewline - 1;

    final lspItems = await ref.read(lspProvider.notifier).getCompletions(
      activeTab.filePath,
      activeTab.languageId,
      line,
      character,
    );

    if (lspItems == null || lspItems.isEmpty) return;
    if (!mounted) return;

    // Convert LSP items to CompletionItems
    final lowerPrefix = prefix.toLowerCase();
    final lspSuggestions = <CompletionItem>[];
    final seenLabels = <String>{};

    // Track labels from word suggestions to avoid duplicates
    for (final ws in wordSuggestions) {
      seenLabels.add(ws.label);
    }

    for (final item in lspItems) {
      if (item is! Map) continue;
      final label = item['label'] as String? ?? '';
      final insertText = item['insertText'] as String?;
      final detail = item['detail'] as String?;
      final kindInt = item['kind'] as int?;

      // Filter by prefix match
      final effectiveLabel = insertText ?? label;
      if (!effectiveLabel.toLowerCase().startsWith(lowerPrefix)) continue;

      if (seenLabels.add(label)) {
        lspSuggestions.add(CompletionItem(
          label: label,
          kind: lspKindToCompletionKind(kindInt),
          detail: detail,
          insertText: insertText,
        ));
      }
    }

    if (lspSuggestions.isEmpty) return;
    if (!mounted) return;

    // Merge: LSP items first, then word-based
    final merged = <CompletionItem>[...lspSuggestions, ...wordSuggestions];
    if (merged.length > AutoCompleteService.maxSuggestions) {
      merged.removeRange(AutoCompleteService.maxSuggestions, merged.length);
    }

    setState(() {
      _suggestions = merged;
      _selectedSuggestion = 0;
    });
    _showOrUpdateOverlay();
  }

  void _showOrUpdateOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
      return;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) {
        final colors = ref.read(themeColorsProvider);
        return _AutoCompletePopup(
          suggestions: _suggestions,
          selectedIndex: _selectedSuggestion,
          colors: colors,
          layerLink: _layerLink,
          onSelect: _acceptSuggestionAt,
        );
      },
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (_suggestions.isNotEmpty) {
      setState(() {
        _suggestions = [];
        _selectedSuggestion = 0;
      });
    }
  }

  void _acceptSuggestion() {
    if (_suggestions.isEmpty) return;
    _acceptSuggestionAt(_selectedSuggestion);
  }

  void _acceptSuggestionAt(int index) {
    if (index < 0 || index >= _suggestions.length) return;

    final suggestion = _suggestions[index];
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset;
    final prefixStart = AutoCompleteService.getPrefixStart(text, cursor);
    final insertText = suggestion.textToInsert;

    _isAcceptingSuggestion = true;
    _controller.removeListener(_onTextChanged);

    final newText = text.substring(0, prefixStart) +
        insertText +
        text.substring(cursor);
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(
      offset: prefixStart + insertText.length,
    );

    _controller.addListener(_onTextChanged);
    _isAcceptingSuggestion = false;
    _removeOverlay();

    // Notify provider of content change
    ref.read(tabProvider.notifier).updateContent(_controller.text);
    _updateCursorPosition();
    _focusNode.requestFocus();
  }

  bool _handleAutoCompleteKey(KeyEvent event) {
    if (_suggestions.isEmpty) return false;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedSuggestion =
            (_selectedSuggestion + 1) % _suggestions.length;
      });
      _overlayEntry?.markNeedsBuild();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedSuggestion =
            (_selectedSuggestion - 1 + _suggestions.length) %
                _suggestions.length;
      });
      _overlayEntry?.markNeedsBuild();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.tab) {
      _acceptSuggestion();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _removeOverlay();
      return true;
    }
    return false;
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

    // Update bracket matching
    _updateBracketMatch(text, clampedOffset);
  }

  static const _openBrackets = '({[';
  static const _closeBrackets = ')}]';

  void _updateBracketMatch(String text, int cursor) {
    final colors = ref.read(themeColorsProvider);
    final highlightColor = colors.editorSelectionBackground;

    // Check char at cursor and char before cursor
    int? bracketPos;

    if (cursor < text.length && _isBracket(text[cursor])) {
      bracketPos = cursor;
    } else if (cursor > 0 && _isBracket(text[cursor - 1])) {
      bracketPos = cursor - 1;
    }

    if (bracketPos == null) {
      _controller.updateBracketMatch(null, null, null);
      return;
    }

    final ch = text[bracketPos];
    final matchPos = _findMatchingBracket(text, bracketPos, ch);

    if (matchPos != null) {
      _controller.updateBracketMatch(bracketPos, matchPos, highlightColor);
    } else {
      _controller.updateBracketMatch(null, null, null);
    }
  }

  bool _isBracket(String ch) {
    return _openBrackets.contains(ch) || _closeBrackets.contains(ch);
  }

  int? _findMatchingBracket(String text, int pos, String bracket) {
    final openIdx = _openBrackets.indexOf(bracket);
    if (openIdx >= 0) {
      // Search forward for closing bracket
      final close = _closeBrackets[openIdx];
      int depth = 1;
      for (int i = pos + 1; i < text.length; i++) {
        if (text[i] == bracket) {
          depth++;
        } else if (text[i] == close) {
          depth--;
          if (depth == 0) return i;
        }
      }
      return null;
    }

    final closeIdx = _closeBrackets.indexOf(bracket);
    if (closeIdx >= 0) {
      // Search backward for opening bracket
      final open = _openBrackets[closeIdx];
      int depth = 1;
      for (int i = pos - 1; i >= 0; i--) {
        if (text[i] == bracket) {
          depth++;
        } else if (text[i] == open) {
          depth--;
          if (depth == 0) return i;
        }
      }
      return null;
    }

    return null;
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

  /// Insert indent (tab/spaces) at cursor or indent selected lines
  void _handleTab() {
    final settings = ref.read(settingsProvider);
    final indent = settings.insertSpaces ? ' ' * settings.tabSize : '\t';
    final text = _controller.text;
    final selection = _controller.selection;

    if (!selection.isValid) return;

    if (selection.isCollapsed) {
      // No selection — insert indent at cursor
      final cursor = selection.baseOffset;
      final newText =
          text.substring(0, cursor) + indent + text.substring(cursor);
      _controller.removeListener(_onTextChanged);
      _controller.text = newText;
      _controller.selection =
          TextSelection.collapsed(offset: cursor + indent.length);
      _controller.addListener(_onTextChanged);
      _onTextChanged();
    } else {
      // Selection — indent each selected line
      _indentLines(indent, selection);
    }
  }

  /// Remove one level of indent from cursor line or selected lines
  void _handleShiftTab() {
    final settings = ref.read(settingsProvider);
    final selection = _controller.selection;
    if (!selection.isValid) return;
    _dedentLines(settings.tabSize, selection);
  }

  void _indentLines(String indent, TextSelection selection) {
    final text = _controller.text;
    final startLine = text.substring(0, selection.start).split('\n').length - 1;
    final endLine = text.substring(0, selection.end).split('\n').length - 1;
    final lines = text.split('\n');

    for (int i = startLine; i <= endLine; i++) {
      lines[i] = indent + lines[i];
    }

    final newText = lines.join('\n');
    final addedPerLine = indent.length;
    _controller.removeListener(_onTextChanged);
    _controller.text = newText;
    _controller.selection = TextSelection(
      baseOffset: selection.start + addedPerLine,
      extentOffset: selection.end + addedPerLine * (endLine - startLine + 1),
    );
    _controller.addListener(_onTextChanged);
    _onTextChanged();
  }

  void _dedentLines(int tabSize, TextSelection selection) {
    final text = _controller.text;
    final startLine = text.substring(0, selection.start).split('\n').length - 1;
    final endLine = text.substring(0, selection.end).split('\n').length - 1;
    final lines = text.split('\n');

    int firstLineRemoved = 0;
    int totalRemoved = 0;

    for (int i = startLine; i <= endLine; i++) {
      final line = lines[i];
      int removed = 0;
      for (int j = 0; j < line.length && removed < tabSize; j++) {
        if (line[j] == ' ') {
          removed++;
        } else if (line[j] == '\t') {
          removed = tabSize; // treat tab as full indent
        } else {
          break;
        }
      }
      if (removed > 0) {
        lines[i] = line.substring(removed);
        if (i == startLine) firstLineRemoved = removed;
        totalRemoved += removed;
      }
    }

    if (totalRemoved == 0) return;

    final newText = lines.join('\n');
    _controller.removeListener(_onTextChanged);
    _controller.text = newText;
    _controller.selection = TextSelection(
      baseOffset: (selection.start - firstLineRemoved).clamp(0, newText.length),
      extentOffset:
          (selection.end - totalRemoved).clamp(0, newText.length),
    );
    _controller.addListener(_onTextChanged);
    _onTextChanged();
  }

  /// Toggle go-to-line dialog
  void _toggleGoToLine() {
    setState(() {
      _showGoToLine = !_showGoToLine;
      if (_showGoToLine) {
        _goToLineController.text = '';
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _goToLineFocusNode.requestFocus();
        });
      } else {
        _focusNode.requestFocus();
      }
    });
  }

  /// Navigate to a specific line number
  void _goToLine(int lineNumber) {
    final text = _controller.text;
    final lines = text.split('\n');
    final targetLine = lineNumber.clamp(1, lines.length);

    // Calculate offset of the start of the target line
    int offset = 0;
    for (int i = 0; i < targetLine - 1; i++) {
      offset += lines[i].length + 1; // +1 for newline
    }
    offset = offset.clamp(0, text.length);

    _controller.selection = TextSelection.collapsed(offset: offset);
    _focusNode.requestFocus();
    _updateCursorPosition();
    setState(() => _showGoToLine = false);
  }

  /// Duplicate current line (Ctrl+D) — or, if text is selected, find and
  /// select the next occurrence of that text (VS Code behavior).
  void _duplicateLine() {
    final text = _controller.text;
    final selection = _controller.selection;
    if (!selection.isValid) return;

    // If there's a non-empty selection, find & select the next occurrence
    if (!selection.isCollapsed) {
      final selected = selection.textInside(text);
      if (selected.isEmpty) return;

      // Search forward from selection end
      final searchFrom = selection.end;
      int nextIndex = text.indexOf(selected, searchFrom);
      // Wrap around if not found
      if (nextIndex == -1) {
        nextIndex = text.indexOf(selected);
      }
      if (nextIndex == -1 || nextIndex == selection.start) return;

      _controller.selection = TextSelection(
        baseOffset: nextIndex,
        extentOffset: nextIndex + selected.length,
      );
      return;
    }

    // No selection — duplicate the current line
    final cursor = selection.baseOffset.clamp(0, text.length);
    final lines = text.split('\n');
    final textBefore = text.substring(0, cursor);
    final lineIndex = textBefore.split('\n').length - 1;

    if (lineIndex >= lines.length) return;

    final line = lines[lineIndex];
    lines.insert(lineIndex + 1, line);

    final newText = lines.join('\n');
    final newCursor = cursor + line.length + 1;

    _controller.removeListener(_onTextChanged);
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(
      offset: newCursor.clamp(0, newText.length),
    );
    _controller.addListener(_onTextChanged);
    _onTextChanged();
  }

  /// Toggle line comment (Ctrl+/)
  void _toggleComment() {
    final tabState = ref.read(tabProvider);
    final activeTab = tabState.activeTab;
    if (activeTab == null) return;

    final text = _controller.text;
    final selection = _controller.selection;
    if (!selection.isValid) return;

    // Determine comment prefix based on language
    final commentPrefix = _getCommentPrefix(activeTab.languageId);
    if (commentPrefix == null) return;

    final startLine = text.substring(0, selection.start).split('\n').length - 1;
    final endLine = text.substring(0, selection.end).split('\n').length - 1;
    final lines = text.split('\n');

    // Check if all selected lines are already commented
    bool allCommented = true;
    for (int i = startLine; i <= endLine; i++) {
      if (!lines[i].trimLeft().startsWith(commentPrefix)) {
        allCommented = false;
        break;
      }
    }

    int totalDelta = 0;
    int firstLineDelta = 0;

    if (allCommented) {
      // Uncomment
      for (int i = startLine; i <= endLine; i++) {
        final trimmed = lines[i].trimLeft();
        final indent = lines[i].length - trimmed.length;
        final withoutComment = trimmed.startsWith('$commentPrefix ')
            ? trimmed.substring(commentPrefix.length + 1)
            : trimmed.substring(commentPrefix.length);
        lines[i] = lines[i].substring(0, indent) + withoutComment;
        final removed = (trimmed.length - withoutComment.length);
        totalDelta -= removed;
        if (i == startLine) firstLineDelta = -removed;
      }
    } else {
      // Comment
      for (int i = startLine; i <= endLine; i++) {
        final trimmed = lines[i].trimLeft();
        final indent = lines[i].length - trimmed.length;
        lines[i] = '${lines[i].substring(0, indent)}$commentPrefix $trimmed';
        final added = commentPrefix.length + 1;
        totalDelta += added;
        if (i == startLine) firstLineDelta = added;
      }
    }

    final newText = lines.join('\n');
    _controller.removeListener(_onTextChanged);
    _controller.text = newText;
    _controller.selection = TextSelection(
      baseOffset: (selection.start + firstLineDelta).clamp(0, newText.length),
      extentOffset: (selection.end + totalDelta).clamp(0, newText.length),
    );
    _controller.addListener(_onTextChanged);
    _onTextChanged();
  }

  String? _getCommentPrefix(String languageId) {
    switch (languageId) {
      case 'python':
      case 'shellscript':
      case 'yaml':
      case 'r':
        return '#';
      case 'html':
      case 'xml':
        return null; // Block comment only, skip for now
      case 'css':
      case 'scss':
      case 'sass':
      case 'less':
        return '//';
      case 'sql':
        return '--';
      case 'lua':
        return '--';
      default:
        return '//';
    }
  }

  /// Select entire current line (Ctrl+L)
  void _selectLine() {
    final text = _controller.text;
    final selection = _controller.selection;
    if (!selection.isValid) return;

    final cursor = selection.baseOffset.clamp(0, text.length);
    final lines = text.split('\n');
    final textBefore = text.substring(0, cursor);
    final lineIndex = textBefore.split('\n').length - 1;

    if (lineIndex >= lines.length) return;

    // Calculate start of this line
    int lineStart = 0;
    for (int i = 0; i < lineIndex; i++) {
      lineStart += lines[i].length + 1;
    }
    // End of this line (include newline if not last)
    int lineEnd = lineStart + lines[lineIndex].length;
    if (lineIndex < lines.length - 1) lineEnd += 1;

    _controller.selection = TextSelection(
      baseOffset: lineStart,
      extentOffset: lineEnd.clamp(0, text.length),
    );
  }

  /// Move current line up (Alt+Up)
  void _moveLineUp() {
    final text = _controller.text;
    final selection = _controller.selection;
    if (!selection.isValid) return;

    final cursor = selection.baseOffset.clamp(0, text.length);
    final lines = text.split('\n');
    final textBefore = text.substring(0, cursor);
    final lineIndex = textBefore.split('\n').length - 1;

    if (lineIndex <= 0 || lineIndex >= lines.length) return;

    // Swap current line with the one above
    final temp = lines[lineIndex];
    lines[lineIndex] = lines[lineIndex - 1];
    lines[lineIndex - 1] = temp;

    final newText = lines.join('\n');

    // Calculate new cursor position (same column, one line up)
    final colInLine = cursor - textBefore.lastIndexOf('\n') - 1;
    int newLineStart = 0;
    for (int i = 0; i < lineIndex - 1; i++) {
      newLineStart += lines[i].length + 1;
    }
    final newCursor = (newLineStart + colInLine).clamp(0, newText.length);

    _controller.removeListener(_onTextChanged);
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(offset: newCursor);
    _controller.addListener(_onTextChanged);
    _onTextChanged();
  }

  /// Move current line down (Alt+Down)
  void _moveLineDown() {
    final text = _controller.text;
    final selection = _controller.selection;
    if (!selection.isValid) return;

    final cursor = selection.baseOffset.clamp(0, text.length);
    final lines = text.split('\n');
    final textBefore = text.substring(0, cursor);
    final lineIndex = textBefore.split('\n').length - 1;

    if (lineIndex >= lines.length - 1) return;

    // Swap current line with the one below
    final temp = lines[lineIndex];
    lines[lineIndex] = lines[lineIndex + 1];
    lines[lineIndex + 1] = temp;

    final newText = lines.join('\n');

    // Calculate new cursor position (same column, one line down)
    final colInLine = cursor - textBefore.lastIndexOf('\n') - 1;
    int newLineStart = 0;
    for (int i = 0; i < lineIndex + 1; i++) {
      newLineStart += lines[i].length + 1;
    }
    final newCursor = (newLineStart + colInLine).clamp(0, newText.length);

    _controller.removeListener(_onTextChanged);
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(offset: newCursor);
    _controller.addListener(_onTextChanged);
    _onTextChanged();
  }

  /// Delete current line (Ctrl+Shift+K)
  void _deleteLine() {
    final text = _controller.text;
    final selection = _controller.selection;
    if (!selection.isValid) return;

    final cursor = selection.baseOffset.clamp(0, text.length);
    final lines = text.split('\n');
    final textBefore = text.substring(0, cursor);
    final lineIndex = textBefore.split('\n').length - 1;

    if (lineIndex >= lines.length) return;

    lines.removeAt(lineIndex);

    // If we removed the only line, leave an empty line
    if (lines.isEmpty) lines.add('');

    final newText = lines.join('\n');

    // Place cursor at start of the same line index (or last line)
    final targetLine = lineIndex.clamp(0, lines.length - 1);
    int newCursor = 0;
    for (int i = 0; i < targetLine; i++) {
      newCursor += lines[i].length + 1;
    }
    newCursor = newCursor.clamp(0, newText.length);

    _controller.removeListener(_onTextChanged);
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(offset: newCursor);
    _controller.addListener(_onTextChanged);
    _onTextChanged();
  }

  /// Select all occurrences of current word/selection (Ctrl+Shift+L).
  /// Opens the find bar pre-filled with the word/selection for easy replace-all.
  void _selectAllOccurrences() {
    final text = _controller.text;
    final selection = _controller.selection;
    if (!selection.isValid) return;

    String searchTerm;
    if (!selection.isCollapsed) {
      searchTerm = selection.textInside(text);
    } else {
      // Get word under cursor
      final cursor = selection.baseOffset.clamp(0, text.length);
      final wordPattern = RegExp(r'[a-zA-Z_$][a-zA-Z0-9_$]*');
      String? word;
      for (final match in wordPattern.allMatches(text)) {
        if (match.start <= cursor && match.end >= cursor) {
          word = match.group(0);
          break;
        }
      }
      if (word == null || word.isEmpty) return;
      searchTerm = word;
    }

    if (searchTerm.isEmpty) return;

    // Open find bar with the search term pre-filled
    _findController.text = searchTerm;
    setState(() {
      _showFindBar = true;
      _showReplace = true;
    });
    _performFind();

    // Select the first occurrence
    if (_findMatches.isNotEmpty) {
      _currentMatchIndex = 0;
      final match = _findMatches[0];
      _controller.selection = TextSelection(
        baseOffset: match.start,
        extentOffset: match.end,
      );
    }
  }

  /// Manually trigger auto-complete (Ctrl+Space)
  void _manualTriggerAutoComplete() {
    final tabState = ref.read(tabProvider);
    final activeTab = tabState.activeTab;
    if (activeTab == null) return;

    final text = _controller.text;
    final selection = _controller.selection;
    if (!selection.isValid || !selection.isCollapsed) return;

    final cursor = selection.baseOffset;
    final prefix = AutoCompleteService.getCurrentPrefix(text, cursor);

    if (prefix == null) {
      _removeOverlay();
      return;
    }

    final wordSuggestions = AutoCompleteService.getSuggestions(
      text: text,
      prefix: prefix,
      languageId: activeTab.languageId,
      cursorOffset: cursor,
    );

    if (wordSuggestions.isEmpty) {
      _removeOverlay();
    } else {
      setState(() {
        _suggestions = wordSuggestions;
        _selectedSuggestion = 0;
      });
      _showOrUpdateOverlay();
    }

    // Also request LSP completions asynchronously
    _requestLspCompletions(activeTab, text, cursor, prefix, wordSuggestions);
  }

  /// Handle mouse hover in the editor — request LSP hover info after a delay.
  void _onEditorHover(Offset localPosition) {
    _hoverDebounce?.cancel();
    _removeHoverOverlay();

    _hoverDebounce = Timer(const Duration(milliseconds: 500), () {
      _requestLspHover(localPosition);
    });
  }

  void _onEditorHoverExit() {
    _hoverDebounce?.cancel();
    _removeHoverOverlay();
  }

  Future<void> _requestLspHover(Offset localPosition) async {
    final tabState = ref.read(tabProvider);
    final activeTab = tabState.activeTab;
    if (activeTab == null || activeTab.filePath.startsWith('untitled')) return;

    final lspState = ref.read(lspProvider);
    final client = lspState.clients[activeTab.languageId];
    if (client == null || !client.isRunning) return;

    final settings = ref.read(settingsProvider);
    final lineHeight = settings.fontSize * 1.6;
    final charWidth = settings.fontSize * 0.6;
    final scrollOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;

    // Convert pixel position to line/character
    final line = ((localPosition.dy + scrollOffset - 8) / lineHeight).floor();
    final character = ((localPosition.dx - 8) / charWidth).floor();

    if (line < 0 || character < 0) return;

    final result = await ref.read(lspProvider.notifier).getHover(
      activeTab.filePath,
      activeTab.languageId,
      line,
      character,
    );

    if (result == null || !mounted) return;

    // Extract hover content
    final contents = result['contents'];
    String? hoverText;

    if (contents is Map) {
      hoverText = contents['value'] as String?;
    } else if (contents is String) {
      hoverText = contents;
    } else if (contents is List && contents.isNotEmpty) {
      final first = contents.first;
      if (first is Map) {
        hoverText = first['value'] as String?;
      } else if (first is String) {
        hoverText = first;
      }
    }

    if (hoverText == null || hoverText.trim().isEmpty) return;
    if (!mounted) return;

    _hoverContent = hoverText;
    _hoverPosition = localPosition;
    _showHoverOverlay();
  }

  void _showHoverOverlay() {
    _removeHoverOverlay();
    if (_hoverContent == null) return;

    final colors = ref.read(themeColorsProvider);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final globalPos = renderBox.localToGlobal(_hoverPosition);

    _hoverOverlay = OverlayEntry(
      builder: (context) => Positioned(
        left: globalPos.dx.clamp(8.0, MediaQuery.of(context).size.width - 400),
        top: globalPos.dy - 40,
        child: _HoverTooltip(
          content: _hoverContent!,
          colors: colors,
        ),
      ),
    );
    Overlay.of(context).insert(_hoverOverlay!);
  }

  /// Go to definition at the current cursor position (F12)
  Future<void> _goToDefinition() async {
    final tabState = ref.read(tabProvider);
    final activeTab = tabState.activeTab;
    if (activeTab == null || activeTab.filePath.startsWith('untitled')) return;

    final lspState = ref.read(lspProvider);
    final client = lspState.clients[activeTab.languageId];
    if (client == null || !client.isRunning) return;

    final text = _controller.text;
    final selection = _controller.selection;
    if (!selection.isValid) return;

    final cursor = selection.baseOffset.clamp(0, text.length);
    final textBefore = text.substring(0, cursor);
    final line = textBefore.split('\n').length - 1;
    final lastNewline = textBefore.lastIndexOf('\n');
    final character = lastNewline == -1 ? cursor : cursor - lastNewline - 1;

    final result = await ref.read(lspProvider.notifier).getDefinition(
      activeTab.filePath,
      activeTab.languageId,
      line,
      character,
    );

    if (result == null || result.isEmpty || !mounted) return;

    // Parse the first definition location
    final loc = result.first;
    if (loc is! Map) return;

    String? targetUri = loc['uri'] as String?;
    final range = loc['range'] as Map<String, dynamic>?;

    if (targetUri == null) return;

    // Strip file:// prefix
    if (targetUri.startsWith('file://')) {
      targetUri = targetUri.substring(7);
    }

    final targetLine = range?['start']?['line'] as int? ?? 0;
    final fileName = targetUri.split('/').last;

    // Open the file
    await ref.read(tabProvider.notifier).openFile(targetUri, fileName);

    // Navigate to the target line after the file is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _goToLine(targetLine + 1); // _goToLine is 1-indexed
    });
  }

  /// Go to definition at a specific mouse position (Ctrl+Click)
  Future<void> _goToDefinitionAtPosition(Offset localPosition) async {
    final tabState = ref.read(tabProvider);
    final activeTab = tabState.activeTab;
    if (activeTab == null || activeTab.filePath.startsWith('untitled')) return;

    final lspState = ref.read(lspProvider);
    final client = lspState.clients[activeTab.languageId];
    if (client == null || !client.isRunning) return;

    final settings = ref.read(settingsProvider);
    final lineHeight = settings.fontSize * 1.6;
    final charWidth = settings.fontSize * 0.6;
    final scrollOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;

    // Convert pixel position to line/character
    final line = ((localPosition.dy + scrollOffset - 8) / lineHeight).floor();
    final character = ((localPosition.dx - 8) / charWidth).floor();

    if (line < 0 || character < 0) return;

    final result = await ref.read(lspProvider.notifier).getDefinition(
      activeTab.filePath,
      activeTab.languageId,
      line,
      character,
    );

    if (result == null || result.isEmpty || !mounted) return;

    final loc = result.first;
    if (loc is! Map) return;

    String? targetUri = loc['uri'] as String?;
    final range = loc['range'] as Map<String, dynamic>?;

    if (targetUri == null) return;

    if (targetUri.startsWith('file://')) {
      targetUri = targetUri.substring(7);
    }

    final targetLine = range?['start']?['line'] as int? ?? 0;
    final fileName = targetUri.split('/').last;

    await ref.read(tabProvider.notifier).openFile(targetUri, fileName);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _goToLine(targetLine + 1);
    });
  }

  void _removeHoverOverlay() {
    _hoverOverlay?.remove();
    _hoverOverlay = null;
    _hoverContent = null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeColorsProvider);
    final tokenColors = ref.watch(tokenColorsProvider);
    final tabState = ref.watch(tabProvider);
    final settings = ref.watch(settingsProvider);
    final lspState = ref.watch(lspProvider);
    final activeTab = tabState.activeTab;

    if (activeTab == null) {
      return const SizedBox.shrink();
    }

    // Sync controller with tab content when switching tabs
    if (_lastSyncedTabId != activeTab.id) {
      _lastSyncedTabId = activeTab.id;
      _lspDocVersion = 1;
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

          // Notify LSP that this document is now open
          if (!activeTab.filePath.startsWith('untitled')) {
            ref.read(lspProvider.notifier).didOpenDocument(
              activeTab.filePath,
              activeTab.languageId,
              activeTab.content,
            );
          }
        }
      });
    }

    // Update the highlighter on every build so colors and language stay in sync
    final highlighter = SyntaxHighlighter(tokenColors);
    _controller.updateHighlighter(highlighter, activeTab.languageId);
    final lineCount = activeTab.content.split('\n').length;

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        if (_handleAutoCompleteKey(event)) {
          // Consumed by auto-complete
        }
      },
      child: CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): _toggleFindBar,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          final tab = ref.read(tabProvider).activeTab;
          ref.read(tabProvider.notifier).saveActiveTab().then((_) {
            if (tab != null && !tab.filePath.startsWith('untitled')) {
              ref.read(lspProvider.notifier).didSaveDocument(
                tab.filePath,
                tab.languageId,
                _controller.text,
              );
            }
          });
        },
        const SingleActivator(LogicalKeyboardKey.keyG, control: true): _toggleGoToLine,
        const SingleActivator(LogicalKeyboardKey.keyD, control: true): _duplicateLine,
        const SingleActivator(LogicalKeyboardKey.slash, control: true): _toggleComment,
        const SingleActivator(LogicalKeyboardKey.keyL, control: true): _selectLine,
        const SingleActivator(LogicalKeyboardKey.tab): () {
          if (_suggestions.isNotEmpty) {
            _acceptSuggestion();
          } else {
            _handleTab();
          }
        },
        const SingleActivator(LogicalKeyboardKey.tab, shift: true): _handleShiftTab,
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_suggestions.isNotEmpty) {
            _removeOverlay();
          } else if (_showGoToLine) {
            _toggleGoToLine();
          } else if (_showFindBar) {
            _toggleFindBar();
          }
        },
        // Ctrl+Space: manually trigger auto-complete
        const SingleActivator(LogicalKeyboardKey.space, control: true): _manualTriggerAutoComplete,
        // Alt+Up: move line up
        const SingleActivator(LogicalKeyboardKey.arrowUp, alt: true): _moveLineUp,
        // Alt+Down: move line down
        const SingleActivator(LogicalKeyboardKey.arrowDown, alt: true): _moveLineDown,
        // Ctrl+Shift+K: delete line
        const SingleActivator(LogicalKeyboardKey.keyK, control: true, shift: true): _deleteLine,
        // Ctrl+Shift+L: select all occurrences
        const SingleActivator(LogicalKeyboardKey.keyL, control: true, shift: true): _selectAllOccurrences,
        // F12: Go to definition
        const SingleActivator(LogicalKeyboardKey.f12): _goToDefinition,
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

              // Go-to-line bar
              if (_showGoToLine)
                _GoToLineBar(
                  controller: _goToLineController,
                  focusNode: _goToLineFocusNode,
                  colors: colors,
                  lineCount: lineCount,
                  onSubmit: (line) => _goToLine(line),
                  onClose: _toggleGoToLine,
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
                      child: Listener(
                        onPointerDown: (event) {
                          // Ctrl+Click: go to definition
                          if (event.buttons == 1 &&
                              (HardwareKeyboard.instance.logicalKeysPressed
                                  .contains(LogicalKeyboardKey.controlLeft) ||
                               HardwareKeyboard.instance.logicalKeysPressed
                                  .contains(LogicalKeyboardKey.controlRight))) {
                            _goToDefinitionAtPosition(event.localPosition);
                          }
                        },
                        child: MouseRegion(
                          onHover: (event) => _onEditorHover(event.localPosition),
                          onExit: (_) => _onEditorHoverExit(),
                          child: CompositedTransformTarget(
                            link: _layerLink,
                            child: _HighlightedEditor(
                              controller: _controller,
                              focusNode: _focusNode,
                              scrollController: _scrollController,
                              settings: settings,
                              colors: colors,
                              currentLine: _currentLine,
                              onTap: _updateCursorPosition,
                              diagnostics: activeTab.filePath.startsWith('untitled')
                                  ? const []
                                  : lspState.getDiagnosticsForFile(activeTab.filePath),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Minimap
                    if (settings.minimap)
                      _Minimap(
                        content: activeTab.content,
                        colors: colors,
                        currentLine: _currentLine,
                        lineCount: lineCount,
                        scrollController: _scrollController,
                        fontSize: settings.fontSize,
                      ),
                  ],
                ),
              ),
            ],
          ),
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

/// Minimap — a scaled-down overview of the code, shown on the right side.
/// Uses a CustomPainter to render tiny lines representing code content.
class _Minimap extends StatefulWidget {
  final String content;
  final ThemeColors colors;
  final int currentLine;
  final int lineCount;
  final ScrollController scrollController;
  final double fontSize;

  const _Minimap({
    required this.content,
    required this.colors,
    required this.currentLine,
    required this.lineCount,
    required this.scrollController,
    required this.fontSize,
  });

  @override
  State<_Minimap> createState() => _MinimapState();
}

class _MinimapState extends State<_Minimap> {
  double _scrollFraction = 0.0;
  double _viewportFraction = 1.0;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant _Minimap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScroll);
      widget.scrollController.addListener(_onScroll);
    }
    // Recompute on content change
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onScroll();
    });
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!widget.scrollController.hasClients) return;
    final pos = widget.scrollController.position;
    final maxScroll = pos.maxScrollExtent;
    final viewportHeight = pos.viewportDimension;
    final contentHeight = maxScroll + viewportHeight;

    setState(() {
      _scrollFraction = maxScroll > 0 ? pos.pixels / maxScroll : 0.0;
      _viewportFraction =
          contentHeight > 0 ? viewportHeight / contentHeight : 1.0;
    });
  }

  void _onMinimapTap(double dy, double minimapHeight) {
    if (!widget.scrollController.hasClients) return;
    final pos = widget.scrollController.position;
    final maxScroll = pos.maxScrollExtent;
    if (maxScroll <= 0) return;

    // Map tap position to scroll offset
    final fraction = (dy / minimapHeight).clamp(0.0, 1.0);
    final target = fraction * maxScroll;
    widget.scrollController.jumpTo(target.clamp(0.0, maxScroll));
  }

  @override
  Widget build(BuildContext context) {
    const minimapWidth = 60.0;

    return Container(
      width: minimapWidth,
      color: widget.colors.editorBackground,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final minimapHeight = constraints.maxHeight;

          return GestureDetector(
            onTapDown: (details) {
              _onMinimapTap(details.localPosition.dy, minimapHeight);
            },
            onVerticalDragUpdate: (details) {
              _onMinimapTap(details.localPosition.dy, minimapHeight);
            },
            child: CustomPaint(
              size: Size(minimapWidth, minimapHeight),
              painter: _MinimapPainter(
                content: widget.content,
                lineCount: widget.lineCount,
                currentLine: widget.currentLine,
                scrollFraction: _scrollFraction,
                viewportFraction: _viewportFraction,
                foregroundColor: widget.colors.editorForeground,
                highlightColor: widget.colors.editorLineHighlight,
                viewportColor: widget.colors.scrollbarThumb,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MinimapPainter extends CustomPainter {
  final String content;
  final int lineCount;
  final int currentLine;
  final double scrollFraction;
  final double viewportFraction;
  final Color foregroundColor;
  final Color highlightColor;
  final Color viewportColor;

  _MinimapPainter({
    required this.content,
    required this.lineCount,
    required this.currentLine,
    required this.scrollFraction,
    required this.viewportFraction,
    required this.foregroundColor,
    required this.highlightColor,
    required this.viewportColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (lineCount == 0) return;

    // Each line gets a tiny height
    const lineHeight = 2.5;
    const lineGap = 0.5;
    final totalCodeHeight = lineCount * (lineHeight + lineGap);

    // Scale factor if code is taller than minimap
    final scale = totalCodeHeight > size.height
        ? size.height / totalCodeHeight
        : 1.0;
    final scaledLineHeight = lineHeight * scale;
    final scaledLineGap = lineGap * scale;

    final lines = content.split('\n');

    // Draw viewport indicator
    final viewportHeight = (viewportFraction * size.height).clamp(10.0, size.height);
    final maxViewportTop = size.height - viewportHeight;
    final viewportTop = scrollFraction * maxViewportTop;

    final viewportPaint = Paint()
      ..color = viewportColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, viewportTop, size.width, viewportHeight),
        const Radius.circular(2),
      ),
      viewportPaint,
    );

    // Draw viewport border
    final viewportBorderPaint = Paint()
      ..color = viewportColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, viewportTop, size.width, viewportHeight),
        const Radius.circular(2),
      ),
      viewportBorderPaint,
    );

    // Draw code lines
    final linePaint = Paint()
      ..style = PaintingStyle.fill;

    for (int i = 0; i < lines.length && i < lineCount; i++) {
      final line = lines[i];
      final y = i * (scaledLineHeight + scaledLineGap);
      if (y > size.height) break;

      if (line.trim().isEmpty) continue;

      // Calculate indent and content length
      final trimmed = line.trimLeft();
      final indent = line.length - trimmed.length;
      final contentLen = trimmed.length;

      // Scale x positions: each char ~1.2px wide in minimap
      const charWidth = 1.2;
      final x = (indent * charWidth + 4).clamp(4.0, size.width - 4);
      final w = (contentLen * charWidth).clamp(2.0, size.width - x - 2);

      // Current line highlight
      if (i + 1 == currentLine) {
        linePaint.color = highlightColor;
        canvas.drawRect(
          Rect.fromLTWH(0, y, size.width, scaledLineHeight),
          linePaint,
        );
      }

      // Draw the minimap line
      linePaint.color = foregroundColor.withValues(alpha: 0.25);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, scaledLineHeight),
          const Radius.circular(0.5),
        ),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MinimapPainter oldDelegate) {
    return content != oldDelegate.content ||
        lineCount != oldDelegate.lineCount ||
        currentLine != oldDelegate.currentLine ||
        scrollFraction != oldDelegate.scrollFraction ||
        viewportFraction != oldDelegate.viewportFraction;
  }
}

/// Editor with syntax-aware text rendering
class _HighlightedEditor extends StatelessWidget {
  final HighlightedTextController controller;
  final FocusNode focusNode;
  final ScrollController scrollController;
  final SettingsState settings;
  final ThemeColors colors;
  final int currentLine;
  final VoidCallback onTap;
  final List<LspDiagnostic> diagnostics;

  const _HighlightedEditor({
    required this.controller,
    required this.focusNode,
    required this.scrollController,
    required this.settings,
    required this.colors,
    required this.currentLine,
    required this.onTap,
    this.diagnostics = const [],
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontSize: settings.fontSize,
      fontFamily: 'JetBrainsMono',
      color: colors.editorForeground,
      height: 1.6,
    );

    final textField = TextField(
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
      inputFormatters: [
        AutoEditFormatter(
          autoCloseBrackets: settings.autoCloseBrackets,
          tabSize: settings.tabSize,
          insertSpaces: settings.insertSpaces,
        ),
      ],
      selectionControls: MaterialTextSelectionControls(),
      onTap: onTap,
    );

    // Always use a Stack so we can layer diagnostics and indent guides
    return Stack(
      children: [
        // Indent guides layer
        if (settings.indentGuides)
          Positioned.fill(
            child: ListenableBuilder(
              listenable: Listenable.merge([controller, scrollController]),
              builder: (context, _) {
                return CustomPaint(
                  painter: _IndentGuidePainter(
                    content: controller.text,
                    tabSize: settings.tabSize,
                    fontSize: settings.fontSize,
                    lineHeight: settings.fontSize * 1.6,
                    scrollOffset: scrollController.hasClients
                        ? scrollController.offset
                        : 0.0,
                    guideColor: colors.editorLineNumberForeground
                        .withValues(alpha: 0.15),
                    contentPaddingLeft: 8.0,
                    contentPaddingTop: 8.0,
                  ),
                );
              },
            ),
          ),
        // Text field
        textField,
        // Diagnostic underlines layer (on top of text)
        if (diagnostics.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: ListenableBuilder(
                listenable: Listenable.merge([controller, scrollController]),
                builder: (context, _) {
                  return CustomPaint(
                    painter: _DiagnosticPainter(
                      diagnostics: diagnostics,
                      content: controller.text,
                      fontSize: settings.fontSize,
                      lineHeight: settings.fontSize * 1.6,
                      scrollOffset: scrollController.hasClients
                          ? scrollController.offset
                          : 0.0,
                      errorColor: colors.error,
                      warningColor: colors.warning,
                      infoColor: colors.primary,
                      contentPaddingLeft: 8.0,
                      contentPaddingTop: 8.0,
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// Paints vertical indent guide lines behind the editor text.
class _IndentGuidePainter extends CustomPainter {
  final String content;
  final int tabSize;
  final double fontSize;
  final double lineHeight;
  final double scrollOffset;
  final Color guideColor;
  final double contentPaddingLeft;
  final double contentPaddingTop;

  _IndentGuidePainter({
    required this.content,
    required this.tabSize,
    required this.fontSize,
    required this.lineHeight,
    required this.scrollOffset,
    required this.guideColor,
    required this.contentPaddingLeft,
    required this.contentPaddingTop,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (content.isEmpty || tabSize <= 0) return;

    final lines = content.split('\n');
    // Approximate char width for monospace font
    final charWidth = fontSize * 0.6;
    final indentWidth = tabSize * charWidth;

    final paint = Paint()
      ..color = guideColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Calculate visible line range
    final firstVisibleLine = (scrollOffset / lineHeight).floor();
    final visibleLines = (size.height / lineHeight).ceil() + 2;
    final lastVisibleLine = (firstVisibleLine + visibleLines)
        .clamp(0, lines.length);

    for (int i = firstVisibleLine; i < lastVisibleLine; i++) {
      if (i < 0 || i >= lines.length) continue;

      final line = lines[i];
      if (line.isEmpty) continue;

      // Count indent level
      int spaces = 0;
      for (int j = 0; j < line.length; j++) {
        if (line[j] == ' ') {
          spaces++;
        } else if (line[j] == '\t') {
          spaces += tabSize;
        } else {
          break;
        }
      }

      final indentLevels = spaces ~/ tabSize;
      if (indentLevels <= 0) continue;

      final y = contentPaddingTop + i * lineHeight - scrollOffset;

      for (int level = 1; level <= indentLevels; level++) {
        final x = contentPaddingLeft + (level - 1) * indentWidth +
            indentWidth * 0.5;
        canvas.drawLine(
          Offset(x, y),
          Offset(x, y + lineHeight),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _IndentGuidePainter oldDelegate) {
    return content != oldDelegate.content ||
        tabSize != oldDelegate.tabSize ||
        fontSize != oldDelegate.fontSize ||
        scrollOffset != oldDelegate.scrollOffset;
  }
}

/// Paints wavy underlines for LSP diagnostics (errors, warnings, etc.)
class _DiagnosticPainter extends CustomPainter {
  final List<LspDiagnostic> diagnostics;
  final String content;
  final double fontSize;
  final double lineHeight;
  final double scrollOffset;
  final Color errorColor;
  final Color warningColor;
  final Color infoColor;
  final double contentPaddingLeft;
  final double contentPaddingTop;

  _DiagnosticPainter({
    required this.diagnostics,
    required this.content,
    required this.fontSize,
    required this.lineHeight,
    required this.scrollOffset,
    required this.errorColor,
    required this.warningColor,
    required this.infoColor,
    required this.contentPaddingLeft,
    required this.contentPaddingTop,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (diagnostics.isEmpty || content.isEmpty) return;

    final charWidth = fontSize * 0.6;
    final lines = content.split('\n');

    // Calculate visible line range
    final firstVisibleLine = (scrollOffset / lineHeight).floor();
    final visibleLines = (size.height / lineHeight).ceil() + 2;
    final lastVisibleLine = (firstVisibleLine + visibleLines)
        .clamp(0, lines.length);

    for (final diag in diagnostics) {
      final diagLine = diag.startLine;
      // Skip if diagnostic is outside visible range
      if (diagLine < firstVisibleLine || diagLine >= lastVisibleLine) continue;
      if (diagLine >= lines.length) continue;

      // Determine underline color based on severity
      Color color;
      if (diag.isError) {
        color = errorColor;
      } else if (diag.isWarning) {
        color = warningColor;
      } else {
        color = infoColor;
      }

      final startChar = diag.startCharacter;
      int endChar = diag.endCharacter;

      // If start == end (zero-width), underline the whole token/word or at least a few chars
      if (endChar <= startChar) {
        endChar = startChar + 1;
        // Try to extend to end of word
        final line = lines[diagLine];
        int e = startChar;
        while (e < line.length && _isWordChar(line.codeUnitAt(e))) {
          e++;
        }
        if (e > startChar) endChar = e;
      }

      final y = contentPaddingTop + diagLine * lineHeight - scrollOffset +
          lineHeight - 3; // Position near bottom of line
      final x1 = contentPaddingLeft + startChar * charWidth;
      final x2 = contentPaddingLeft + endChar * charWidth;
      final width = (x2 - x1).clamp(charWidth, size.width - x1);

      _drawWavyLine(canvas, x1, y, width, color);
    }
  }

  bool _isWordChar(int c) {
    return (c >= 65 && c <= 90) ||  // A-Z
        (c >= 97 && c <= 122) ||    // a-z
        (c >= 48 && c <= 57) ||     // 0-9
        c == 95;                     // _
  }

  /// Draw a wavy (squiggly) underline
  void _drawWavyLine(Canvas canvas, double x, double y, double width, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final path = Path();
    const waveHeight = 2.0;
    const waveLength = 4.0;
    path.moveTo(x, y);

    double cx = x;
    bool up = true;
    while (cx < x + width) {
      final nextX = (cx + waveLength / 2).clamp(x, x + width);
      final peakY = up ? y - waveHeight : y + waveHeight;
      path.quadraticBezierTo(cx + waveLength / 4, peakY, nextX, y);
      cx = nextX;
      up = !up;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DiagnosticPainter oldDelegate) {
    return diagnostics != oldDelegate.diagnostics ||
        content != oldDelegate.content ||
        fontSize != oldDelegate.fontSize ||
        scrollOffset != oldDelegate.scrollOffset;
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

/// Go-to-line bar (Ctrl+G)
class _GoToLineBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ThemeColors colors;
  final int lineCount;
  final ValueChanged<int> onSubmit;
  final VoidCallback onClose;

  const _GoToLineBar({
    required this.controller,
    required this.focusNode,
    required this.colors,
    required this.lineCount,
    required this.onSubmit,
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
      child: Row(
        children: [
          Text(
            'Go to Line:',
            style: TextStyle(
              color: colors.foreground.withValues(alpha: 0.7),
              fontSize: 12,
              fontFamily: 'JetBrainsMono',
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            height: 26,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: TextInputType.number,
              onSubmitted: (value) {
                final line = int.tryParse(value);
                if (line != null && line > 0) {
                  onSubmit(line);
                }
              },
              style: TextStyle(
                color: colors.inputForeground,
                fontSize: 12,
                fontFamily: 'JetBrainsMono',
              ),
              decoration: InputDecoration(
                hintText: '1-$lineCount',
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
          const SizedBox(width: 8),
          Text(
            '($lineCount lines)',
            style: TextStyle(
              color: colors.foreground.withValues(alpha: 0.4),
              fontSize: 11,
              fontFamily: 'JetBrainsMono',
            ),
          ),
          const Spacer(),
          _SmallIconBtn(
            icon: Icons.close,
            onTap: onClose,
            color: colors.foreground,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
}

/// Auto-complete popup overlay
class _AutoCompletePopup extends StatelessWidget {
  final List<CompletionItem> suggestions;
  final int selectedIndex;
  final ThemeColors colors;
  final LayerLink layerLink;
  final ValueChanged<int> onSelect;

  const _AutoCompletePopup({
    required this.suggestions,
    required this.selectedIndex,
    required this.colors,
    required this.layerLink,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    final itemHeight = 26.0;
    final maxVisible = suggestions.length.clamp(1, 8);
    final popupHeight = maxVisible * itemHeight + 8; // +8 for padding

    return Positioned(
      width: 260,
      child: CompositedTransformFollower(
        link: layerLink,
        showWhenUnlinked: false,
        offset: const Offset(40, 30),
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(6),
          color: colors.surface,
          child: Container(
            constraints: BoxConstraints(maxHeight: popupHeight),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: suggestions.length,
                itemExtent: itemHeight,
                itemBuilder: (context, index) {
                  final item = suggestions[index];
                  final isSelected = index == selectedIndex;
                  final isLsp = item.kind != CompletionKind.keyword &&
                      item.kind != CompletionKind.word;
                  final badgeLabel = completionKindLabel(item.kind);
                  final kindDesc = completionKindDescription(item.kind);

                  return GestureDetector(
                    onTap: () => onSelect(index),
                    child: Container(
                      height: itemHeight,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      color: isSelected
                          ? colors.listActiveBackground
                          : Colors.transparent,
                      child: Row(
                        children: [
                          // Kind icon
                          Container(
                            width: 20,
                            height: 20,
                            alignment: Alignment.center,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: isLsp
                                  ? colors.success.withValues(alpha: 0.15)
                                  : item.kind == CompletionKind.keyword
                                      ? colors.primary.withValues(alpha: 0.15)
                                      : colors.foreground.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              badgeLabel,
                              style: TextStyle(
                                color: isLsp
                                    ? colors.success
                                    : item.kind == CompletionKind.keyword
                                        ? colors.primary
                                        : colors.foreground
                                            .withValues(alpha: 0.6),
                                fontSize: 10,
                                fontFamily: 'JetBrainsMono',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // Label
                          Expanded(
                            child: Text(
                              item.label,
                              style: TextStyle(
                                color: isSelected
                                    ? colors.foreground
                                    : colors.foreground
                                        .withValues(alpha: 0.85),
                                fontSize: 12,
                                fontFamily: 'JetBrainsMono',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Detail (from LSP) or kind label
                          Text(
                            item.detail ?? kindDesc,
                            style: TextStyle(
                              color:
                                  colors.foreground.withValues(alpha: 0.35),
                              fontSize: 10,
                              fontFamily: 'JetBrainsMono',
                            ),
                           ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hover tooltip overlay showing LSP hover info
class _HoverTooltip extends StatelessWidget {
  final String content;
  final ThemeColors colors;

  const _HoverTooltip({
    required this.content,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(6),
      color: colors.surface,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: colors.border),
        ),
        child: SingleChildScrollView(
          child: SelectableText(
            content,
            style: TextStyle(
              color: colors.foreground.withValues(alpha: 0.9),
              fontSize: 12,
              fontFamily: 'JetBrainsMono',
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}
