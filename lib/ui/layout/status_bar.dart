import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_ide/core/constants/app_constants.dart';
import 'package:spark_ide/core/theme/theme_provider.dart';
import 'package:spark_ide/providers/tab_provider.dart';
import 'package:spark_ide/providers/settings_provider.dart';

/// Status bar at the bottom of the IDE
class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeColorsProvider);
    final tabState = ref.watch(tabProvider);
    final settings = ref.watch(settingsProvider);
    final activeTab = tabState.activeTab;

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

          // Errors / Warnings (placeholder)
          Icon(
            Icons.error_outline,
            size: 13,
            color: colors.statusBarForeground.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 3),
          _StatusText(text: '0', color: colors.statusBarForeground),
          const SizedBox(width: 8),
          Icon(
            Icons.warning_amber,
            size: 13,
            color: colors.statusBarForeground.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 3),
          _StatusText(text: '0', color: colors.statusBarForeground),

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
          ],

          if (activeTab == null)
            _StatusText(
              text: 'Spark IDE',
              color: colors.statusBarForeground.withValues(alpha: 0.5),
            ),
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
