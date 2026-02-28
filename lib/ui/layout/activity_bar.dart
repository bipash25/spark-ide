import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_ide/core/constants/app_constants.dart';
import 'package:spark_ide/core/theme/theme_provider.dart';
import 'package:spark_ide/core/theme/spark_theme.dart';
import 'package:spark_ide/providers/settings_provider.dart';

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
          const Spacer(),
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
      builder: (context) => _SettingsDialog(colors: colors),
    );
  }
}

class _ActivityBarButton extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeColorsProvider);

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: AppSizes.activityBarWidth,
          height: AppSizes.activityBarWidth,
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isActive ? colors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Icon(
            isActive ? activeIcon : icon,
            size: AppSizes.iconSizeLg,
            color: isActive
                ? colors.activityBarActiveForeground
                : colors.activityBarForeground.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

class _SettingsDialog extends ConsumerWidget {
  final ThemeColors colors;

  const _SettingsDialog({required this.colors});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final themeMode = ref.watch(themeModeProvider);

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
                    _sectionTitle('Appearance'),
                    _settingRow(
                      'Theme',
                      DropdownButton<ThemeMode>(
                        value: themeMode,
                        dropdownColor: colors.surface,
                        style: TextStyle(color: colors.foreground, fontSize: 13),
                        underline: Container(height: 1, color: colors.border),
                        items: const [
                          DropdownMenuItem(
                            value: ThemeMode.dark,
                            child: Text('Dark'),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.light,
                            child: Text('Light'),
                          ),
                        ],
                        onChanged: (mode) {
                          if (mode != null) {
                            ref
                                .read(themeModeProvider.notifier)
                                .setThemeMode(mode);
                          }
                        },
                      ),
                    ),
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
