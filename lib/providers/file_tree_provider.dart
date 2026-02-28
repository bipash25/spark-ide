import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_ide/models/file_node.dart';
import 'package:spark_ide/services/file_system/file_system_service.dart';
import 'package:spark_ide/providers/tab_provider.dart';

/// State for the file explorer
class FileTreeState {
  final FileNode? root;
  final String? rootPath;
  final bool isLoading;
  final String? error;
  final Set<String> expandedPaths;

  const FileTreeState({
    this.root,
    this.rootPath,
    this.isLoading = false,
    this.error,
    this.expandedPaths = const {},
  });

  FileTreeState copyWith({
    FileNode? root,
    String? rootPath,
    bool? isLoading,
    String? error,
    Set<String>? expandedPaths,
  }) {
    return FileTreeState(
      root: root ?? this.root,
      rootPath: rootPath ?? this.rootPath,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      expandedPaths: expandedPaths ?? this.expandedPaths,
    );
  }
}

/// Manages the file explorer tree
class FileTreeNotifier extends StateNotifier<FileTreeState> {
  final FileSystemService _fileService;

  FileTreeNotifier(this._fileService) : super(const FileTreeState());

  /// Open a folder as the workspace root
  Future<void> openFolder(String path) async {
    state = state.copyWith(isLoading: true, rootPath: path, error: null);

    try {
      final root = await _fileService.buildFileTree(path);
      state = state.copyWith(
        root: root,
        isLoading: false,
        expandedPaths: {path},
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Toggle expand/collapse for a directory
  Future<void> toggleExpanded(FileNode node) async {
    if (!node.isDirectory) return;

    final expanded = Set<String>.from(state.expandedPaths);

    if (expanded.contains(node.path)) {
      expanded.remove(node.path);
      state = state.copyWith(expandedPaths: expanded);
    } else {
      expanded.add(node.path);
      // Load children if not loaded
      if (node.children.isEmpty) {
        final loaded = await _fileService.loadChildren(node);
        final newRoot = _updateNodeInTree(state.root!, node.path, loaded);
        state = state.copyWith(root: newRoot, expandedPaths: expanded);
      } else {
        state = state.copyWith(expandedPaths: expanded);
      }
    }
  }

  /// Refresh the file tree
  Future<void> refresh() async {
    if (state.rootPath == null) return;
    await openFolder(state.rootPath!);
  }

  /// Create a new file in the given directory
  Future<void> createFile(String dirPath, String fileName) async {
    final filePath = '$dirPath/$fileName';
    await _fileService.createFile(filePath);
    await refresh();
  }

  /// Create a new directory
  Future<void> createDirectory(String parentPath, String dirName) async {
    final dirPath = '$parentPath/$dirName';
    await _fileService.createDirectory(dirPath);
    await refresh();
  }

  /// Delete a file or directory
  Future<void> delete(String path) async {
    await _fileService.delete(path);
    await refresh();
  }

  /// Rename a file or directory
  Future<void> rename(String oldPath, String newName) async {
    await _fileService.rename(oldPath, newName);
    await refresh();
  }

  bool isExpanded(String path) => state.expandedPaths.contains(path);

  /// Recursively update a node in the tree
  FileNode _updateNodeInTree(FileNode current, String targetPath, FileNode replacement) {
    if (current.path == targetPath) return replacement;
    if (!current.isDirectory) return current;

    return current.copyWith(
      children: current.children
          .map((child) => _updateNodeInTree(child, targetPath, replacement))
          .toList(),
    );
  }
}

final fileTreeProvider =
    StateNotifierProvider<FileTreeNotifier, FileTreeState>((ref) {
  final fileService = ref.watch(fileSystemServiceProvider);
  return FileTreeNotifier(fileService);
});
