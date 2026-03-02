import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_ide/core/constants/app_constants.dart';
import 'package:spark_ide/core/theme/theme_provider.dart';
import 'package:spark_ide/providers/tab_provider.dart';
import 'package:spark_ide/providers/settings_provider.dart';
import 'package:spark_ide/providers/output_provider.dart';
import 'package:spark_ide/providers/file_tree_provider.dart';
import 'package:spark_ide/providers/lsp_provider.dart';
import 'package:spark_ide/providers/auth_provider.dart';
import 'package:spark_ide/ui/auth/auth_dialog.dart';

/// Status bar at the bottom of the IDE
class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeColorsProvider);
    final tabState = ref.watch(tabProvider);
    final settings = ref.watch(settingsProvider);
    final activeTab = tabState.activeTab;
    final lspState = ref.watch(lspProvider);
    final errorCount = lspState.errorCount;
    final warningCount = lspState.warningCount;

    return Container(
      height: AppSizes.statusBarHeight,
      color: colors.statusBarBackground,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          // Branch icon (placeholder for future git integration)
          Icon(
            Icons.merge_type,
            size: 14,
            color: colors.statusBarForeground.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 4),
          _StatusText(
            text: 'main',
            color: colors.statusBarForeground,
          ),
          const SizedBox(width: 16),

          // Errors / Warnings (live from LSP)
          Icon(
            Icons.error_outline,
            size: 13,
            color: errorCount > 0
                ? colors.error
                : colors.statusBarForeground.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 3),
          _StatusText(
            text: '$errorCount',
            color: errorCount > 0
                ? colors.error
                : colors.statusBarForeground,
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.warning_amber,
            size: 13,
            color: warningCount > 0
                ? colors.warning
                : colors.statusBarForeground.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 3),
          _StatusText(
            text: '$warningCount',
            color: warningCount > 0
                ? colors.warning
                : colors.statusBarForeground,
          ),

          const SizedBox(width: 16),

          // Run button
          if (activeTab != null &&
              !activeTab.filePath.startsWith('untitled'))
            _RunButton(
              color: colors.statusBarForeground,
              onTap: () {
                ref.read(tabProvider.notifier).saveActiveTab().then((_) {
                  // Notify LSP of save
                  ref.read(lspProvider.notifier).didSaveDocument(
                    activeTab.filePath,
                    activeTab.languageId,
                    activeTab.content,
                  );
                  final workDir = ref.read(fileTreeProvider).rootPath;
                  ref.read(outputProvider.notifier).runFile(
                    activeTab.filePath,
                    workingDirectory: workDir,
                  );
                  ref.read(bottomPanelProvider.notifier).state =
                      BottomPanel.output;
                  ref.read(bottomPanelVisibleProvider.notifier).state = true;
                });
              },
            ),

          const Spacer(),

          // Right side: cursor position, language, encoding, etc.
          if (activeTab != null) ...[
            // Cursor position
            _StatusButton(
              text: 'Ln ${activeTab.cursorLine}, Col ${activeTab.cursorColumn}',
              color: colors.statusBarForeground,
              onTap: () {},
            ),
            _StatusDivider(color: colors.statusBarForeground),

            // Tab size
            _StatusButton(
              text: 'Spaces: ${settings.tabSize}',
              color: colors.statusBarForeground,
              onTap: () {},
            ),
            _StatusDivider(color: colors.statusBarForeground),

            // Encoding
            _StatusButton(
              text: 'UTF-8',
              color: colors.statusBarForeground,
              onTap: () {},
            ),
            _StatusDivider(color: colors.statusBarForeground),

            // Language
            _StatusButton(
              text: _getLanguageLabel(activeTab.languageId),
              color: colors.statusBarForeground,
              onTap: () {},
            ),
            _StatusDivider(color: colors.statusBarForeground),

            // LSP status indicator
            _LspIndicator(
              languageId: activeTab.languageId,
              lspState: lspState,
              color: colors.statusBarForeground,
              activeColor: colors.success,
            ),
            _StatusDivider(color: colors.statusBarForeground),
            _AuthIndicator(),
          ],

          if (activeTab == null) ...[
            _StatusText(
              text: 'Spark IDE',
              color: colors.statusBarForeground.withValues(alpha: 0.5),
            ),
            const Spacer(),
            _AuthIndicator(),
          ],
        ],
      ),
    );
  }

  String _getLanguageLabel(String languageId) {
    switch (languageId) {
      case 'dart':
        return 'Dart';
      case 'python':
        return 'Python';
      case 'javascript':
        return 'JavaScript';
      case 'javascriptreact':
        return 'JavaScript React';
      case 'typescript':
        return 'TypeScript';
      case 'typescriptreact':
        return 'TypeScript React';
      case 'html':
        return 'HTML';
      case 'css':
        return 'CSS';
      case 'scss':
        return 'SCSS';
      case 'json':
        return 'JSON';
      case 'yaml':
        return 'YAML';
      case 'markdown':
        return 'Markdown';
      case 'c':
        return 'C';
      case 'cpp':
        return 'C++';
      case 'java':
        return 'Java';
      case 'kotlin':
        return 'Kotlin';
      case 'swift':
        return 'Swift';
      case 'go':
        return 'Go';
      case 'rust':
        return 'Rust';
      case 'ruby':
        return 'Ruby';
      case 'php':
        return 'PHP';
      case 'csharp':
        return 'C#';
      case 'sql':
        return 'SQL';
      case 'shellscript':
        return 'Shell Script';
      case 'xml':
        return 'XML';
      case 'plaintext':
        return 'Plain Text';
      default:
        return languageId;
    }
  }
}

