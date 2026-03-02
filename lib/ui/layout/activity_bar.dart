import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_ide/core/constants/app_constants.dart';
import 'package:spark_ide/core/theme/theme_provider.dart';
import 'package:spark_ide/core/theme/spark_theme.dart';
import 'package:spark_ide/providers/settings_provider.dart';
import 'package:spark_ide/providers/auth_provider.dart';
import 'package:spark_ide/ui/auth/auth_dialog.dart';

/// VS Code-style activity bar on the far left
class ActivityBar extends ConsumerWidget {
  const ActivityBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeColorsProvider);
    final activePanel = ref.watch(sidebarPanelProvider);
    final sidebarVisible = ref.watch(sidebarVisibleProvider);

    return Container(
      width: AppSizes.activityBarWidth,
      color: colors.activityBarBackground,
      child: Column(
        children: [
          const SizedBox(height: 4),
          _ActivityBarButton(
            icon: Icons.file_copy_outlined,
            activeIcon: Icons.file_copy,
            tooltip: 'Explorer',
            isActive: sidebarVisible && activePanel == SidebarPanel.explorer,
            onTap: () {
              if (activePanel == SidebarPanel.explorer && sidebarVisible) {
                ref.read(sidebarVisibleProvider.notifier).state = false;
              } else {
                ref.read(sidebarPanelProvider.notifier).state =
                    SidebarPanel.explorer;
                ref.read(sidebarVisibleProvider.notifier).state = true;
              }
            },
          ),
          _ActivityBarButton(
            icon: Icons.search,
            activeIcon: Icons.search,
            tooltip: 'Search',
            isActive: sidebarVisible && activePanel == SidebarPanel.search,
            onTap: () {
              if (activePanel == SidebarPanel.search && sidebarVisible) {
                ref.read(sidebarVisibleProvider.notifier).state = false;
              } else {
                ref.read(sidebarPanelProvider.notifier).state =
                    SidebarPanel.search;
                ref.read(sidebarVisibleProvider.notifier).state = true;
              }
            },
          ),
          _ActivityBarButton(
            icon: Icons.school_outlined,
            activeIcon: Icons.school,
            tooltip: 'Classrooms',
            isActive: sidebarVisible && activePanel == SidebarPanel.classroom,
            onTap: () {
              if (activePanel == SidebarPanel.classroom && sidebarVisible) {
                ref.read(sidebarVisibleProvider.notifier).state = false;
              } else {
                ref.read(sidebarPanelProvider.notifier).state =
                    SidebarPanel.classroom;
                ref.read(sidebarVisibleProvider.notifier).state = true;
              }
            },
          ),
          const Spacer(),
          _AccountButton(),
          _ActivityBarButton(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings,
            tooltip: 'Settings',
            isActive: false,
            onTap: () {
              _showSettingsDialog(context, ref);
            },
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context, WidgetRef ref) {
    final colors = ref.read(themeColorsProvider);
    showDialog(
      context: context,
      builder: (context) => SettingsDialog(colors: colors),
    );
  }
}

class _ActivityBarButton extends ConsumerStatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onTap;

  const _ActivityBarButton({
    required this.icon,
    required this.activeIcon,
    required this.tooltip,
    required this.isActive,
    required this.onTap,
  });

  @override
  ConsumerState<_ActivityBarButton> createState() => _ActivityBarButtonState();
}

class _ActivityBarButtonState extends ConsumerState<_ActivityBarButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeColorsProvider);

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppDurations.fast,
            width: AppSizes.activityBarWidth,
            height: AppSizes.activityBarWidth,
            decoration: BoxDecoration(
              color: _isHovered && !widget.isActive
                  ? colors.listHoverBackground
                  : Colors.transparent,
              border: Border(
                left: BorderSide(
                  color: widget.isActive ? colors.primary : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: AnimatedSwitcher(
              duration: AppDurations.fast,
              child: Icon(
                widget.isActive ? widget.activeIcon : widget.icon,
                key: ValueKey(widget.isActive),
                size: AppSizes.iconSizeLg,
                color: widget.isActive
                    ? colors.activityBarActiveForeground
                    : _isHovered
                        ? colors.activityBarForeground
                        : colors.activityBarForeground.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsDialog extends ConsumerWidget {
  final ThemeColors colors;

  const SettingsDialog({super.key, required this.colors});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final selectedTheme = ref.watch(selectedThemeProvider);

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
        side: BorderSide(color: colors.border),
      ),
      child: Container(
        width: 450,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(AppSizes.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Settings',
                  style: TextStyle(
                    color: colors.foreground,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: colors.foreground, size: 18),
                  splashRadius: 16,
                ),
              ],
            ),
            const SizedBox(height: AppSizes.spacingLg),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Color Theme'),
                    // Theme picker grid
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final theme in availableThemes)
                          _ThemeTile(
                            entry: theme,
                            isSelected: theme.id == selectedTheme,
                            colors: colors,
                            onTap: () => ref
                                .read(selectedThemeProvider.notifier)
                                .setTheme(theme.id),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.spacingLg),
                    _sectionTitle('Appearance'),
                    _settingRow(
                      'Font Size',
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => ref
                                .read(settingsProvider.notifier)
                                .decreaseFontSize(),
                            icon: Icon(Icons.remove,
                                color: colors.foreground, size: 16),
                            splashRadius: 14,
                          ),
                          Text(
                            '${settings.fontSize.round()}',
                            style: TextStyle(
                                color: colors.foreground, fontSize: 13),
                          ),
                          IconButton(
                            onPressed: () => ref
                                .read(settingsProvider.notifier)
                                .increaseFontSize(),
                            icon: Icon(Icons.add,
                                color: colors.foreground, size: 16),
                            splashRadius: 14,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSizes.spacingLg),
                    _sectionTitle('Editor'),
                    _switchRow(
                      'Word Wrap',
                      settings.wordWrap,
                      () => ref.read(settingsProvider.notifier).toggleWordWrap(),
                    ),
                    _switchRow(
                      'Line Numbers',
                      settings.lineNumbers,
                      () => ref
                          .read(settingsProvider.notifier)
                          .toggleLineNumbers(),
                    ),
                    _switchRow(
                      'Minimap',
                      settings.minimap,
                      () => ref.read(settingsProvider.notifier).toggleMinimap(),
                    ),
                    _switchRow(
                      'Highlight Active Line',
                      settings.highlightActiveLine,
                      () => ref.read(settingsProvider.notifier).update(
                            (s) => s.copyWith(
                                highlightActiveLine: !s.highlightActiveLine),
                          ),
                    ),
                    _switchRow(
                      'Indent Guides',
                      settings.indentGuides,
                      () => ref.read(settingsProvider.notifier).toggleIndentGuides(),
                    ),
                    _settingRow(
                      'Tab Size',
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final size in [2, 4, 8])
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              child: ChoiceChip(
                                label: Text('$size'),
                                selected: settings.tabSize == size,
                                onSelected: (_) => ref
                                    .read(settingsProvider.notifier)
                                    .setTabSize(size),
                                selectedColor: colors.primary,
                                labelStyle: TextStyle(
                                  color: settings.tabSize == size
                                      ? colors.buttonForeground
                                      : colors.foreground,
                                  fontSize: 12,
                                ),
                                backgroundColor: colors.inputBackground,
                                side: BorderSide.none,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSizes.spacingLg),
                    _sectionTitle('Keyboard Shortcuts'),
                    _KeyboardShortcutsList(colors: colors),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: colors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _settingRow(String label, Widget trailing) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: colors.foreground, fontSize: 13)),
          trailing,
        ],
      ),
    );
  }

  Widget _switchRow(String label, bool value, VoidCallback onTap) {
    return _settingRow(
      label,
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          width: 36,
          height: 20,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: value ? colors.primary : colors.inputBackground,
          ),
          child: AnimatedAlign(
            duration: AppDurations.fast,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value ? colors.buttonForeground : colors.foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Displays all keyboard shortcuts grouped by category inside the settings dialog.
class _KeyboardShortcutsList extends ConsumerWidget {
  final ThemeColors colors;

  const _KeyboardShortcutsList({required this.colors});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kbService = ref.watch(keyBindingServiceProvider);
    final grouped = kbService.groupedBindings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final category in grouped.keys) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              category,
              style: TextStyle(
                color: colors.foreground.withValues(alpha: 0.5),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          for (final kb in grouped[category]!)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      kb.label,
                      style: TextStyle(
                        color: colors.foreground,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: colors.inputBackground,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: kb.isCustomized
                            ? colors.primary.withValues(alpha: 0.5)
                            : colors.border.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      kb.activeLabel,
                      style: TextStyle(
                        color: kb.isCustomized
                            ? colors.primary
                            : colors.foreground.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontFamily: 'JetBrainsMono',
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// A single theme preview tile for the settings dialog theme picker.
class _ThemeTile extends StatelessWidget {
  final ThemeEntry entry;
  final bool isSelected;
  final ThemeColors colors;
  final VoidCallback onTap;

  const _ThemeTile({
    required this.entry,
    required this.isSelected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        width: 130,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? colors.primary : colors.border,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? colors.primary.withValues(alpha: 0.08)
              : Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mini preview
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: entry.previewBackground,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  // Sidebar preview
                  Container(
                    width: 20,
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        entry.previewBackground,
                        Colors.black,
                        0.15,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        bottomLeft: Radius.circular(4),
                      ),
                    ),
                  ),
                  // Editor area preview
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            height: 3,
                            width: 40,
                            decoration: BoxDecoration(
                              color: entry.previewAccent,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 3,
                            width: 55,
                            decoration: BoxDecoration(
                              color: entry.isDark
                                  ? Colors.white.withValues(alpha: 0.15)
                                  : Colors.black.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 3,
                            width: 35,
                            decoration: BoxDecoration(
                              color: entry.isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // Theme name
            Text(
              entry.name,
              style: TextStyle(
                color: isSelected ? colors.primary : colors.foreground,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Account button in the activity bar — shows avatar when signed in.
class _AccountButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeColorsProvider);
    final authState = ref.watch(authProvider);

    return Tooltip(
      message: authState.isSignedIn
          ? authState.profile!.displayName
          : 'Sign In',
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: () => AuthDialog.show(context),
        child: SizedBox(
          width: AppSizes.activityBarWidth,
          height: AppSizes.activityBarWidth,
          child: authState.isSignedIn
              ? Center(
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.primary.withValues(alpha: 0.2),
                    ),
                    child: Center(
                      child: Text(
                        authState.profile!.displayName.isNotEmpty
                            ? authState.profile!.displayName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: colors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                )
              : Icon(
                  Icons.person_outline,
                  size: AppSizes.iconSizeLg,
                  color: colors.activityBarForeground.withValues(alpha: 0.6),
                ),
        ),
      ),
    );
  }
}
