import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_ide/core/theme/theme_provider.dart';
import 'package:spark_ide/core/theme/spark_theme.dart';
import 'package:spark_ide/providers/tab_provider.dart';
import 'package:spark_ide/providers/file_tree_provider.dart';
import 'package:path/path.dart' as p;

/// Breadcrumb bar showing the current file's path segments
class BreadcrumbBar extends ConsumerWidget {
  const BreadcrumbBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeColorsProvider);
    final tabState = ref.watch(tabProvider);
    final fileTreeState = ref.watch(fileTreeProvider);
    final activeTab = tabState.activeTab;

    if (activeTab == null) return const SizedBox.shrink();

    final filePath = activeTab.filePath;

    // If the file is untitled, just show the name
    if (filePath.startsWith('untitled')) {
      return _buildContainer(colors, [
        _BreadcrumbSegment(
          label: activeTab.fileName,
          isLast: true,
          colors: colors,
        ),
      ]);
    }

    // Build relative path segments from project root
    final rootPath = fileTreeState.rootPath;
    String displayPath;
    if (rootPath != null && filePath.startsWith(rootPath)) {
      displayPath = p.relative(filePath, from: rootPath);
    } else {
      displayPath = filePath;
    }

    final segments = p.split(displayPath);

    return _buildContainer(
      colors,
      _buildSegments(segments, colors),
    );
  }

  Widget _buildContainer(ThemeColors colors, List<Widget> children) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.editorBackground,
        border: Border(
          bottom: BorderSide(
            color: colors.border.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: children),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSegments(List<String> segments, ThemeColors colors) {
    final widgets = <Widget>[];
    for (int i = 0; i < segments.length; i++) {
      final isLast = i == segments.length - 1;
      final isDirectory = !isLast;

      widgets.add(
        _BreadcrumbSegment(
          label: segments[i],
          isLast: isLast,
          isDirectory: isDirectory,
          colors: colors,
        ),
      );

      if (!isLast) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              Icons.chevron_right,
              size: 14,
              color: colors.foreground.withValues(alpha: 0.3),
            ),
          ),
        );
      }
    }
    return widgets;
  }
}

class _BreadcrumbSegment extends StatefulWidget {
  final String label;
  final bool isLast;
  final bool isDirectory;
  final ThemeColors colors;

  const _BreadcrumbSegment({
    required this.label,
    required this.isLast,
    this.isDirectory = false,
    required this.colors,
  });

  @override
  State<_BreadcrumbSegment> createState() => _BreadcrumbSegmentState();
}

class _BreadcrumbSegmentState extends State<_BreadcrumbSegment> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: _hovered
              ? widget.colors.listHoverBackground
              : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isDirectory) ...[
              Icon(
                Icons.folder,
                size: 13,
                color: widget.colors.foreground.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 3),
            ],
            Text(
              widget.label,
              style: TextStyle(
                color: widget.isLast
                    ? widget.colors.foreground
                    : widget.colors.foreground.withValues(alpha: 0.5),
                fontSize: 11,
                fontFamily: 'JetBrainsMono',
                fontWeight: widget.isLast ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
