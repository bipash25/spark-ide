import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_pty/flutter_pty.dart';

/// Service that manages a pseudo-terminal process.
/// Wraps flutter_pty to provide shell access on desktop platforms.
class TerminalService {
  Pty? _pty;
  String? _workingDirectory;

  /// Whether a PTY process is currently running
  bool get isRunning => _pty != null;

  /// Start a new shell process
  Pty startShell({String? workingDirectory}) {
    _workingDirectory = workingDirectory;

    final shell = _getShell();
    _pty = Pty.start(
      shell,
      columns: 80,
      rows: 24,
      workingDirectory: workingDirectory,
      environment: Platform.environment,
    );

    return _pty!;
  }

  /// Resize the terminal
  void resize(int columns, int rows) {
    _pty?.resize(columns, rows);
  }

  /// Write data to the PTY
  void write(String data) {
    final encoded = const SystemEncoding().encoder.convert(data);
    _pty?.write(Uint8List.fromList(encoded));
  }

  /// Kill the current PTY process
  void kill() {
    _pty?.kill();
    _pty = null;
  }

  /// Restart the shell
  Pty restart({String? workingDirectory}) {
    kill();
    return startShell(workingDirectory: workingDirectory ?? _workingDirectory);
  }

  /// Get the default shell for the current platform
  String _getShell() {
    if (Platform.isWindows) {
      return 'cmd.exe';
    }
    // Try to use the user's preferred shell
    final shell = Platform.environment['SHELL'];
    if (shell != null && shell.isNotEmpty) {
      return shell;
    }
    return '/bin/bash';
  }

  void dispose() {
    kill();
  }
}
