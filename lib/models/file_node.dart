import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// Represents a file or directory in the file tree
class FileNode {
  final String name;
  final String path;
  final bool isDirectory;
  final bool isExpanded;
  final List<FileNode> children;
  final int depth;

  const FileNode({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.isExpanded = false,
    this.children = const [],
    this.depth = 0,
  });

  FileNode copyWith({
    String? name,
    String? path,
    bool? isDirectory,
    bool? isExpanded,
    List<FileNode>? children,
    int? depth,
  }) {
    return FileNode(
      name: name ?? this.name,
      path: path ?? this.path,
      isDirectory: isDirectory ?? this.isDirectory,
      isExpanded: isExpanded ?? this.isExpanded,
      children: children ?? this.children,
      depth: depth ?? this.depth,
    );
  }

  String get extension => p.extension(name).toLowerCase();

  IconData get icon {
    if (isDirectory) {
      return isExpanded ? Icons.folder_open : Icons.folder;
    }
    return _getFileIcon(extension);
  }

  Color get iconColor {
    if (isDirectory) return const Color(0xFF89B4FA);
    return _getFileColor(extension);
  }

  static IconData _getFileIcon(String ext) {
    switch (ext) {
      case '.dart':
      case '.py':
      case '.js':
      case '.ts':
      case '.jsx':
      case '.tsx':
      case '.java':
      case '.kt':
      case '.swift':
      case '.go':
      case '.rs':
      case '.c':
      case '.cpp':
      case '.h':
      case '.hpp':
      case '.cs':
      case '.rb':
      case '.php':
        return Icons.code;
      case '.html':
      case '.htm':
      case '.xml':
      case '.svg':
        return Icons.web;
      case '.css':
      case '.scss':
      case '.sass':
      case '.less':
        return Icons.style;
      case '.json':
      case '.yaml':
      case '.yml':
      case '.toml':
      case '.ini':
      case '.env':
        return Icons.settings;
      case '.md':
      case '.txt':
      case '.rtf':
      case '.doc':
        return Icons.description;
      case '.png':
      case '.jpg':
      case '.jpeg':
      case '.gif':
      case '.bmp':
      case '.webp':
      case '.ico':
        return Icons.image;
      case '.sql':
        return Icons.storage;
      case '.sh':
      case '.bash':
      case '.zsh':
      case '.bat':
      case '.cmd':
      case '.ps1':
        return Icons.terminal;
      case '.gitignore':
      case '.gitmodules':
        return Icons.merge_type;
      case '.lock':
        return Icons.lock;
      default:
        return Icons.insert_drive_file;
    }
  }

  static Color _getFileColor(String ext) {
    switch (ext) {
      case '.dart':
        return const Color(0xFF89B4FA);
      case '.py':
        return const Color(0xFFF9E2AF);
      case '.js':
      case '.jsx':
        return const Color(0xFFF9E2AF);
      case '.ts':
      case '.tsx':
        return const Color(0xFF89B4FA);
      case '.html':
      case '.htm':
        return const Color(0xFFF38BA8);
      case '.css':
      case '.scss':
      case '.sass':
        return const Color(0xFF89DCEB);
      case '.json':
        return const Color(0xFFF9E2AF);
      case '.md':
        return const Color(0xFF89B4FA);
      case '.c':
      case '.cpp':
      case '.h':
      case '.hpp':
        return const Color(0xFF89DCEB);
      case '.java':
        return const Color(0xFFFAB387);
      case '.go':
        return const Color(0xFF89DCEB);
      case '.rs':
        return const Color(0xFFFAB387);
      case '.sql':
        return const Color(0xFFF5C2E7);
      case '.sh':
      case '.bash':
        return const Color(0xFFA6E3A1);
      default:
        return const Color(0xFFBAC2DE);
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileNode &&
          runtimeType == other.runtimeType &&
          path == other.path;

  @override
  int get hashCode => path.hashCode;
}
