import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_ide/services/lsp/lsp_client.dart';
import 'package:spark_ide/services/lsp/lsp_server_registry.dart';

/// State for the LSP manager
class LspState {
  /// Active LSP clients keyed by language ID
  final Map<String, LspClient> clients;

  /// Diagnostics keyed by file URI
  final Map<String, List<LspDiagnostic>> diagnostics;

  /// Available servers (language -> isAvailable)
  final Map<String, bool> availability;

  /// Whether the LSP system is enabled
  final bool enabled;

  /// Root URI of the current workspace
  final String? rootUri;

  const LspState({
    this.clients = const {},
    this.diagnostics = const {},
    this.availability = const {},
    this.enabled = true,
    this.rootUri,
  });

  LspState copyWith({
    Map<String, LspClient>? clients,
    Map<String, List<LspDiagnostic>>? diagnostics,
    Map<String, bool>? availability,
    bool? enabled,
    String? rootUri,
  }) {
    return LspState(
      clients: clients ?? this.clients,
      diagnostics: diagnostics ?? this.diagnostics,
      availability: availability ?? this.availability,
      enabled: enabled ?? this.enabled,
      rootUri: rootUri ?? this.rootUri,
    );
  }

  /// Get diagnostics for a specific file path
  List<LspDiagnostic> getDiagnosticsForFile(String filePath) {
    final uri = _filePathToUri(filePath);
    return diagnostics[uri] ?? const [];
  }

  /// Get total error count across all files
  int get errorCount => diagnostics.values
      .expand((d) => d)
      .where((d) => d.isError)
      .length;

  /// Get total warning count across all files
  int get warningCount => diagnostics.values
      .expand((d) => d)
      .where((d) => d.isWarning)
      .length;

  static String _filePathToUri(String path) {
    if (path.startsWith('file://')) return path;
    return 'file://$path';
  }
}

/// Manages LSP client lifecycle, connects to language servers,
/// and broadcasts diagnostics to the UI.
class LspNotifier extends StateNotifier<LspState> {
  final Map<String, StreamSubscription> _diagnosticSubs = {};
  final Set<String> _openDocuments = {};

  LspNotifier() : super(const LspState());

  /// Set the workspace root and check available servers.
  Future<void> setWorkspace(String rootPath) async {
    final rootUri = 'file://$rootPath';
    final availability = await LspServerRegistry.checkAvailability();

    state = state.copyWith(
      rootUri: rootUri,
      availability: availability,
    );
  }

  /// Start the LSP client for a given language, if a server is available.
  Future<bool> startClient(String languageId) async {
    if (!state.enabled || state.rootUri == null) return false;

    // Already running?
    if (state.clients.containsKey(languageId) &&
        state.clients[languageId]!.isRunning) {
      return true;
    }

    // Check for shared language servers (e.g., clangd for C and C++)
    final config = LspServerRegistry.getConfig(languageId);
    if (config == null) return false;

    // See if a shared client is already running
    for (final shared in config.sharedWith) {
      if (state.clients.containsKey(shared) &&
          state.clients[shared]!.isRunning) {
        // Reuse the existing client
        final newClients = Map<String, LspClient>.from(state.clients);
        newClients[languageId] = state.clients[shared]!;
        state = state.copyWith(clients: newClients);
        return true;
      }
    }

    // Find the actual command
    final command = await LspServerRegistry.findServerCommand(languageId);
    if (command == null) return false;

    final client = LspClient(
      serverCommand: command,
      serverArgs: config.args,
    );

    final success = await client.start(state.rootUri!);
    if (!success) return false;

    // Listen for diagnostics
    final sub = client.diagnostics.listen((params) {
      _onDiagnostics(params);
    });
    _diagnosticSubs[languageId] = sub;

    final newClients = Map<String, LspClient>.from(state.clients);
    newClients[languageId] = client;
    state = state.copyWith(clients: newClients);

    return true;
  }

  /// Stop the LSP client for a given language.
  Future<void> stopClient(String languageId) async {
    final client = state.clients[languageId];
    if (client == null) return;

    await _diagnosticSubs[languageId]?.cancel();
    _diagnosticSubs.remove(languageId);

    await client.stop();

    final newClients = Map<String, LspClient>.from(state.clients);
    newClients.remove(languageId);
    state = state.copyWith(clients: newClients);
  }

