import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;

/// Result of a code execution
class ExecutionResult {
  final String stdout;
  final String stderr;
  final int exitCode;
  final Duration elapsed;
  final String command;

  const ExecutionResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
    required this.elapsed,
    required this.command,
  });

  bool get success => exitCode == 0;

  String get output {
    final buf = StringBuffer();
    if (stdout.isNotEmpty) buf.write(stdout);
    if (stderr.isNotEmpty) {
      if (buf.isNotEmpty) buf.writeln();
      buf.write(stderr);
    }
    return buf.toString();
  }
}

/// Supported execution targets
enum ExecutionTarget {
  python,
  c,
  cpp,
  javascript,
  html,
  dart,
  shell,
  unsupported,
}

/// Service for compiling and executing code files.
/// Detects available compilers on the system and runs files accordingly.
class CompilerService {
  /// Cached compiler paths
  final Map<String, String?> _compilerCache = {};

  /// Detect the execution target from a file path
  ExecutionTarget detectTarget(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    switch (ext) {
      case '.py':
      case '.pyw':
        return ExecutionTarget.python;
      case '.c':
        return ExecutionTarget.c;
      case '.cpp':
      case '.cc':
      case '.cxx':
        return ExecutionTarget.cpp;
      case '.js':
      case '.mjs':
        return ExecutionTarget.javascript;
      case '.html':
      case '.htm':
        return ExecutionTarget.html;
      case '.dart':
        return ExecutionTarget.dart;
      case '.sh':
      case '.bash':
        return ExecutionTarget.shell;
      default:
        return ExecutionTarget.unsupported;
    }
  }

  /// Get a human-readable name for the target
  String targetName(ExecutionTarget target) {
    switch (target) {
      case ExecutionTarget.python:
        return 'Python';
      case ExecutionTarget.c:
        return 'C';
      case ExecutionTarget.cpp:
        return 'C++';
      case ExecutionTarget.javascript:
        return 'JavaScript (Node.js)';
      case ExecutionTarget.html:
        return 'HTML (Browser)';
      case ExecutionTarget.dart:
        return 'Dart';
      case ExecutionTarget.shell:
        return 'Shell Script';
      case ExecutionTarget.unsupported:
        return 'Unsupported';
    }
  }

