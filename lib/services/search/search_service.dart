import 'dart:io';
import 'package:path/path.dart' as p;

/// A single match within a file
class SearchMatch {
  final String filePath;
  final String fileName;
  final String relativePath;
  final int line;
  final int column;
  final String lineContent;
  final int matchStart;
  final int matchEnd;

  const SearchMatch({
    required this.filePath,
    required this.fileName,
    required this.relativePath,
    required this.line,
    required this.column,
    required this.lineContent,
    required this.matchStart,
    required this.matchEnd,
  });
}

/// Groups matches by file
class FileSearchResult {
  final String filePath;
  final String fileName;
  final String relativePath;
  final List<SearchMatch> matches;

  const FileSearchResult({
    required this.filePath,
    required this.fileName,
    required this.relativePath,
    required this.matches,
  });

  int get matchCount => matches.length;
}

/// Service for searching across files in a project directory
class SearchService {
  static const _ignoredDirectories = {
    'node_modules',
    '__pycache__',
    '.git',
    '.svn',
    '.hg',
    'build',
    'dist',
    '.dart_tool',
    '.idea',
    '.vscode',
    'target',
    '.gradle',
    'Pods',
    '.next',
    'coverage',
    '.cache',
  };

  static const _binaryExtensions = {
    '.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp', '.ico',
    '.mp3', '.mp4', '.avi', '.mov', '.mkv', '.wav', '.flac',
    '.zip', '.tar', '.gz', '.rar', '.7z',
    '.exe', '.dll', '.so', '.dylib', '.o', '.a',
    '.pdf', '.doc', '.docx', '.xls', '.xlsx',
    '.ttf', '.otf', '.woff', '.woff2', '.eot',
    '.class', '.pyc', '.pyo',
  };

  /// Search for a query string across all files in [rootPath].
  ///
  /// Returns results grouped by file. Supports case sensitivity, whole word
  /// matching, and regex mode.
  Future<List<FileSearchResult>> search({
    required String rootPath,
    required String query,
    bool caseSensitive = false,
    bool wholeWord = false,
    bool useRegex = false,
  }) async {
    if (query.isEmpty) return [];

    final Pattern pattern;
    try {
      pattern = _buildPattern(query, caseSensitive, wholeWord, useRegex);
    } catch (_) {
      // Invalid regex
      return [];
    }

    final results = <FileSearchResult>[];
    await _searchDirectory(
      Directory(rootPath),
      rootPath,
      pattern,
      results,
    );

    // Sort by file path
    results.sort((a, b) => a.relativePath.compareTo(b.relativePath));
    return results;
  }

  Pattern _buildPattern(
    String query,
    bool caseSensitive,
    bool wholeWord,
    bool useRegex,
  ) {
    String regexSource;
    if (useRegex) {
      regexSource = query;
    } else {
      regexSource = RegExp.escape(query);
    }

    if (wholeWord) {
      regexSource = '\\b$regexSource\\b';
    }

    return RegExp(regexSource, caseSensitive: caseSensitive);
  }

  Future<void> _searchDirectory(
    Directory dir,
    String rootPath,
    Pattern pattern,
    List<FileSearchResult> results,
  ) async {
    List<FileSystemEntity> entities;
    try {
      entities = await dir.list().toList();
    } catch (_) {
      return;
    }

    for (final entity in entities) {
      final name = p.basename(entity.path);

      // Skip hidden files/dirs (except .env)
      if (name.startsWith('.') && name != '.env') continue;

      if (entity is Directory) {
        if (_ignoredDirectories.contains(name)) continue;
        await _searchDirectory(entity, rootPath, pattern, results);
      } else if (entity is File) {
        final ext = p.extension(name).toLowerCase();
        if (_binaryExtensions.contains(ext)) continue;

        // Skip files larger than 1MB
        try {
          final stat = await entity.stat();
          if (stat.size > 1024 * 1024) continue;
        } catch (_) {
          continue;
        }

        final fileMatches = await _searchFile(entity, rootPath, pattern);
        if (fileMatches != null) {
          results.add(fileMatches);
        }
      }
    }
  }

  Future<FileSearchResult?> _searchFile(
    File file,
    String rootPath,
    Pattern pattern,
  ) async {
    String content;
    try {
      content = await file.readAsString();
    } catch (_) {
      // Binary file or encoding error
      return null;
    }

    final lines = content.split('\n');
    final matches = <SearchMatch>[];
    final fileName = p.basename(file.path);
    final relativePath = p.relative(file.path, from: rootPath);

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineMatches = pattern.allMatches(line);

      for (final match in lineMatches) {
        matches.add(SearchMatch(
          filePath: file.path,
          fileName: fileName,
          relativePath: relativePath,
          line: i + 1,
          column: match.start + 1,
          lineContent: line,
          matchStart: match.start,
          matchEnd: match.end,
        ));
      }
    }

    if (matches.isEmpty) return null;

    return FileSearchResult(
      filePath: file.path,
      fileName: fileName,
      relativePath: relativePath,
      matches: matches,
    );
  }
}
