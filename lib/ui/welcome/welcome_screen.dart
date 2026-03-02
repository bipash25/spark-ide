import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_ide/core/constants/app_constants.dart';
import 'package:spark_ide/core/theme/theme_provider.dart';
import 'package:spark_ide/providers/file_tree_provider.dart';
import 'package:spark_ide/providers/tab_provider.dart';
import 'package:spark_ide/providers/settings_provider.dart';
import 'package:file_picker/file_picker.dart';

/// Welcome screen shown when no files are open
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeColorsProvider);
    final screenSize = MediaQuery.of(context).size;
    final isSmall = screenSize.width < 600;

    return Container(
      color: colors.editorBackground,
      child: Center(
        child: FadeTransition(
          opacity: _fadeIn,
          child: SlideTransition(
            position: _slideUp,
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isSmall ? 24 : 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo / Title
                  Icon(
                    Icons.bolt,
                    size: isSmall ? 48 : 64,
                    color: colors.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Spark IDE',
                    style: TextStyle(
                      fontSize: isSmall ? 28 : 36,
                      fontWeight: FontWeight.w700,
                      color: colors.foreground,
                      fontFamily: 'JetBrainsMono',
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lightweight. Cross-platform. No bloat.',
                    style: TextStyle(
                      fontSize: isSmall ? 12 : 14,
                      color: colors.foreground.withValues(alpha: 0.5),
                      fontFamily: 'JetBrainsMono',
                    ),
                  ),
                  SizedBox(height: isSmall ? 32 : 48),

                  // Action buttons
                  _WelcomeActionGrid(isSmall: isSmall),

                  SizedBox(height: isSmall ? 32 : 48),

                  // Keyboard shortcuts
                  if (!isSmall) ...[
                    Text(
                      'Keyboard Shortcuts',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.foreground.withValues(alpha: 0.6),
                        fontFamily: 'JetBrainsMono',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ShortcutGrid(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeActionGrid extends ConsumerWidget {
  final bool isSmall;

  const _WelcomeActionGrid({required this.isSmall});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeColorsProvider);

    final actions = [
      _WelcomeAction(
        icon: Icons.folder_open,
        label: 'Open Folder',
        description: 'Open a project folder',
        color: colors.primary,
        onTap: () async {
          final result = await FilePicker.platform.getDirectoryPath();
          if (result != null) {
            await ref.read(fileTreeProvider.notifier).openFolder(result);
            ref.read(sidebarVisibleProvider.notifier).state = true;
          }
        },
      ),
      _WelcomeAction(
        icon: Icons.note_add_outlined,
        label: 'New File',
        description: 'Create a new untitled file',
        color: colors.secondary,
        onTap: () {
          ref.read(tabProvider.notifier).openFile('untitled-1', 'untitled-1');
        },
      ),
      _WelcomeAction(
        icon: Icons.file_open_outlined,
        label: 'Open File',
        description: 'Open an existing file',
        color: colors.accent,
        onTap: () async {
          final result = await FilePicker.platform.pickFiles();
          if (result != null && result.files.single.path != null) {
            final path = result.files.single.path!;
            final name = result.files.single.name;
            ref.read(tabProvider.notifier).openFile(path, name);
          }
        },
      ),
    ];

    if (isSmall) {
      return Column(
        children: actions
            .map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: a,
                ))
            .toList(),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: actions
          .map((a) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox(width: 180, child: a),
              ))
          .toList(),
    );
  }
}

class _WelcomeAction extends ConsumerStatefulWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _WelcomeAction({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  ConsumerState<_WelcomeAction> createState() => _WelcomeActionState();
}

class _WelcomeActionState extends ConsumerState<_WelcomeAction> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeColorsProvider);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isHovered
                ? colors.surface
                : colors.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
            border: Border.all(
              color: _isHovered ? widget.color.withValues(alpha: 0.5) : colors.border,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 28,
                color: widget.color,
              ),
              const SizedBox(height: 10),
              Text(
                widget.label,
                style: TextStyle(
                  color: colors.foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'JetBrainsMono',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.foreground.withValues(alpha: 0.5),
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

class _ShortcutGrid extends ConsumerWidget {
  final shortcuts = const [
    ('Ctrl+S', 'Save file'),
    ('Ctrl+O', 'Open file'),
    ('Ctrl+N', 'New file'),
    ('Ctrl+W', 'Close tab'),
    ('Ctrl+Shift+P', 'Command palette'),
    ('Ctrl+B', 'Toggle sidebar'),
    ('Ctrl+`', 'Toggle terminal'),
    ('Ctrl+F', 'Find in file'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeColorsProvider);

    return Wrap(
      spacing: 24,
      runSpacing: 8,
      children: shortcuts.map((s) {
        return SizedBox(
          width: 200,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: colors.border.withValues(alpha: 0.5)),
                ),
                child: Text(
                  s.$1,
                  style: TextStyle(
                    color: colors.foreground.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontFamily: 'JetBrainsMono',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.$2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.foreground.withValues(alpha: 0.5),
                    fontSize: 11,
                    fontFamily: 'JetBrainsMono',
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
