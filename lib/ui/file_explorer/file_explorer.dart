import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_ide/core/constants/app_constants.dart';
import 'package:spark_ide/core/theme/theme_provider.dart';
import 'package:spark_ide/core/theme/spark_theme.dart';
import 'package:spark_ide/models/file_node.dart';
import 'package:spark_ide/providers/file_tree_provider.dart';
import 'package:spark_ide/providers/tab_provider.dart';
import 'package:file_picker/file_picker.dart';

/// File explorer sidebar panel
class FileExplorer extends ConsumerWidget {
  const FileExplorer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeColorsProvider);
    final fileTree = ref.watch(fileTreeProvider);

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
                  'EXPLORER',
                  style: TextStyle(
                    color: colors.sidebarForeground.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                _IconBtn(
                  icon: Icons.create_new_folder_outlined,
                  tooltip: 'Open Folder',
                  color: colors.sidebarForeground.withValues(alpha: 0.6),
                  onTap: () => _openFolder(ref),
                ),
                const SizedBox(width: 2),
                _IconBtn(
                  icon: Icons.refresh,
                  tooltip: 'Refresh',
                  color: colors.sidebarForeground.withValues(alpha: 0.6),
                  onTap: () => ref.read(fileTreeProvider.notifier).refresh(),
                ),
              ],
            ),
          ),
          // Tree content
          Expanded(
            child: fileTree.isLoading
                ? Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.primary,
                      ),
                    ),
                  )
                : fileTree.root == null
                    ? _EmptyState(onOpenFolder: () => _openFolder(ref))
                    : _FileTreeView(root: fileTree.root!),
          ),
        ],
      ),
    );
  }

  Future<void> _openFolder(WidgetRef ref) async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      await ref.read(fileTreeProvider.notifier).openFolder(result);
    }
  }
}

class _EmptyState extends ConsumerWidget {
  final VoidCallback onOpenFolder;