  /// Stop all running LSP clients.
  Future<void> stopAll() async {
    for (final sub in _diagnosticSubs.values) {
      await sub.cancel();
    }
    _diagnosticSubs.clear();
    _openDocuments.clear();

    for (final client in state.clients.values) {
      await client.stop();
    }

    state = state.copyWith(
      clients: {},
      diagnostics: {},
    );
  }

  /// Get the LSP client for a language, starting it if needed.
  Future<LspClient?> getClient(String languageId) async {
    if (state.clients.containsKey(languageId) &&
        state.clients[languageId]!.isRunning) {
      return state.clients[languageId];
    }

    final started = await startClient(languageId);
    return started ? state.clients[languageId] : null;
  }

  /// Notify the appropriate LSP client that a document was opened.
  Future<void> didOpenDocument(
      String filePath, String languageId, String text) async {
    // Avoid sending duplicate didOpen for already-opened documents
    if (_openDocuments.contains(filePath)) return;

    final client = await getClient(languageId);
    if (client == null) return;

    _openDocuments.add(filePath);
    final uri = 'file://$filePath';
    client.didOpen(uri, languageId, text, 1);
  }

  /// Notify the appropriate LSP client of a document change.
  void didChangeDocument(
      String filePath, String languageId, String text, int version) {
    final client = state.clients[languageId];
    if (client == null || !client.isRunning) return;

    final uri = 'file://$filePath';
    client.didChange(uri, text, version);
  }

  /// Notify the appropriate LSP client that a document was saved.
  void didSaveDocument(String filePath, String languageId, String text) {
    final client = state.clients[languageId];
    if (client == null || !client.isRunning) return;

    final uri = 'file://$filePath';
    client.didSave(uri, text);
  }

  /// Notify the appropriate LSP client that a document was closed.
  void didCloseDocument(String filePath, String languageId) {
    _openDocuments.remove(filePath);

    final client = state.clients[languageId];
    if (client == null || !client.isRunning) return;

    final uri = 'file://$filePath';
    client.didClose(uri);
  }

  /// Request completions from the LSP server.
  Future<List<dynamic>?> getCompletions(
      String filePath, String languageId, int line, int character) async {
    final client = state.clients[languageId];
    if (client == null || !client.isRunning) return null;

    final uri = 'file://$filePath';
    return client.completion(uri, line, character);
  }

  /// Request hover info from the LSP server.
  Future<Map<String, dynamic>?> getHover(
      String filePath, String languageId, int line, int character) async {
    final client = state.clients[languageId];
    if (client == null || !client.isRunning) return null;

    final uri = 'file://$filePath';
    return client.hover(uri, line, character);
  }

  /// Request go-to-definition from the LSP server.
  Future<List<dynamic>?> getDefinition(
      String filePath, String languageId, int line, int character) async {
    final client = state.clients[languageId];
    if (client == null || !client.isRunning) return null;

    final uri = 'file://$filePath';
    return client.definition(uri, line, character);
  }

  /// Toggle LSP on/off
  void toggleEnabled() {
    if (state.enabled) {
      stopAll();
    }
    state = state.copyWith(enabled: !state.enabled);
  }

  /// Clear diagnostics for a specific file.
  void clearDiagnostics(String filePath) {
    final uri = 'file://$filePath';
    final newDiagnostics = Map<String, List<LspDiagnostic>>.from(state.diagnostics);
    newDiagnostics.remove(uri);
    state = state.copyWith(diagnostics: newDiagnostics);
  }

  void _onDiagnostics(LspDiagnosticsParams params) {
    final newDiagnostics = Map<String, List<LspDiagnostic>>.from(state.diagnostics);
    if (params.diagnostics.isEmpty) {
      newDiagnostics.remove(params.uri);
    } else {
      newDiagnostics[params.uri] = params.diagnostics;
    }
    state = state.copyWith(diagnostics: newDiagnostics);
  }

  @override
  void dispose() {
    stopAll();
    super.dispose();
  }
}

/// Riverpod provider for the LSP manager
final lspProvider = StateNotifierProvider<LspNotifier, LspState>((ref) {
  return LspNotifier();
});
