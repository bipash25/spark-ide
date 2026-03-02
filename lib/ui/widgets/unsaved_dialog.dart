import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_ide/core/theme/theme_provider.dart';
import 'package:spark_ide/providers/tab_provider.dart';
import 'package:spark_ide/providers/lsp_provider.dart';

/// Result of the unsaved changes dialog
enum UnsavedAction { save, discard, cancel }

/// Shows a confirmation dialog when closing a tab with unsaved changes.
/// Returns true if the tab should be closed, false if the action was cancelled.
Future<bool> confirmCloseTab(BuildContext context, WidgetRef ref, int index) async {
  final tabState = ref.read(tabProvider);
  if (index < 0 || index >= tabState.tabs.length) return true;

  final tab = tabState.tabs[index];

  // If no unsaved changes, close immediately
  if (!tab.isDirty) {
    // Notify LSP before closing
    if (!tab.filePath.startsWith('untitled')) {
      ref.read(lspProvider.notifier).didCloseDocument(
        tab.filePath,
        tab.languageId,
      );
    }
    ref.read(tabProvider.notifier).closeTab(index);
    return true;
  }

  final colors = ref.read(themeColorsProvider);

  final result = await showDialog<UnsavedAction>(
    context: context,
    barrierDismissible: true,
    builder: (context) => _UnsavedChangesDialog(
      fileName: tab.fileName,
      colors: colors,
    ),
  );

  if (result == null || result == UnsavedAction.cancel) {
    return false;
  }

  if (result == UnsavedAction.save) {
    // Save first, then close
    // Temporarily switch to the tab to save it
    final prevActive = tabState.activeIndex;
    ref.read(tabProvider.notifier).setActiveTab(index);
    await ref.read(tabProvider.notifier).saveActiveTab();
    // Notify LSP of save then close
    if (!tab.filePath.startsWith('untitled')) {
      ref.read(lspProvider.notifier).didSaveDocument(
        tab.filePath,
        tab.languageId,
        tab.content,
      );
      ref.read(lspProvider.notifier).didCloseDocument(
        tab.filePath,
        tab.languageId,
      );
    }
    // If we switched, the close will adjust the index
    ref.read(tabProvider.notifier).closeTab(index);
    // Try to restore previous active (adjusted for removal)
    if (prevActive < index && prevActive >= 0) {
      ref.read(tabProvider.notifier).setActiveTab(prevActive);
    }
    return true;
  }

  // Discard — notify LSP of close, then close tab
  if (!tab.filePath.startsWith('untitled')) {
    ref.read(lspProvider.notifier).didCloseDocument(
      tab.filePath,
      tab.languageId,
    );
  }
  ref.read(tabProvider.notifier).closeTab(index);
  return true;
}

class _UnsavedChangesDialog extends StatelessWidget {
  final String fileName;
  final dynamic colors;

  const _UnsavedChangesDialog({
    required this.fileName,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: colors.warning,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Unsaved Changes',
                    style: TextStyle(
                      color: colors.foreground,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'JetBrainsMono',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Message
              Text(
                'Do you want to save the changes you made to "$fileName"?',
                style: TextStyle(
                  color: colors.foreground.withValues(alpha: 0.7),
                  fontSize: 13,
                  fontFamily: 'JetBrainsMono',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Your changes will be lost if you don't save them.",
                style: TextStyle(
                  color: colors.foreground.withValues(alpha: 0.45),
                  fontSize: 11,
                  fontFamily: 'JetBrainsMono',
                ),
              ),

              const SizedBox(height: 20),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Don't Save
                  _DialogButton(
                    label: "Don't Save",
                    onTap: () =>
                        Navigator.of(context).pop(UnsavedAction.discard),
                    colors: colors,
                    isDestructive: true,
                  ),
                  const SizedBox(width: 8),
                  // Cancel
                  _DialogButton(
                    label: 'Cancel',
                    onTap: () =>
                        Navigator.of(context).pop(UnsavedAction.cancel),
                    colors: colors,
                  ),
                  const SizedBox(width: 8),
                  // Save
                  _DialogButton(
                    label: 'Save',
                    onTap: () =>
                        Navigator.of(context).pop(UnsavedAction.save),
                    colors: colors,
                    isPrimary: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final dynamic colors;
  final bool isPrimary;
  final bool isDestructive;

  const _DialogButton({
    required this.label,
    required this.onTap,
    required this.colors,
    this.isPrimary = false,
    this.isDestructive = false,
  });

  @override
  State<_DialogButton> createState() => _DialogButtonState();
}

class _DialogButtonState extends State<_DialogButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    if (widget.isPrimary) {
      bg = _hovered
          ? widget.colors.buttonHoverBackground
          : widget.colors.buttonBackground;
      fg = widget.colors.buttonForeground;
    } else if (widget.isDestructive) {
      bg = _hovered
          ? widget.colors.error.withValues(alpha: 0.2)
          : Colors.transparent;
      fg = widget.colors.error;
    } else {
      bg = _hovered
          ? widget.colors.foreground.withValues(alpha: 0.1)
          : Colors.transparent;
      fg = widget.colors.foreground.withValues(alpha: 0.7);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4),
            border: widget.isPrimary
                ? null
                : Border.all(
                    color: widget.isDestructive
                        ? widget.colors.error.withValues(alpha: 0.4)
                        : widget.colors.border,
                  ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              fontFamily: 'JetBrainsMono',
            ),
          ),
        ),
      ),
    );
  }
}