  const _EmptyState({required this.onOpenFolder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeColorsProvider);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_open,
              size: 48,
              color: colors.sidebarForeground.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'No folder opened',
              style: TextStyle(
                color: colors.sidebarForeground.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onOpenFolder,
              style: TextButton.styleFrom(
                backgroundColor: colors.buttonBackground,
                foregroundColor: colors.buttonForeground,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text('Open Folder', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileTreeView extends ConsumerWidget {
  final FileNode root;

  const _FileTreeView({required this.root});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flatList = _flatten(root, ref);

    return ListView.builder(
      itemCount: flatList.length,
      itemExtent: 24,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemBuilder: (context, index) {
        return _FileTreeItem(node: flatList[index]);
      },
    );
  }

  List<FileNode> _flatten(FileNode node, WidgetRef ref) {
    final result = <FileNode>[];
    final fileTree = ref.watch(fileTreeProvider);

    for (final child in node.children) {
      result.add(child);
      if (child.isDirectory && fileTree.expandedPaths.contains(child.path)) {
        result.addAll(_flattenNode(child, ref));
      }
    }

    return result;
  }

  List<FileNode> _flattenNode(FileNode node, WidgetRef ref) {
    final result = <FileNode>[];
    final fileTree = ref.watch(fileTreeProvider);

    for (final child in node.children) {
      result.add(child);
      if (child.isDirectory && fileTree.expandedPaths.contains(child.path)) {
        result.addAll(_flattenNode(child, ref));
      }
    }

    return result;
  }
}

class _FileTreeItem extends ConsumerStatefulWidget {
  final FileNode node;

  const _FileTreeItem({required this.node});

  @override
  ConsumerState<_FileTreeItem> createState() => _FileTreeItemState();
}

class _FileTreeItemState extends ConsumerState<_FileTreeItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeColorsProvider);
    final fileTree = ref.watch(fileTreeProvider);
    final tabState = ref.watch(tabProvider);
    final isExpanded = fileTree.expandedPaths.contains(widget.node.path);
    final isActive = tabState.activeTab?.filePath == widget.node.path;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => _handleTap(ref),
        onSecondaryTapUp: (details) =>
            _showContextMenu(context, ref, details.globalPosition),
        child: Container(
          height: 24,
          color: isActive
              ? colors.listActiveBackground
              : _isHovered
                  ? colors.listHoverBackground
                  : Colors.transparent,
          padding: EdgeInsets.only(left: 12.0 + (widget.node.depth - 1) * 16.0),
          child: Row(
            children: [
              // Expand/collapse arrow for directories
              if (widget.node.isDirectory)
                SizedBox(
                  width: 16,
                  child: Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    size: 14,
                    color: colors.sidebarForeground.withValues(alpha: 0.6),
                  ),
                )
              else
                const SizedBox(width: 16),

              // File/folder icon
              Icon(
                widget.node.icon,
                size: 16,
                color: widget.node.iconColor,
              ),
              const SizedBox(width: 6),

              // File name
              Expanded(
                child: Text(
                  widget.node.name,
                  style: TextStyle(
                    color: isActive
                        ? colors.foreground
                        : colors.sidebarForeground,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTap(WidgetRef ref) {
    if (widget.node.isDirectory) {
      ref.read(fileTreeProvider.notifier).toggleExpanded(widget.node);
    } else {
      ref
          .read(tabProvider.notifier)
          .openFile(widget.node.path, widget.node.name);
    }
  }

  void _showContextMenu(
      BuildContext context, WidgetRef ref, Offset position) {
    final colors = ref.read(themeColorsProvider);

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx, position.dy),
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: colors.border),
      ),
      items: [
        if (widget.node.isDirectory) ...[
          _menuItem('New File', Icons.note_add_outlined, colors, () {
            _showNameDialog(context, ref, 'New File', (name) {
              ref
                  .read(fileTreeProvider.notifier)
                  .createFile(widget.node.path, name);
            });
          }),
          _menuItem('New Folder', Icons.create_new_folder_outlined, colors, () {
            _showNameDialog(context, ref, 'New Folder', (name) {
              ref
                  .read(fileTreeProvider.notifier)
                  .createDirectory(widget.node.path, name);
            });
          }),
          const PopupMenuDivider(),
        ],
        _menuItem('Rename', Icons.edit_outlined, colors, () {
          _showNameDialog(
            context,
            ref,
            'Rename',
            (name) {
              ref
                  .read(fileTreeProvider.notifier)
                  .rename(widget.node.path, name);
            },
            initialValue: widget.node.name,
          );
        }),
        _menuItem('Delete', Icons.delete_outline, colors, () {
          ref.read(fileTreeProvider.notifier).delete(widget.node.path);
        }),
      ],
    );
  }

  PopupMenuEntry<dynamic> _menuItem(
      String label, IconData icon, ThemeColors colors, VoidCallback onTap) {
    return PopupMenuItem<dynamic>(
      onTap: onTap,
      height: 32,
      child: Row(
        children: [
          Icon(icon, size: 16, color: colors.foreground.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(color: colors.foreground, fontSize: 12)),
        ],
      ),
    );
  }

  void _showNameDialog(BuildContext context, WidgetRef ref, String title,
      void Function(String) onConfirm,
      {String initialValue = ''}) {
    final colors = ref.read(themeColorsProvider);
    final controller = TextEditingController(text: initialValue);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: colors.border),
        ),
        title: Text(title,
            style: TextStyle(color: colors.foreground, fontSize: 14)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: colors.foreground, fontSize: 13),
          decoration: InputDecoration(
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              onConfirm(value);
              Navigator.of(ctx).pop();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel',
                style: TextStyle(color: colors.foreground, fontSize: 12)),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                onConfirm(controller.text);
                Navigator.of(ctx).pop();
              }
            },
            style: TextButton.styleFrom(
              backgroundColor: colors.buttonBackground,
              foregroundColor: colors.buttonForeground,
            ),
            child: const Text('OK', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}
