import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_ide/core/theme/theme_provider.dart';
import 'package:spark_ide/core/theme/spark_theme.dart';
import 'package:spark_ide/providers/file_tree_provider.dart';
import 'package:spark_ide/providers/tab_provider.dart';
import 'package:spark_ide/services/search/search_service.dart';

/// Search panel in the sidebar for searching across files
class SearchPanel extends ConsumerStatefulWidget {
  const SearchPanel({super.key});

  @override
  ConsumerState<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends ConsumerState<SearchPanel> {
  final _searchController = TextEditingController();
  final _replaceController = TextEditingController();
  final _searchService = SearchService();
  bool _showReplace = false;
  bool _caseSensitive = false;
  bool _wholeWord = false;
  bool _useRegex = false;
  List<FileSearchResult> _results = [];
  int _totalMatches = 0;
  bool _isSearching = false;
  Timer? _debounce;

  // Track which file groups are expanded
  final Set<String> _expandedFiles = {};

  @override
  void dispose() {
    _searchController.dispose();
    _replaceController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _performSearch);
  }

  Future<void> _performSearch() async {
    final query = _searchController.text;
    final rootPath = ref.read(fileTreeProvider).rootPath;

    if (query.isEmpty || rootPath == null) {
      setState(() {
        _results = [];
        _totalMatches = 0;
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    final results = await _searchService.search(
      rootPath: rootPath,
      query: query,
      caseSensitive: _caseSensitive,
      wholeWord: _wholeWord,
      useRegex: _useRegex,
    );

    if (!mounted) return;

    int total = 0;
    for (final r in results) {
      total += r.matchCount;
    }

    setState(() {
      _results = results;
      _totalMatches = total;
      _isSearching = false;
      // Auto-expand first few files
      _expandedFiles.clear();
      for (int i = 0; i < results.length && i < 5; i++) {
        _expandedFiles.add(results[i].filePath);
      }
    });
  }

  void _openFileAtMatch(SearchMatch match) {
    final fileName = match.fileName;
    ref.read(tabProvider.notifier).openFile(match.filePath, fileName);
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeColorsProvider);
    final hasProject = ref.watch(fileTreeProvider).rootPath != null;

    return Container(
      color: colors.sidebarBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            height: 35,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text(
                  'SEARCH',
                  style: TextStyle(
                    color: colors.sidebarForeground.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                if (_isSearching)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: colors.primary,
                    ),
                  ),
              ],
            ),
          ),

          // Search input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                // Search field
                Row(
                  children: [
                    // Toggle replace
                    GestureDetector(
                      onTap: () =>
                          setState(() => _showReplace = !_showReplace),
                      child: Icon(
                        _showReplace
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_right,
                        size: 16,
                        color: colors.sidebarForeground.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _SearchInput(
                        controller: _searchController,
                        placeholder: 'Search',
                        colors: colors,
                        onChanged: (_) => _onSearchChanged(),
                        onSubmitted: (_) => _performSearch(),
                        suffixIcons: [
                          _ToggleButton(
                            icon: Icons.text_fields,
                            tooltip: 'Match Case',
                            isActive: _caseSensitive,
                            color: colors,
                            onTap: () {
                              setState(
                                  () => _caseSensitive = !_caseSensitive);
                              _performSearch();
                            },
                          ),
                          _ToggleButton(
                            icon: Icons.abc,
                            tooltip: 'Match Whole Word',
                            isActive: _wholeWord,
                            color: colors,
                            onTap: () {
                              setState(() => _wholeWord = !_wholeWord);
                              _performSearch();
                            },
                          ),
                          _ToggleButton(
                            icon: Icons.data_object,
                            tooltip: 'Use Regular Expression',
                            isActive: _useRegex,
                            color: colors,
                            onTap: () {
                              setState(() => _useRegex = !_useRegex);
                              _performSearch();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Replace field
                if (_showReplace) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const SizedBox(width: 20),
                      Expanded(
                        child: _SearchInput(
                          controller: _replaceController,
                          placeholder: 'Replace',
                          colors: colors,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Results summary
          if (_searchController.text.isNotEmpty && !_isSearching)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                _totalMatches == 0
                    ? 'No results found'
                    : '$_totalMatches result${_totalMatches == 1 ? '' : 's'} in ${_results.length} file${_results.length == 1 ? '' : 's'}',
                style: TextStyle(
                  color: colors.sidebarForeground.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              ),
            ),

          if (!hasProject && _searchController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                'Open a folder to search across files.',
                style: TextStyle(
                  color: colors.sidebarForeground.withValues(alpha: 0.4),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

          const SizedBox(height: 4),

          // Results list — grouped by file
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemBuilder: (context, index) {
                final fileResult = _results[index];
                final isExpanded = _expandedFiles.contains(fileResult.filePath);

                return _FileResultGroup(
                  fileResult: fileResult,
                  isExpanded: isExpanded,
                  colors: colors,
                  query: _searchController.text,
                  onToggle: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedFiles.remove(fileResult.filePath);
                      } else {
                        _expandedFiles.add(fileResult.filePath);
                      }
                    });
                  },
                  onMatchTap: _openFileAtMatch,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A collapsible group of matches within one file
class _FileResultGroup extends StatelessWidget {
  final FileSearchResult fileResult;
  final bool isExpanded;
  final ThemeColors colors;
  final String query;
  final VoidCallback onToggle;
  final ValueChanged<SearchMatch> onMatchTap;

  const _FileResultGroup({
    required this.fileResult,
    required this.isExpanded,
    required this.colors,
    required this.query,
    required this.onToggle,
    required this.onMatchTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // File header
        _HoverableItem(
          colors: colors,
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: Row(
              children: [
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  size: 14,
                  color: colors.sidebarForeground.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.insert_drive_file,
                  size: 14,
                  color: colors.sidebarForeground.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    fileResult.fileName,
                    style: TextStyle(
                      color: colors.sidebarForeground,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                // Relative path
                Flexible(
                  child: Text(
                    fileResult.relativePath,
                    style: TextStyle(
                      color: colors.sidebarForeground.withValues(alpha: 0.35),
                      fontSize: 10,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                // Match count badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${fileResult.matchCount}',
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Individual matches (when expanded)
        if (isExpanded)
          ...fileResult.matches.map(
            (match) => _HoverableItem(
              colors: colors,
              onTap: () => onMatchTap(match),
              child: Padding(
                padding:
                    const EdgeInsets.only(left: 32, right: 8, top: 2, bottom: 2),
                child: _HighlightedMatchLine(
                  lineContent: match.lineContent,
                  matchStart: match.matchStart,
                  matchEnd: match.matchEnd,
                  lineNumber: match.line,
                  colors: colors,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Highlights the matched text within a line
class _HighlightedMatchLine extends StatelessWidget {
  final String lineContent;
  final int matchStart;
  final int matchEnd;
  final int lineNumber;
  final ThemeColors colors;

  const _HighlightedMatchLine({
    required this.lineContent,
    required this.matchStart,
    required this.matchEnd,
    required this.lineNumber,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = lineContent.trimLeft();
    final leftTrimCount = lineContent.length - trimmed.length;
    final adjustedStart = (matchStart - leftTrimCount).clamp(0, trimmed.length);
    final adjustedEnd = (matchEnd - leftTrimCount).clamp(0, trimmed.length);

    return Row(
      children: [
        // Line number
        SizedBox(
          width: 30,
          child: Text(
            '$lineNumber',
            style: TextStyle(
              color: colors.sidebarForeground.withValues(alpha: 0.3),
              fontSize: 11,
              fontFamily: 'JetBrainsMono',
            ),
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: 6),
        // Line content with highlighted match
        Expanded(
          child: RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: TextStyle(
                color: colors.sidebarForeground.withValues(alpha: 0.6),
                fontSize: 11,
                fontFamily: 'JetBrainsMono',
              ),
              children: [
                if (adjustedStart > 0)
                  TextSpan(text: trimmed.substring(0, adjustedStart)),
                if (adjustedStart < adjustedEnd)
                  TextSpan(
                    text: trimmed.substring(adjustedStart, adjustedEnd),
                    style: TextStyle(
                      color: colors.foreground,
                      backgroundColor: colors.primary.withValues(alpha: 0.3),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (adjustedEnd < trimmed.length)
                  TextSpan(text: trimmed.substring(adjustedEnd)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A widget that shows a hover highlight
class _HoverableItem extends StatefulWidget {
  final ThemeColors colors;
  final VoidCallback onTap;
  final Widget child;

  const _HoverableItem({
    required this.colors,
    required this.onTap,
    required this.child,
  });

  @override
  State<_HoverableItem> createState() => _HoverableItemState();
}

class _HoverableItemState extends State<_HoverableItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          color: _hovered
              ? widget.colors.listHoverBackground
              : Colors.transparent,
          child: widget.child,
        ),
      ),
    );
  }
}

class _SearchInput extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final ThemeColors colors;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final List<Widget>? suffixIcons;

  const _SearchInput({
    required this.controller,
    required this.placeholder,
    required this.colors,
    this.onChanged,
    this.onSubmitted,
    this.suffixIcons,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: colors.inputBackground,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colors.inputBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              style: TextStyle(
                color: colors.inputForeground,
                fontSize: 12,
                fontFamily: 'JetBrainsMono',
              ),
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: TextStyle(
                  color: colors.inputForeground.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                isCollapsed: true,
              ),
            ),
          ),
          if (suffixIcons != null) ...suffixIcons!,
          const SizedBox(width: 2),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final ThemeColors color;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: isActive
                ? color.primary.withValues(alpha: 0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Icon(
            icon,
            size: 14,
            color: isActive
                ? color.primary
                : color.foreground.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}
