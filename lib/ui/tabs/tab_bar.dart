import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_ide/core/constants/app_constants.dart';
import 'package:spark_ide/core/theme/theme_provider.dart';
import 'package:spark_ide/models/editor_tab.dart';
import 'package:spark_ide/providers/tab_provider.dart';

/// Tab bar for open editor tabs
class EditorTabBar extends ConsumerWidget {
  const EditorTabBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeColorsProvider);
    final tabState = ref.watch(tabProvider);

    if (!tabState.hasOpenTabs) return const SizedBox.shrink();

    return Container(
      height: AppSizes.tabBarHeight,
      color: colors.tabBarBackground,
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: tabState.tabs.length,
              itemBuilder: (context, index) {
                return _Tab(
                  tab: tabState.tabs[index],
                  isActive: index == tabState.activeIndex,
                  index: index,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends ConsumerStatefulWidget {
  final EditorTab tab;
  final bool isActive;
  final int index;

  const _Tab({
    required this.tab,
    required this.isActive,
    required this.index,
  });

  @override
  ConsumerState<_Tab> createState() => _TabState();
}

class _TabState extends ConsumerState<_Tab> {
  bool _isHovered = false;
  bool _isCloseHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeColorsProvider);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Listener(
        onPointerDown: (event) {
          // Middle mouse button click to close tab
          if (event.buttons == 4) {
            ref.read(tabProvider.notifier).closeTab(widget.index);
          }
        },
        child: GestureDetector(
        onTap: () => ref.read(tabProvider.notifier).setActiveTab(widget.index),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 200, minWidth: 80),
          decoration: BoxDecoration(
            color: widget.isActive
                ? colors.tabActiveBackground
                : _isHovered
                    ? colors.tabActiveBackground.withValues(alpha: 0.5)
                    : colors.tabBarBackground,
            border: Border(
              top: BorderSide(
                color: widget.isActive ? colors.tabActiveBorder : Colors.transparent,
                width: 2,
              ),
              right: BorderSide(
                color: colors.border.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // File icon
              _FileIcon(extension: widget.tab.extension),
              const SizedBox(width: 6),
              // File name
              Flexible(
                child: Text(
                  widget.tab.fileName,
                  style: TextStyle(
                    color: widget.isActive
                        ? colors.tabActiveForeground
                        : colors.tabInactiveForeground,
                    fontSize: 12,
                    fontStyle: widget.tab.isDirty ? FontStyle.italic : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              // Close / dirty indicator
              MouseRegion(
                onEnter: (_) => setState(() => _isCloseHovered = true),
                onExit: (_) => setState(() => _isCloseHovered = false),
                child: GestureDetector(
                  onTap: () =>
                      ref.read(tabProvider.notifier).closeTab(widget.index),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: Center(
                      child: widget.tab.isDirty && !_isHovered && !_isCloseHovered
                          ? Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors.foreground.withValues(alpha: 0.5),
                              ),
                            )
                          : (_isHovered || _isCloseHovered)
                              ? Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    color: _isCloseHovered
                                        ? colors.foreground.withValues(alpha: 0.1)
                                        : Colors.transparent,
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    size: 14,
                                    color: colors.foreground.withValues(alpha: 0.6),
                                  ),
                                )
                              : const SizedBox.shrink(),
                    ),
                  ),
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

class _FileIcon extends StatelessWidget {
  final String extension;

  const _FileIcon({required this.extension});

  @override
  Widget build(BuildContext context) {
    return Icon(
      _getIcon(),
      size: 14,
      color: _getColor(),
    );
  }

  IconData _getIcon() {
    switch (extension) {
      case '.html':
      case '.htm':
        return Icons.web;
      case '.css':
      case '.scss':
        return Icons.style;
      case '.json':
      case '.yaml':
      case '.yml':
        return Icons.settings;
      case '.md':
        return Icons.description;
      case '.png':
      case '.jpg':
      case '.jpeg':
      case '.gif':
        return Icons.image;
      case '.sql':
        return Icons.storage;
      default:
        return Icons.code;
    }
  }

  Color _getColor() {
    switch (extension) {
      case '.dart':
        return const Color(0xFF89B4FA);
      case '.py':
        return const Color(0xFFF9E2AF);
      case '.js':
      case '.jsx':
        return const Color(0xFFF9E2AF);
      case '.ts':
      case '.tsx':
        return const Color(0xFF89B4FA);
      case '.html':
      case '.htm':
        return const Color(0xFFF38BA8);
      case '.css':
      case '.scss':
        return const Color(0xFF89DCEB);
      case '.c':
      case '.cpp':
      case '.h':
        return const Color(0xFF89DCEB);
      case '.java':
        return const Color(0xFFFAB387);
      case '.go':
        return const Color(0xFF89DCEB);
      case '.rs':
        return const Color(0xFFFAB387);
      case '.sql':
        return const Color(0xFFF5C2E7);
      default:
        return const Color(0xFFBAC2DE);
    }
  }
}