class _LspIndicator extends StatelessWidget {
  final String languageId;
  final LspState lspState;
  final Color color;
  final Color activeColor;

  const _LspIndicator({
    required this.languageId,
    required this.lspState,
    required this.color,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasClient = lspState.clients.containsKey(languageId) &&
        lspState.clients[languageId]!.isRunning;
    final isAvailable = lspState.availability[languageId] ?? false;

    final String label;
    final Color indicatorColor;

    if (hasClient) {
      label = 'LSP';
      indicatorColor = activeColor;
    } else if (isAvailable) {
      label = 'LSP (idle)';
      indicatorColor = color.withValues(alpha: 0.5);
    } else {
      label = 'LSP (n/a)';
      indicatorColor = color.withValues(alpha: 0.3);
    }

    return Tooltip(
      message: hasClient
          ? 'Language Server active'
          : isAvailable
              ? 'Language Server available'
              : 'No language server found',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: indicatorColor,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: indicatorColor,
              fontSize: 11,
              fontFamily: 'JetBrainsMono',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusText extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusText({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color.withValues(alpha: 0.8),
        fontSize: 11,
        fontFamily: 'JetBrainsMono',
      ),
    );
  }
}

class _StatusButton extends StatefulWidget {
  final String text;
  final Color color;
  final VoidCallback onTap;

  const _StatusButton({
    required this.text,
    required this.color,
    required this.onTap,
  });

  @override
  State<_StatusButton> createState() => _StatusButtonState();
}

class _StatusButtonState extends State<_StatusButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _isHovered
                ? widget.color.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            widget.text,
            style: TextStyle(
              color: widget.color.withValues(alpha: 0.8),
              fontSize: 11,
              fontFamily: 'JetBrainsMono',
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusDivider extends StatelessWidget {
  final Color color;

  const _StatusDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 14,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: color.withValues(alpha: 0.15),
    );
  }
}

class _RunButton extends StatefulWidget {
  final Color color;
  final VoidCallback onTap;

  const _RunButton({required this.color, required this.onTap});

  @override
  State<_RunButton> createState() => _RunButtonState();
}

class _RunButtonState extends State<_RunButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: 'Run File (F5)',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _isHovered
                  ? widget.color.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.play_arrow,
                  size: 14,
                  color: widget.color.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 3),
                Text(
                  'Run',
                  style: TextStyle(
                    color: widget.color.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontFamily: 'JetBrainsMono',
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

/// Auth indicator in the status bar — shows user name or "Sign In".
class _AuthIndicator extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AuthIndicator> createState() => _AuthIndicatorState();
}

class _AuthIndicatorState extends ConsumerState<_AuthIndicator> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeColorsProvider);
    final authState = ref.watch(authProvider);

    final String label;
    final IconData icon;
    if (authState.isSignedIn) {
      label = authState.profile!.displayName;
      icon = Icons.person;
    } else {
      label = 'Sign In';
      icon = Icons.person_outline;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => AuthDialog.show(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _isHovered
                ? colors.statusBarForeground.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: colors.statusBarForeground.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: colors.statusBarForeground.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontFamily: 'JetBrainsMono',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
