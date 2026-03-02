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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileNode &&
          runtimeType == other.runtimeType &&
          path == other.path;

  @override
  int get hashCode => path.hashCode;
}
