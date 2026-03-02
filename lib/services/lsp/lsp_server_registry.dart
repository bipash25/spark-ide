import 'dart:io';

/// Registry of known language servers and how to launch them.
///
/// Maps language IDs to the command/args needed to start the
/// corresponding LSP server. The IDE will attempt to find these
/// on the system PATH and only enable LSP for languages where
/// the server binary is available.
class LspServerRegistry {
  /// Known language server configurations.
  static const _servers = <String, LspServerConfig>{
    'python': LspServerConfig(
      languageId: 'python',
      command: 'pylsp',
      args: [],
      displayName: 'Python Language Server',
      alternativeCommands: ['pyls', 'python-language-server'],
    ),
    'dart': LspServerConfig(
      languageId: 'dart',
      command: 'dart',
      args: ['language-server', '--protocol=lsp'],
      displayName: 'Dart Analysis Server',
    ),
    'javascript': LspServerConfig(
      languageId: 'javascript',
      command: 'typescript-language-server',
      args: ['--stdio'],
      displayName: 'TypeScript/JavaScript Language Server',
      sharedWith: ['typescript', 'javascriptreact', 'typescriptreact'],
    ),
    'typescript': LspServerConfig(
      languageId: 'typescript',
      command: 'typescript-language-server',
      args: ['--stdio'],
      displayName: 'TypeScript Language Server',
      sharedWith: ['javascript', 'javascriptreact', 'typescriptreact'],
    ),
    'c': LspServerConfig(
      languageId: 'c',
      command: 'clangd',
      args: [],
      displayName: 'Clangd (C/C++)',
      sharedWith: ['cpp'],
    ),
    'cpp': LspServerConfig(
      languageId: 'cpp',
      command: 'clangd',
      args: [],
      displayName: 'Clangd (C/C++)',
      sharedWith: ['c'],
    ),
    'rust': LspServerConfig(
      languageId: 'rust',
      command: 'rust-analyzer',
      args: [],
      displayName: 'Rust Analyzer',
    ),
    'go': LspServerConfig(
      languageId: 'go',
      command: 'gopls',
      args: [],
      displayName: 'gopls (Go)',
    ),
    'java': LspServerConfig(
      languageId: 'java',
      command: 'jdtls',
      args: [],
      displayName: 'Eclipse JDT Language Server',
    ),
    'html': LspServerConfig(
      languageId: 'html',
      command: 'vscode-html-language-server',
      args: ['--stdio'],
      displayName: 'HTML Language Server',
    ),
    'css': LspServerConfig(
      languageId: 'css',
      command: 'vscode-css-language-server',
      args: ['--stdio'],
      displayName: 'CSS Language Server',
      sharedWith: ['scss', 'less'],
    ),
    'json': LspServerConfig(
      languageId: 'json',
      command: 'vscode-json-language-server',
      args: ['--stdio'],
      displayName: 'JSON Language Server',
    ),
    'yaml': LspServerConfig(
      languageId: 'yaml',
      command: 'yaml-language-server',
      args: ['--stdio'],
      displayName: 'YAML Language Server',
    ),
    'shellscript': LspServerConfig(
      languageId: 'shellscript',
      command: 'bash-language-server',
      args: ['start'],
      displayName: 'Bash Language Server',
    ),
    'sql': LspServerConfig(
      languageId: 'sql',
      command: 'sql-language-server',
      args: ['up', '--method', 'stdio'],
      displayName: 'SQL Language Server',
    ),
  };

  /// Get the server config for a language, if one exists.
  static LspServerConfig? getConfig(String languageId) {
    return _servers[languageId];
  }

  /// Get all known server configs.
  static Map<String, LspServerConfig> get allConfigs => _servers;

  /// Check if a server binary is available on the system.
  static Future<bool> isServerAvailable(String languageId) async {
    final config = _servers[languageId];
    if (config == null) return false;

    // Try the primary command
    if (await _commandExists(config.command)) return true;

    // Try alternative commands
    for (final alt in config.alternativeCommands) {
      if (await _commandExists(alt)) return true;
    }

    return false;
  }

  /// Find the actual command to use (tries primary, then alternatives).
  static Future<String?> findServerCommand(String languageId) async {
    final config = _servers[languageId];
    if (config == null) return null;

    if (await _commandExists(config.command)) return config.command;

    for (final alt in config.alternativeCommands) {
      if (await _commandExists(alt)) return alt;
    }

    return null;
  }

  /// Check which language servers are available on this system.
  static Future<Map<String, bool>> checkAvailability() async {
    final results = <String, bool>{};
    for (final entry in _servers.entries) {
      results[entry.key] = await isServerAvailable(entry.key);
    }
    return results;
  }

  static Future<bool> _commandExists(String command) async {
    try {
      final result = await Process.run('which', [command]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}

/// Configuration for a language server.
class LspServerConfig {
  final String languageId;
  final String command;
  final List<String> args;
  final String displayName;
  final List<String> alternativeCommands;
  final List<String> sharedWith;

  const LspServerConfig({
    required this.languageId,
    required this.command,
    this.args = const [],
    required this.displayName,
    this.alternativeCommands = const [],
    this.sharedWith = const [],
  });
}
