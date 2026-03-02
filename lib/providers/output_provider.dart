import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_ide/services/compiler/compiler_service.dart';

/// State for code execution output
class OutputState {
  final String output;
  final bool isRunning;
  final String? command;
  final int? exitCode;
  final Duration? elapsed;
  final String? error;

  const OutputState({
    this.output = '',
    this.isRunning = false,
    this.command,
    this.exitCode,
    this.elapsed,
    this.error,
  });

  OutputState copyWith({
    String? output,
    bool? isRunning,
    String? command,
    int? exitCode,
    Duration? elapsed,
    String? error,
  }) {
    return OutputState(
      output: output ?? this.output,
      isRunning: isRunning ?? this.isRunning,
      command: command ?? this.command,
      exitCode: exitCode ?? this.exitCode,
      elapsed: elapsed ?? this.elapsed,
      error: error ?? this.error,
    );
  }

  bool get hasOutput => output.isNotEmpty || error != null;
}

/// Manages code execution and output state
class OutputNotifier extends StateNotifier<OutputState> {
  final CompilerService _compilerService;

  OutputNotifier(this._compilerService) : super(const OutputState());

  /// Run the given file
  Future<void> runFile(String filePath, {String? workingDirectory}) async {
    final target = _compilerService.detectTarget(filePath);

    if (target == ExecutionTarget.unsupported) {
      state = OutputState(
        output: '',
        isRunning: false,
        error: 'Cannot run this file type.',
      );
      return;
    }

    state = OutputState(
      output: '--- Running ${_compilerService.targetName(target)} ---\n',
      isRunning: true,
      command: filePath,
    );

    final result = await _compilerService.execute(
      filePath,
      workingDirectory: workingDirectory,
    );

    final buf = StringBuffer();
    buf.write(state.output);

    if (result.command.isNotEmpty) {
      buf.writeln('\$ ${result.command}');
    }

    if (result.stdout.isNotEmpty) {
      buf.write(result.stdout);
      if (!result.stdout.endsWith('\n')) buf.writeln();
    }

    if (result.stderr.isNotEmpty) {
      buf.write(result.stderr);
      if (!result.stderr.endsWith('\n')) buf.writeln();
    }

    buf.writeln();
    if (result.success) {
      buf.writeln(
          '--- Process exited with code ${result.exitCode} (${result.elapsed.inMilliseconds}ms) ---');
    } else {
      buf.writeln(
          '--- Process failed with code ${result.exitCode} (${result.elapsed.inMilliseconds}ms) ---');
    }

    state = OutputState(
      output: buf.toString(),
      isRunning: false,
      command: result.command,
      exitCode: result.exitCode,
      elapsed: result.elapsed,
    );
  }

  /// Clear the output
  void clear() {
    state = const OutputState();
  }
}

final compilerServiceProvider = Provider<CompilerService>((ref) {
  return CompilerService();
});

final outputProvider =
    StateNotifierProvider<OutputNotifier, OutputState>((ref) {
  final compiler = ref.watch(compilerServiceProvider);
  return OutputNotifier(compiler);
});
