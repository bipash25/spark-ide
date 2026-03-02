import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A JSON-RPC 2.0 client for the Language Server Protocol.
///
/// Manages the lifecycle of a language server process and provides
/// methods for sending requests, notifications, and handling responses.
class LspClient {
  final String serverCommand;
  final List<String> serverArgs;
  final String? workingDirectory;

  Process? _process;
  int _nextId = 1;
  final _pendingRequests = <int, Completer<dynamic>>{};
  final _buffer = StringBuffer();
  int? _expectedContentLength;

  /// Stream of notifications from the server
  final _notificationController =
      StreamController<LspNotification>.broadcast();
  Stream<LspNotification> get notifications => _notificationController.stream;

  /// Stream of diagnostics specifically
  final _diagnosticsController =
      StreamController<LspDiagnosticsParams>.broadcast();
  Stream<LspDiagnosticsParams> get diagnostics =>
      _diagnosticsController.stream;

  /// Whether the client is connected and initialized
  bool _initialized = false;
  bool get isInitialized => _initialized;
  bool get isRunning => _process != null;

  /// Server capabilities received during initialization
  Map<String, dynamic>? serverCapabilities;

  LspClient({
    required this.serverCommand,
    this.serverArgs = const [],
    this.workingDirectory,
  });

  /// Start the language server process and perform initialization handshake.
  Future<bool> start(String rootUri) async {
    try {
      _process = await Process.start(
        serverCommand,
        serverArgs,
        workingDirectory: workingDirectory,
      );

      // Listen to stdout for responses
      _process!.stdout.listen(
        _onData,
        onError: (error) {
          _cleanup();
        },
        onDone: _cleanup,
      );

      // Listen to stderr for diagnostics/logs (ignore, don't crash)
      _process!.stderr.listen((_) {});

      // Send initialize request
      final result = await sendRequest('initialize', {
        'processId': pid,
        'rootUri': rootUri,
        'capabilities': _clientCapabilities(),
        'trace': 'off',
      });

      if (result != null && result is Map<String, dynamic>) {
        serverCapabilities = result['capabilities'] as Map<String, dynamic>?;
      }

      // Send initialized notification
      sendNotification('initialized', {});
      _initialized = true;
      return true;
    } catch (e) {
      _cleanup();
      return false;
    }
  }

  /// Stop the language server gracefully.
  Future<void> stop() async {
    if (_process == null) return;

    try {
      // Send shutdown request
      await sendRequest('shutdown', null).timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );
      // Send exit notification
      sendNotification('exit', null);
    } catch (_) {}

