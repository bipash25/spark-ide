/// Represents a classroom where a teacher shares code with students.
class Classroom {
  final String id;
  final String name;
  final String description;
  final String teacherId;
  final String teacherName;
  final String joinCode;
  final List<String> studentIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Classroom({
    required this.id,
    required this.name,
    this.description = '',
    required this.teacherId,
    required this.teacherName,
    required this.joinCode,
    this.studentIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  int get studentCount => studentIds.length;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'joinCode': joinCode,
      'studentIds': studentIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Classroom.fromMap(Map<String, dynamic> map) {
    return Classroom(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      teacherId: map['teacherId'] as String,
      teacherName: map['teacherName'] as String? ?? '',
      joinCode: map['joinCode'] as String,
      studentIds: List<String>.from(map['studentIds'] as List? ?? []),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  Classroom copyWith({
    String? id,
    String? name,
    String? description,
    String? teacherId,
    String? teacherName,
    String? joinCode,
    List<String>? studentIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Classroom(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      joinCode: joinCode ?? this.joinCode,
      studentIds: studentIds ?? this.studentIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Classroom &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// A code assignment shared by a teacher in a classroom.
class Assignment {
  final String id;
  final String classroomId;
  final String title;
  final String description;
  final String teacherId;
  final Map<String, String> files; // filename -> content
  final String language;
  final DateTime createdAt;
  final DateTime? dueDate;
  final bool isOpen;

  const Assignment({
    required this.id,
    required this.classroomId,
    required this.title,
    this.description = '',
    required this.teacherId,
    this.files = const {},
    this.language = 'plaintext',
    required this.createdAt,
    this.dueDate,
    this.isOpen = true,
  });

  bool get isOverdue =>
      dueDate != null && DateTime.now().isAfter(dueDate!) && isOpen;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'classroomId': classroomId,
      'title': title,
      'description': description,
      'teacherId': teacherId,
      'files': files,
      'language': language,
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'isOpen': isOpen,
    };
  }

  factory Assignment.fromMap(Map<String, dynamic> map) {
    return Assignment(
      id: map['id'] as String,
      classroomId: map['classroomId'] as String,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      teacherId: map['teacherId'] as String,
      files: Map<String, String>.from(map['files'] as Map? ?? {}),
      language: map['language'] as String? ?? 'plaintext',
      createdAt: DateTime.parse(map['createdAt'] as String),
      dueDate: map['dueDate'] != null
          ? DateTime.parse(map['dueDate'] as String)
          : null,
      isOpen: map['isOpen'] as bool? ?? true,
    );
  }

  Assignment copyWith({
    String? id,
    String? classroomId,
    String? title,
    String? description,
    String? teacherId,
    Map<String, String>? files,
    String? language,
    DateTime? createdAt,
    DateTime? dueDate,
    bool? isOpen,
  }) {
    return Assignment(
      id: id ?? this.id,
      classroomId: classroomId ?? this.classroomId,
      title: title ?? this.title,
      description: description ?? this.description,
      teacherId: teacherId ?? this.teacherId,
      files: files ?? this.files,
      language: language ?? this.language,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      isOpen: isOpen ?? this.isOpen,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Assignment &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// A student's submission for an assignment.
class Submission {
  final String id;
  final String assignmentId;
  final String classroomId;
  final String studentId;
  final String studentName;
  final Map<String, String> files; // filename -> content
  final DateTime submittedAt;
  final DateTime? updatedAt;
  final String? feedback;
  final int? grade;

  const Submission({
    required this.id,
    required this.assignmentId,
    required this.classroomId,
    required this.studentId,
    required this.studentName,
    this.files = const {},
    required this.submittedAt,
    this.updatedAt,
    this.feedback,
    this.grade,
  });

  bool get isGraded => grade != null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'assignmentId': assignmentId,
      'classroomId': classroomId,
      'studentId': studentId,
      'studentName': studentName,
      'files': files,
      'submittedAt': submittedAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'feedback': feedback,
      'grade': grade,
    };
  }

  factory Submission.fromMap(Map<String, dynamic> map) {
    return Submission(
      id: map['id'] as String,
      assignmentId: map['assignmentId'] as String,
      classroomId: map['classroomId'] as String,
      studentId: map['studentId'] as String,
      studentName: map['studentName'] as String? ?? '',
      files: Map<String, String>.from(map['files'] as Map? ?? {}),
      submittedAt: DateTime.parse(map['submittedAt'] as String),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
      feedback: map['feedback'] as String?,
      grade: map['grade'] as int?,
    );
  }

  Submission copyWith({
    String? id,
    String? assignmentId,
    String? classroomId,
    String? studentId,
    String? studentName,
    Map<String, String>? files,
    DateTime? submittedAt,
    DateTime? updatedAt,
    String? feedback,
    int? grade,
  }) {
    return Submission(
      id: id ?? this.id,
      assignmentId: assignmentId ?? this.assignmentId,
      classroomId: classroomId ?? this.classroomId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      files: files ?? this.files,
      submittedAt: submittedAt ?? this.submittedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      feedback: feedback ?? this.feedback,
      grade: grade ?? this.grade,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Submission &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
