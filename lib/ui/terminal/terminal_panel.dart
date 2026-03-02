import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:spark_ide/core/theme/theme_provider.dart';
import 'package:spark_ide/core/theme/spark_theme.dart';
import 'package:spark_ide/providers/file_tree_provider.dart';
import 'package:spark_ide/services/terminal/terminal_service.dart';

/// Integrated terminal widget using xterm + flutter_pty
class TerminalPanel extends ConsumerStatefulWidget {
  const TerminalPanel({super.key});

  @override
  ConsumerState<TerminalPanel> createState() => _TerminalPanelState();
}

class _TerminalPanelState extends ConsumerState<TerminalPanel> {
  late Terminal _terminal;
  late TerminalService _terminalService;
  Pty? _pty;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 10000);
    _terminalService = TerminalService();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _startTerminal();
    }
  }

  void _startTerminal() {
    final workingDirectory = ref.read(fileTreeProvider).rootPath;

    _pty = _terminalService.startShell(
      workingDirectory: workingDirectory,
    );

    // PTY output -> Terminal display
    _pty!.output.cast<List<int>>().transform(const Utf8Decoder()).listen(
      (data) {
        _terminal.write(data);
      },
      onDone: () {
        if (mounted) {
          _terminal.write('\r\n\x1B[90m[Process exited]\x1B[0m\r\n');
        }
      },
    );

    // Terminal input -> PTY
    _terminal.onOutput = (data) {
      _pty?.write(const Utf8Encoder().convert(data));
    };

    // Terminal resize -> PTY
    _terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      _terminalService.resize(width, height);
    };
  }

  void _restartTerminal() {
    final workingDirectory = ref.read(fileTreeProvider).rootPath;
    _terminalService.kill();
    _terminal = Terminal(maxLines: 10000);

    _pty = _terminalService.restart(workingDirectory: workingDirectory);

    _pty!.output.cast<List<int>>().transform(const Utf8Decoder()).listen(
      (data) {
        _terminal.write(data);
      },
      onDone: () {
        if (mounted) {
          _terminal.write('\r\n\x1B[90m[Process exited]\x1B[0m\r\n');
        }
      },
    );

    _terminal.onOutput = (data) {
      _pty?.write(const Utf8Encoder().convert(data));
    };

    _terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      _terminalService.resize(width, height);
    };

    setState(() {});
  }

  @override
  void dispose() {
    _terminalService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeColorsProvider);

    return Container(
      color: colors.terminalBackground,
      child: Column(
        children: [
          // Terminal toolbar
          _TerminalToolbar(
            colors: colors,
            onRestart: _restartTerminal,
          ),
          // Terminal view
          Expanded(
            child: TerminalView(
              _terminal,
              textStyle: TerminalStyle(
                fontSize: 13,
                fontFamily: 'JetBrainsMono',
              ),
              theme: _buildTerminalTheme(colors),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              autofocus: true,
            ),
          ),
        ],
      ),
    );
  }

  TerminalTheme _buildTerminalTheme(ThemeColors colors) {
    return TerminalTheme(
      cursor: colors.editorCursorColor,
      selection: colors.editorSelectionBackground,
      foreground: colors.terminalForeground,
      background: colors.terminalBackground,
      black: const Color(0xFF45475A),
      red: const Color(0xFFF38BA8),
      green: const Color(0xFFA6E3A1),
      yellow: const Color(0xFFF9E2AF),
      blue: const Color(0xFF89B4FA),
      magenta: const Color(0xFFF5C2E7),
      cyan: const Color(0xFF89DCEB),
      white: const Color(0xFFBAC2DE),
      brightBlack: const Color(0xFF585B70),
      brightRed: const Color(0xFFF38BA8),
      brightGreen: const Color(0xFFA6E3A1),
      brightYellow: const Color(0xFFF9E2AF),
      brightBlue: const Color(0xFF89B4FA),
      brightMagenta: const Color(0xFFF5C2E7),
      brightCyan: const Color(0xFF89DCEB),
      brightWhite: const Color(0xFFA6ADC8),
      searchHitBackground: colors.primary.withValues(alpha: 0.3),
      searchHitBackgroundCurrent: colors.primary.withValues(alpha: 0.5),
      searchHitForeground: colors.foreground,
    );
  }
}

class _TerminalToolbar extends StatelessWidget {
  final ThemeColors colors;
  final VoidCallback onRestart;

  const _TerminalToolbar({
    required this.colors,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colors.border.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          // Shell label
          Text(
            Platform.isWindows ? 'cmd' : 'bash',
            style: TextStyle(
              color: colors.terminalForeground.withValues(alpha: 0.6),
              fontSize: 11,
              fontFamily: 'JetBrainsMono',
            ),
          ),
          const Spacer(),
          // Restart button
          _ToolbarButton(
            icon: Icons.refresh,
            tooltip: 'Restart Terminal',
            colors: colors,
            onTap: onRestart,
          ),
          const SizedBox(width: 2),
          // New terminal button (placeholder)
          _ToolbarButton(
            icon: Icons.add,
            tooltip: 'New Terminal',
            colors: colors,
            onTap: onRestart, // For now, same as restart
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final ThemeColors colors;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.colors,
    required this.onTap,
  });

  @override
  State<_ToolbarButton> createState() => _ToolbarButtonState();
}

class _ToolbarButtonState extends State<_ToolbarButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: _hovered
                  ? widget.colors.foreground.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              widget.icon,
              size: 14,
              color: widget.colors.terminalForeground.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}
