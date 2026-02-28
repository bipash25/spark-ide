import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_ide/core/theme/theme_provider.dart';
import 'package:spark_ide/core/theme/spark_theme.dart';

/// Search panel in the sidebar for searching across files
class SearchPanel extends ConsumerStatefulWidget {
  const SearchPanel({super.key});

  @override
  ConsumerState<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends ConsumerState<SearchPanel> {
  final _searchController = TextEditingController();
  final _replaceController = TextEditingController();
  bool _showReplace = false;
  bool _caseSensitive = false;
  bool _wholeWord = false;
  bool _useRegex = false;
  List<_SearchResult> _results = [];

  @override
  void dispose() {
    _searchController.dispose();
    _replaceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeColorsProvider);

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
                        onChanged: (_) => _performSearch(),
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

          // Results
          if (_searchController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                _results.isEmpty
                    ? 'No results found'
                    : '${_results.length} result${_results.length == 1 ? '' : 's'} found',
                style: TextStyle(
                  color: colors.sidebarForeground.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              ),
            ),

          const SizedBox(height: 4),

          // Results list
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemExtent: 48,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemBuilder: (context, index) {
                final result = _results[index];
                return _SearchResultItem(result: result, colors: colors);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _performSearch() {
    // Placeholder - actual file search will be implemented with file system integration
    setState(() {
      _results = [];
    });
  }
}

class _SearchInput extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final ThemeColors colors;
  final ValueChanged<String>? onChanged;
  final List<Widget>? suffixIcons;

  const _SearchInput({
    required this.controller,
    required this.placeholder,
    required this.colors,
    this.onChanged,
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

class _SearchResult {
  final String filePath;
  final String fileName;
  final int line;
  final String lineContent;
  final int matchStart;
  final int matchEnd;

  const _SearchResult({
    required this.filePath,
    required this.fileName,
    required this.line,
    required this.lineContent,
    required this.matchStart,
    required this.matchEnd,
  });
}

class _SearchResultItem extends StatelessWidget {
  final _SearchResult result;
  final ThemeColors colors;

  const _SearchResultItem({
    required this.result,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            result.fileName,
            style: TextStyle(
              color: colors.sidebarForeground,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${result.line}: ${result.lineContent.trim()}',
            style: TextStyle(
              color: colors.sidebarForeground.withValues(alpha: 0.6),
              fontSize: 11,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
