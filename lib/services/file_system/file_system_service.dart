import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:spark_ide/models/file_node.dart';

/// Service for file system operations with platform abstraction
class FileSystemService {
  /// Read file contents
  Future<String> readFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('File not found', path);
    }
    return file.readAsString();
  }

  /// Write file contents
  Future<void> writeFile(String path, String content) async {
    final file = File(path);
    await file.writeAsString(content);
  }

  /// Create a new file
  Future<void> createFile(String path, {String content = ''}) async {
    final file = File(path);
    if (await file.exists()) {
      throw FileSystemException('File already exists', path);
    }
    await file.create(recursive: true);
    if (content.isNotEmpty) {
      await file.writeAsString(content);
    }
  }

  /// Create a new directory
  Future<void> createDirectory(String path) async {
    final dir = Directory(path);
    if (await dir.exists()) {
      throw FileSystemException('Directory already exists', path);
    }
    await dir.create(recursive: true);
  }

  /// Delete a file or directory
  Future<void> delete(String path) async {
    final type = await FileSystemEntity.type(path);
    if (type == FileSystemEntityType.directory) {
      await Directory(path).delete(recursive: true);
    } else if (type == FileSystemEntityType.file) {
      await File(path).delete();
    }
  }

  /// Rename a file or directory
  Future<String> rename(String oldPath, String newName) async {
    final dir = p.dirname(oldPath);
    final newPath = p.join(dir, newName);
    final type = await FileSystemEntity.type(oldPath);
    if (type == FileSystemEntityType.directory) {
      await Directory(oldPath).rename(newPath);
    } else {
      await File(oldPath).rename(newPath);
    }
    return newPath;
  }

  /// Check if a path exists
  Future<bool> exists(String path) async {
    return FileSystemEntity.type(path) !=
        Future.value(FileSystemEntityType.notFound);
  }

  /// List directory contents and build a FileNode tree
  Future<FileNode> buildFileTree(String rootPath, {int depth = 0}) async {
    final dir = Directory(rootPath);
    if (!await dir.exists()) {
      throw FileSystemException('Directory not found', rootPath);
    }

    final name = p.basename(rootPath);
    final children = <FileNode>[];

    try {
      final entities = await dir.list().toList();

      // Sort: directories first, then alphabetically
      entities.sort((a, b) {
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;
        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;
        return p
            .basename(a.path)
            .toLowerCase()
            .compareTo(p.basename(b.path).toLowerCase());
      });

      for (final entity in entities) {
        final entityName = p.basename(entity.path);

        // Skip hidden files and common non-essential directories
        if (entityName.startsWith('.') && entityName != '.env') continue;
        if (_ignoredDirectories.contains(entityName)) continue;

        if (entity is Directory) {
          children.add(FileNode(
            name: entityName,
            path: entity.path,
            isDirectory: true,
            depth: depth + 1,
          ));
        } else if (entity is File) {
          children.add(FileNode(
            name: entityName,
            path: entity.path,
            isDirectory: false,
            depth: depth + 1,
          ));
        }
      }
    } catch (e) {
      // Permission denied or other errors - return empty children
    }

    return FileNode(
      name: name,
      path: rootPath,
      isDirectory: true,
      isExpanded: depth == 0,
      children: children,
      depth: depth,
    );
  }

  /// Recursively load children for a directory node
  Future<FileNode> loadChildren(FileNode node) async {
    if (!node.isDirectory) return node;
    final loaded = await buildFileTree(node.path, depth: node.depth);
    return node.copyWith(
      children: loaded.children,
      isExpanded: true,
    );
  }

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
}
