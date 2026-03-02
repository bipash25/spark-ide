import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spark_ide/models/classroom.dart';

/// Service for classroom CRUD operations via Firestore.
class ClassroomService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _classrooms =>
      _firestore.collection('classrooms');

  CollectionReference<Map<String, dynamic>> _assignments(String classroomId) =>
      _classrooms.doc(classroomId).collection('assignments');

  CollectionReference<Map<String, dynamic>> _submissions(
    String classroomId,
    String assignmentId,
  ) =>
      _classrooms
          .doc(classroomId)
          .collection('assignments')
          .doc(assignmentId)
          .collection('submissions');

  // ==================== Classroom CRUD ====================

  /// Create a new classroom.
  Future<Classroom> createClassroom({
    required String name,
    required String description,
    required String teacherId,
    required String teacherName,
  }) async {
    final doc = _classrooms.doc();
    final now = DateTime.now();
    final classroom = Classroom(
      id: doc.id,
      name: name,
      description: description,
      teacherId: teacherId,
      teacherName: teacherName,
      joinCode: _generateJoinCode(),
      createdAt: now,
      updatedAt: now,
    );
    await doc.set(classroom.toMap());
    return classroom;
  }

  /// Get a classroom by ID.
  Future<Classroom?> getClassroom(String id) async {
    final doc = await _classrooms.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return Classroom.fromMap(doc.data()!);
  }

  /// Get a classroom by join code.
  Future<Classroom?> getClassroomByJoinCode(String joinCode) async {
    final query = await _classrooms
        .where('joinCode', isEqualTo: joinCode.toUpperCase())
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return Classroom.fromMap(query.docs.first.data());
  }

  /// Get all classrooms for a teacher.
  Future<List<Classroom>> getTeacherClassrooms(String teacherId) async {
    final query = await _classrooms
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('updatedAt', descending: true)
        .get();
    return query.docs.map((doc) => Classroom.fromMap(doc.data())).toList();
  }

  /// Get all classrooms a student has joined.
  Future<List<Classroom>> getStudentClassrooms(String studentId) async {
    final query = await _classrooms
        .where('studentIds', arrayContains: studentId)
        .orderBy('updatedAt', descending: true)
        .get();
    return query.docs.map((doc) => Classroom.fromMap(doc.data())).toList();
  }

  /// Join a classroom using a join code.
  Future<Classroom> joinClassroom({
    required String joinCode,
    required String studentId,
  }) async {
    final classroom = await getClassroomByJoinCode(joinCode);
    if (classroom == null) {
      throw ClassroomException('Invalid join code. Classroom not found.');
    }
    if (classroom.teacherId == studentId) {
      throw ClassroomException('You are the teacher of this classroom.');
    }
    if (classroom.studentIds.contains(studentId)) {
      throw ClassroomException('You are already in this classroom.');
    }

    final updatedStudents = [...classroom.studentIds, studentId];
    await _classrooms.doc(classroom.id).update({
      'studentIds': updatedStudents,
      'updatedAt': DateTime.now().toIso8601String(),
    });

    return classroom.copyWith(studentIds: updatedStudents);
  }

  /// Leave a classroom (student only).
  Future<void> leaveClassroom({
    required String classroomId,
    required String studentId,
  }) async {
    await _classrooms.doc(classroomId).update({
      'studentIds': FieldValue.arrayRemove([studentId]),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Update classroom details.
  Future<void> updateClassroom(Classroom classroom) async {
    await _classrooms.doc(classroom.id).set(
      classroom.copyWith(updatedAt: DateTime.now()).toMap(),
      SetOptions(merge: true),
    );
  }

  /// Delete a classroom and all its assignments/submissions.
  Future<void> deleteClassroom(String classroomId) async {
    // Delete all assignments (and their submissions)
    final assignments = await _assignments(classroomId).get();
    for (final assignDoc in assignments.docs) {
      final subs = await _submissions(classroomId, assignDoc.id).get();
      for (final sub in subs.docs) {
        await sub.reference.delete();
      }
      await assignDoc.reference.delete();
    }
    await _classrooms.doc(classroomId).delete();
  }

  /// Regenerate join code for a classroom.
  Future<String> regenerateJoinCode(String classroomId) async {
    final newCode = _generateJoinCode();
    await _classrooms.doc(classroomId).update({
      'joinCode': newCode,
      'updatedAt': DateTime.now().toIso8601String(),
    });
    return newCode;
  }

  // ==================== Assignment CRUD ====================

  /// Create an assignment in a classroom.
  Future<Assignment> createAssignment({
    required String classroomId,
    required String title,
    required String description,
    required String teacherId,
    required Map<String, String> files,
    required String language,
    DateTime? dueDate,
  }) async {
    final doc = _assignments(classroomId).doc();
    final assignment = Assignment(
      id: doc.id,
      classroomId: classroomId,
      title: title,
      description: description,
      teacherId: teacherId,
      files: files,
      language: language,
      createdAt: DateTime.now(),
      dueDate: dueDate,
    );
    await doc.set(assignment.toMap());

    // Update classroom timestamp
    await _classrooms.doc(classroomId).update({
      'updatedAt': DateTime.now().toIso8601String(),
    });

    return assignment;
  }

  /// Get all assignments for a classroom.
  Future<List<Assignment>> getAssignments(String classroomId) async {
    final query = await _assignments(classroomId)
        .orderBy('createdAt', descending: true)
        .get();
    return query.docs.map((doc) => Assignment.fromMap(doc.data())).toList();
  }

  /// Get a single assignment.
  Future<Assignment?> getAssignment(
    String classroomId,
    String assignmentId,
  ) async {
    final doc = await _assignments(classroomId).doc(assignmentId).get();
    if (!doc.exists || doc.data() == null) return null;
    return Assignment.fromMap(doc.data()!);
  }

  /// Update an assignment.
  Future<void> updateAssignment(Assignment assignment) async {
    await _assignments(assignment.classroomId)
        .doc(assignment.id)
        .set(assignment.toMap(), SetOptions(merge: true));
  }

  /// Delete an assignment.
  Future<void> deleteAssignment(
    String classroomId,
    String assignmentId,
  ) async {
    // Delete all submissions first
    final subs = await _submissions(classroomId, assignmentId).get();
    for (final sub in subs.docs) {
      await sub.reference.delete();
    }
    await _assignments(classroomId).doc(assignmentId).delete();
  }

  /// Close/reopen an assignment.
  Future<void> toggleAssignment(
    String classroomId,
    String assignmentId,
    bool isOpen,
  ) async {
    await _assignments(classroomId).doc(assignmentId).update({
      'isOpen': isOpen,
    });
  }

  // ==================== Submission CRUD ====================

  /// Submit or update a submission.
  Future<Submission> submitWork({
    required String classroomId,
    required String assignmentId,
    required String studentId,
    required String studentName,
    required Map<String, String> files,
  }) async {
    // Check if student already submitted
    final existing = await getStudentSubmission(
      classroomId,
      assignmentId,
      studentId,
    );

    if (existing != null) {
      // Update existing submission
      final updated = existing.copyWith(
        files: files,
        updatedAt: DateTime.now(),
      );
      await _submissions(classroomId, assignmentId)
          .doc(existing.id)
          .set(updated.toMap(), SetOptions(merge: true));
      return updated;
    }

    // New submission
    final doc = _submissions(classroomId, assignmentId).doc();
    final submission = Submission(
      id: doc.id,
      assignmentId: assignmentId,
      classroomId: classroomId,
      studentId: studentId,
      studentName: studentName,
      files: files,
      submittedAt: DateTime.now(),
    );
    await doc.set(submission.toMap());
    return submission;
  }

  /// Get all submissions for an assignment.
  Future<List<Submission>> getSubmissions(
    String classroomId,
    String assignmentId,
  ) async {
    final query = await _submissions(classroomId, assignmentId)
        .orderBy('submittedAt', descending: true)
        .get();
    return query.docs.map((doc) => Submission.fromMap(doc.data())).toList();
  }

  /// Get a specific student's submission.
  Future<Submission?> getStudentSubmission(
    String classroomId,
    String assignmentId,
    String studentId,
  ) async {
    final query = await _submissions(classroomId, assignmentId)
        .where('studentId', isEqualTo: studentId)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return Submission.fromMap(query.docs.first.data());
  }

  /// Grade a submission (teacher only).
  Future<void> gradeSubmission({
    required String classroomId,
    required String assignmentId,
    required String submissionId,
    required int grade,
    String? feedback,
  }) async {
    await _submissions(classroomId, assignmentId)
        .doc(submissionId)
        .update({
      'grade': grade,
      'feedback': feedback,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  // ==================== Helpers ====================

  /// Generate a 6-character alphanumeric join code.
  String _generateJoinCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no I/O/0/1
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}

class ClassroomException implements Exception {
  final String message;
  const ClassroomException(this.message);

  @override
  String toString() => message;
}