    // Give the process a moment to exit, then kill
    await Future.delayed(const Duration(milliseconds: 500));
    _process?.kill();
    _cleanup();
  }

  /// Send a JSON-RPC request and wait for the response.
  Future<dynamic> sendRequest(String method, dynamic params) {
    if (_process == null) {
      return Future.error('LSP client not running');
    }

    final id = _nextId++;
    final completer = Completer<dynamic>();
    _pendingRequests[id] = completer;

    final message = <String, dynamic>{
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
    };
    if (params != null) {
      message['params'] = params;
    }

    _send(message);
    return completer.future;
  }

  /// Send a JSON-RPC notification (no response expected).
  void sendNotification(String method, dynamic params) {
    if (_process == null) return;

    final message = <String, dynamic>{
      'jsonrpc': '2.0',
      'method': method,
    };
    if (params != null) {
      message['params'] = params;
    }

    _send(message);
  }

  // --- Document sync methods ---

  /// Notify the server that a document was opened.
  void didOpen(String uri, String languageId, String text, int version) {
    sendNotification('textDocument/didOpen', {
      'textDocument': {
        'uri': uri,
        'languageId': languageId,
        'version': version,
        'text': text,
      },
    });
  }

  /// Notify the server of a full document change.
  void didChange(String uri, String text, int version) {
    sendNotification('textDocument/didChange', {
      'textDocument': {
        'uri': uri,
        'version': version,
      },
      'contentChanges': [
        {'text': text},
      ],
    });
  }

  /// Notify the server that a document was saved.
  void didSave(String uri, String text) {
    sendNotification('textDocument/didSave', {
      'textDocument': {'uri': uri},
      'text': text,
    });
  }

  /// Notify the server that a document was closed.
  void didClose(String uri) {
    sendNotification('textDocument/didClose', {
      'textDocument': {'uri': uri},
    });
  }

  // --- LSP feature requests ---

  /// Request completions at a position.
  Future<List<dynamic>?> completion(
      String uri, int line, int character) async {
    try {
      final result = await sendRequest('textDocument/completion', {
        'textDocument': {'uri': uri},
        'position': {'line': line, 'character': character},
      });
      if (result is Map && result.containsKey('items')) {
        return result['items'] as List<dynamic>;
      }
      if (result is List) {
        return result;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Request hover information at a position.
  Future<Map<String, dynamic>?> hover(
      String uri, int line, int character) async {
    try {
      final result = await sendRequest('textDocument/hover', {
        'textDocument': {'uri': uri},
        'position': {'line': line, 'character': character},
      });
      if (result is Map<String, dynamic>) {
        return result;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Request go-to-definition at a position.
  Future<List<dynamic>?> definition(
      String uri, int line, int character) async {
    try {
      final result = await sendRequest('textDocument/definition', {
        'textDocument': {'uri': uri},
        'position': {'line': line, 'character': character},
      });
      if (result is List) {
        return result;
      }
      if (result is Map) {
        return [result];
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // --- Private methods ---

  void _send(Map<String, dynamic> message) {
    final body = jsonEncode(message);
    final header = 'Content-Length: ${utf8.encode(body).length}\r\n\r\n';
    _process!.stdin.write(header);
    _process!.stdin.write(body);
  }

  void _onData(List<int> data) {
    _buffer.write(utf8.decode(data));
    _processBuffer();
  }

  void _processBuffer() {
    while (true) {
      final content = _buffer.toString();

      if (_expectedContentLength == null) {
        // Look for Content-Length header
        final headerEnd = content.indexOf('\r\n\r\n');
        if (headerEnd == -1) return; // Not enough data yet

        final header = content.substring(0, headerEnd);
        final match = RegExp(r'Content-Length:\s*(\d+)').firstMatch(header);
        if (match == null) {
          // Invalid header, skip
          _buffer.clear();
          return;
        }

        _expectedContentLength = int.parse(match.group(1)!);
        // Remove header from buffer
        _buffer.clear();
        _buffer.write(content.substring(headerEnd + 4));
      }

      // Check if we have enough data for the body
      final remaining = _buffer.toString();
      final bodyBytes = utf8.encode(remaining);
      if (bodyBytes.length < _expectedContentLength!) return;

      // Extract the body
      final body = utf8.decode(bodyBytes.sublist(0, _expectedContentLength!));
      final rest = utf8.decode(bodyBytes.sublist(_expectedContentLength!));
      _expectedContentLength = null;
      _buffer.clear();
      _buffer.write(rest);

      // Parse and handle the message
      try {
        final message = jsonDecode(body) as Map<String, dynamic>;
        _handleMessage(message);
      } catch (_) {
        // Skip malformed messages
      }
    }
  }

  void _handleMessage(Map<String, dynamic> message) {
    if (message.containsKey('id') && message.containsKey('result')) {
      // Response to a request
      final id = message['id'] as int;
      final completer = _pendingRequests.remove(id);
      completer?.complete(message['result']);
    } else if (message.containsKey('id') && message.containsKey('error')) {
      // Error response
      final id = message['id'] as int;
      final completer = _pendingRequests.remove(id);
      final error = message['error'];
      completer?.completeError(
        LspError(
          code: error['code'] as int? ?? -1,
          message: error['message'] as String? ?? 'Unknown error',
        ),
      );
    } else if (message.containsKey('method') &&
        !message.containsKey('id')) {
      // Notification from server
      final method = message['method'] as String;
      final params = message['params'];

      _notificationController.add(LspNotification(
        method: method,
        params: params,
      ));

      // Handle specific notifications
      if (method == 'textDocument/publishDiagnostics' &&
          params is Map<String, dynamic>) {
        _handleDiagnostics(params);
      }
    } else if (message.containsKey('method') &&
        message.containsKey('id')) {
      // Server request — respond with empty result
      final id = message['id'];
      _send({
        'jsonrpc': '2.0',
        'id': id,
        'result': null,
      });
    }
  }

  void _handleDiagnostics(Map<String, dynamic> params) {
    final uri = params['uri'] as String? ?? '';
    final diagnosticsList = params['diagnostics'] as List<dynamic>? ?? [];

    final diagnostics = diagnosticsList.map((d) {
      final range = d['range'] as Map<String, dynamic>? ?? {};
      final start = range['start'] as Map<String, dynamic>? ?? {};
      final end = range['end'] as Map<String, dynamic>? ?? {};

      return LspDiagnostic(
        message: d['message'] as String? ?? '',
        severity: d['severity'] as int? ?? 1,
        startLine: start['line'] as int? ?? 0,
        startCharacter: start['character'] as int? ?? 0,
        endLine: end['line'] as int? ?? 0,
        endCharacter: end['character'] as int? ?? 0,
        source: d['source'] as String?,
        code: d['code']?.toString(),
      );
    }).toList();

    _diagnosticsController.add(LspDiagnosticsParams(
      uri: uri,
      diagnostics: diagnostics,
    ));
  }

  void _cleanup() {
    _initialized = false;
    _process = null;
    for (final completer in _pendingRequests.values) {
      completer.completeError('LSP client disconnected');
    }
    _pendingRequests.clear();
    _buffer.clear();
    _expectedContentLength = null;
  }

  Map<String, dynamic> _clientCapabilities() {
    return {
      'textDocument': {
        'synchronization': {
          'dynamicRegistration': false,
          'willSave': false,
          'willSaveWaitUntil': false,
          'didSave': true,
        },
        'completion': {
          'dynamicRegistration': false,
          'completionItem': {
            'snippetSupport': false,
            'documentationFormat': ['plaintext'],
          },
        },
        'hover': {
          'dynamicRegistration': false,
          'contentFormat': ['plaintext'],
        },
        'definition': {
          'dynamicRegistration': false,
        },
        'publishDiagnostics': {
          'relatedInformation': false,
        },
      },
      'workspace': {
        'workspaceFolders': false,
      },
    };
  }

  /// Dispose of all resources.
  Future<void> dispose() async {
    await stop();
    await _notificationController.close();
    await _diagnosticsController.close();
  }
}

/// A notification received from the language server.
class LspNotification {
  final String method;
  final dynamic params;

  const LspNotification({required this.method, this.params});
}

/// Diagnostics published for a file.
class LspDiagnosticsParams {
  final String uri;
  final List<LspDiagnostic> diagnostics;

  const LspDiagnosticsParams({
    required this.uri,
    required this.diagnostics,
  });
}

/// A single diagnostic (error, warning, etc.).
class LspDiagnostic {
  final String message;
  final int severity; // 1=Error, 2=Warning, 3=Info, 4=Hint
  final int startLine;
  final int startCharacter;
  final int endLine;
  final int endCharacter;
  final String? source;
  final String? code;

  const LspDiagnostic({
    required this.message,
    required this.severity,
    required this.startLine,
    required this.startCharacter,
    required this.endLine,
    required this.endCharacter,
    this.source,
    this.code,
  });

  bool get isError => severity == 1;
  bool get isWarning => severity == 2;
  bool get isInfo => severity == 3;
  bool get isHint => severity == 4;
}

/// An error from the language server.
class LspError implements Exception {
  final int code;
  final String message;

  const LspError({required this.code, required this.message});

  @override
  String toString() => 'LspError($code): $message';
}
