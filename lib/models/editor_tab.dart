import 'package:path/path.dart' as p;

/// Represents an open editor tab
class EditorTab {
  final String id;
  final String filePath;
  final String fileName;
  final String content;
  final String savedContent;
  final bool isPinned;
  final int cursorLine;
  final int cursorColumn;
  final int scrollOffset;

  const EditorTab({
    required this.id,
    required this.filePath,
    required this.fileName,
    required this.content,
    required this.savedContent,
    this.isPinned = false,
    this.cursorLine = 0,
    this.cursorColumn = 0,
    this.scrollOffset = 0,
  });

  /// Whether the tab has unsaved changes
  bool get isDirty => content != savedContent;

  /// File extension
  String get extension => p.extension(fileName).toLowerCase();

  /// Language ID based on extension
  String get languageId {
    switch (extension) {
      case '.dart':
        return 'dart';
      case '.py':
      case '.pyw':
        return 'python';
      case '.js':
        return 'javascript';
      case '.jsx':
        return 'javascriptreact';
      case '.ts':
        return 'typescript';
      case '.tsx':
        return 'typescriptreact';
      case '.html':
      case '.htm':
        return 'html';
      case '.css':
        return 'css';
      case '.scss':
        return 'scss';
      case '.sass':
        return 'sass';
      case '.less':
        return 'less';
      case '.json':
        return 'json';
      case '.xml':
        return 'xml';
      case '.yaml':
      case '.yml':
        return 'yaml';
      case '.md':
      case '.markdown':
        return 'markdown';
      case '.c':
        return 'c';
      case '.cpp':
      case '.cc':
      case '.cxx':
        return 'cpp';
      case '.h':
      case '.hpp':
        return 'cpp';
      case '.java':
        return 'java';
      case '.kt':
      case '.kts':
        return 'kotlin';
      case '.swift':
        return 'swift';
      case '.go':
        return 'go';
      case '.rs':
        return 'rust';
      case '.rb':
        return 'ruby';
      case '.php':
        return 'php';
      case '.cs':
        return 'csharp';
      case '.sql':
        return 'sql';
      case '.sh':
      case '.bash':
        return 'shellscript';
      case '.bat':
      case '.cmd':
        return 'bat';
      case '.ps1':
        return 'powershell';
      case '.r':
        return 'r';
      case '.lua':
        return 'lua';
      case '.toml':
        return 'toml';
      case '.ini':
      case '.cfg':
        return 'ini';
      case '.env':
        return 'dotenv';
      case '.dockerfile':
        return 'dockerfile';
      case '.gitignore':
        return 'gitignore';
      case '.svg':
        return 'xml';
      default:
        return 'plaintext';
    }
  }

  EditorTab copyWith({
    String? id,
    String? filePath,
    String? fileName,
    String? content,
    String? savedContent,
    bool? isPinned,
    int? cursorLine,
    int? cursorColumn,
    int? scrollOffset,
  }) {
    return EditorTab(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      content: content ?? this.content,
      savedContent: savedContent ?? this.savedContent,
      isPinned: isPinned ?? this.isPinned,
      cursorLine: cursorLine ?? this.cursorLine,
      cursorColumn: cursorColumn ?? this.cursorColumn,
      scrollOffset: scrollOffset ?? this.scrollOffset,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EditorTab &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