  /// Execute a file. For compiled languages (C/C++), compiles first then runs.
  /// Returns a stream of output lines for real-time display, and a future
  /// for the final result.
  Future<ExecutionResult> execute(
    String filePath, {
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final target = detectTarget(filePath);
    final dir = workingDirectory ?? p.dirname(filePath);

    switch (target) {
      case ExecutionTarget.python:
        // On Windows, 'python3' is a broken Microsoft Store alias — try 'python' first.
        // On Linux/macOS, 'python3' is the standard command.
        return _runInterpreted(
          filePath, dir, timeout,
          Platform.isWindows ? ['python', 'python3'] : ['python3', 'python'],
        );
      case ExecutionTarget.c:
        return _compileAndRun(
          filePath, dir, timeout,
          compilerCandidates: ['gcc', 'cc'],
          compileArgs: (compiler, src, out) => [compiler, src, '-o', out, '-lm'],
        );
      case ExecutionTarget.cpp:
        return _compileAndRun(
          filePath, dir, timeout,
          compilerCandidates: ['g++', 'c++'],
          compileArgs: (compiler, src, out) =>
              [compiler, src, '-o', out, '-std=c++17', '-lm'],
        );
      case ExecutionTarget.javascript:
        return _runInterpreted(filePath, dir, timeout, ['node']);
      case ExecutionTarget.dart:
        return _runInterpreted(filePath, dir, timeout, ['dart']);
      case ExecutionTarget.shell:
        return _runInterpreted(filePath, dir, timeout, ['bash', 'sh']);
      case ExecutionTarget.html:
        return _openHtml(filePath);
      case ExecutionTarget.unsupported:
        return ExecutionResult(
          stdout: '',
          stderr: 'Unsupported file type: ${p.extension(filePath)}',
          exitCode: 1,
          elapsed: Duration.zero,
          command: '',
        );
    }
  }

  /// Run a file with an interpreter (python, node, dart, etc.)
  Future<ExecutionResult> _runInterpreted(
    String filePath,
    String workingDir,
    Duration timeout,
    List<String> interpreterCandidates,
  ) async {
    final interpreter = await _findExecutable(interpreterCandidates);
    if (interpreter == null) {
      return ExecutionResult(
        stdout: '',
        stderr:
            'No interpreter found. Tried: ${interpreterCandidates.join(", ")}\n'
            'Please install one of these and ensure it is on your PATH.',
        exitCode: 1,
        elapsed: Duration.zero,
        command: '',
      );
    }

    final command = '$interpreter ${p.basename(filePath)}';
    final stopwatch = Stopwatch()..start();

    try {
      final result = await Process.run(
        interpreter,
        [filePath],
        workingDirectory: workingDir,
        environment: Platform.environment,
      ).timeout(timeout);

      stopwatch.stop();

      return ExecutionResult(
        stdout: result.stdout.toString(),
        stderr: result.stderr.toString(),
        exitCode: result.exitCode,
        elapsed: stopwatch.elapsed,
        command: command,
      );
    } on TimeoutException {
      stopwatch.stop();
      return ExecutionResult(
        stdout: '',
        stderr: 'Execution timed out after ${timeout.inSeconds}s',
        exitCode: 124,
        elapsed: stopwatch.elapsed,
        command: command,
      );
    } catch (e) {
      stopwatch.stop();
      return ExecutionResult(
        stdout: '',
        stderr: 'Failed to execute: $e',
        exitCode: 1,
        elapsed: stopwatch.elapsed,
        command: command,
      );
    }
  }

  /// Compile (C/C++) and then run
  Future<ExecutionResult> _compileAndRun(
    String filePath,
    String workingDir,
    Duration timeout, {
    required List<String> compilerCandidates,
    required List<String> Function(String compiler, String src, String out)
        compileArgs,
  }) async {
    final compiler = await _findExecutable(compilerCandidates);
    if (compiler == null) {
      return ExecutionResult(
        stdout: '',
        stderr:
            'No compiler found. Tried: ${compilerCandidates.join(", ")}\n'
            'Please install one of these and ensure it is on your PATH.',
        exitCode: 1,
        elapsed: Duration.zero,
        command: '',
      );
    }

    // Output binary name
    final baseName = p.basenameWithoutExtension(filePath);
    final outputPath = p.join(workingDir, baseName);
    final args = compileArgs(compiler, filePath, outputPath);
    final compileCommand = args.join(' ');

    final stopwatch = Stopwatch()..start();

    // Compile
    try {
      final compileResult = await Process.run(
        args[0],
        args.sublist(1),
        workingDirectory: workingDir,
        environment: Platform.environment,
      ).timeout(timeout);

      if (compileResult.exitCode != 0) {
        stopwatch.stop();
        return ExecutionResult(
          stdout: '',
          stderr:
              '--- Compilation Failed ---\n${compileResult.stderr}',
          exitCode: compileResult.exitCode,
          elapsed: stopwatch.elapsed,
          command: compileCommand,
        );
      }
    } on TimeoutException {
      stopwatch.stop();
      return ExecutionResult(
        stdout: '',
        stderr: 'Compilation timed out after ${timeout.inSeconds}s',
        exitCode: 124,
        elapsed: stopwatch.elapsed,
        command: compileCommand,
      );
    } catch (e) {
      stopwatch.stop();
      return ExecutionResult(
        stdout: '',
        stderr: 'Compilation failed: $e',
        exitCode: 1,
        elapsed: stopwatch.elapsed,
        command: compileCommand,
      );
    }

    // Run the compiled binary
    final runCommand = './$baseName';
    try {
      final runResult = await Process.run(
        outputPath,
        [],
        workingDirectory: workingDir,
        environment: Platform.environment,
      ).timeout(timeout);

      stopwatch.stop();

      // Clean up binary
      try {
        await File(outputPath).delete();
      } catch (_) {}

      return ExecutionResult(
        stdout: runResult.stdout.toString(),
        stderr: runResult.stderr.toString(),
        exitCode: runResult.exitCode,
        elapsed: stopwatch.elapsed,
        command: '$compileCommand && $runCommand',
      );
    } on TimeoutException {
      stopwatch.stop();
      try {
        await File(outputPath).delete();
      } catch (_) {}
      return ExecutionResult(
        stdout: '',
        stderr: 'Execution timed out after ${timeout.inSeconds}s',
        exitCode: 124,
        elapsed: stopwatch.elapsed,
        command: runCommand,
      );
    } catch (e) {
      stopwatch.stop();
      return ExecutionResult(
        stdout: '',
        stderr: 'Execution failed: $e',
        exitCode: 1,
        elapsed: stopwatch.elapsed,
        command: runCommand,
      );
    }
  }

  /// Open an HTML file — on desktop, try xdg-open / open / start
  Future<ExecutionResult> _openHtml(String filePath) async {
    final stopwatch = Stopwatch()..start();
    String opener;

    if (Platform.isLinux) {
      opener = 'xdg-open';
    } else if (Platform.isMacOS) {
      opener = 'open';
    } else if (Platform.isWindows) {
      opener = 'start';
    } else {
      stopwatch.stop();
      return ExecutionResult(
        stdout: '',
        stderr: 'Cannot open HTML on this platform.',
        exitCode: 1,
        elapsed: stopwatch.elapsed,
        command: '',
      );
    }

    try {
      // On Windows, 'start' is a cmd built-in, not a standalone executable.
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', filePath]);
      } else {
        await Process.run(opener, [filePath]);
      }
      stopwatch.stop();
      return ExecutionResult(
        stdout: 'Opened $filePath in default browser.',
        stderr: '',
        exitCode: 0,
        elapsed: stopwatch.elapsed,
        command: '$opener ${p.basename(filePath)}',
      );
    } catch (e) {
      stopwatch.stop();
      return ExecutionResult(
        stdout: '',
        stderr: 'Failed to open HTML file: $e',
        exitCode: 1,
        elapsed: stopwatch.elapsed,
        command: '$opener ${p.basename(filePath)}',
      );
    }
  }

  /// Find the first available executable from a list of candidates
  Future<String?> _findExecutable(List<String> candidates) async {
    for (final candidate in candidates) {
      if (_compilerCache.containsKey(candidate)) {
        if (_compilerCache[candidate] != null) return _compilerCache[candidate];
        continue;
      }

      try {
        final result = await Process.run(
          Platform.isWindows ? 'where' : 'which',
          [candidate],
        );
        if (result.exitCode == 0) {
          final path = result.stdout.toString().trim().split('\n').first.trim();
          _compilerCache[candidate] = path;
          return path;
        } else {
          _compilerCache[candidate] = null;
        }
      } catch (_) {
        _compilerCache[candidate] = null;
      }
    }
    return null;
  }
}
