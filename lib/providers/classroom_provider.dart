import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_ide/models/classroom.dart';
import 'package:spark_ide/services/classroom/classroom_service.dart';

/// Provider for the classroom service singleton.
final classroomServiceProvider =
    Provider<ClassroomService>((ref) => ClassroomService());

/// Provider for classroom state.
final classroomProvider =
    StateNotifierProvider<ClassroomNotifier, ClassroomState>((ref) {
  final service = ref.watch(classroomServiceProvider);
  return ClassroomNotifier(service);
});

/// Classroom state.
class ClassroomState {
  final List<Classroom> classrooms;
  final Classroom? activeClassroom;
  final List<Assignment> assignments;
  final Assignment? activeAssignment;
  final List<Submission> submissions;
  final bool isLoading;
  final String? error;
  final String? successMessage;

  const ClassroomState({
    this.classrooms = const [],
    this.activeClassroom,
    this.assignments = const [],
    this.activeAssignment,
    this.submissions = const [],
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  ClassroomState copyWith({
    List<Classroom>? classrooms,
    Classroom? activeClassroom,
    List<Assignment>? assignments,
    Assignment? activeAssignment,
    List<Submission>? submissions,
    bool? isLoading,
    String? error,
    String? successMessage,
    bool clearActiveClassroom = false,
    bool clearActiveAssignment = false,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return ClassroomState(
      classrooms: classrooms ?? this.classrooms,
      activeClassroom:
          clearActiveClassroom ? null : (activeClassroom ?? this.activeClassroom),
      assignments: assignments ?? this.assignments,
      activeAssignment: clearActiveAssignment
          ? null
          : (activeAssignment ?? this.activeAssignment),
      submissions: submissions ?? this.submissions,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

/// Classroom state notifier.
class ClassroomNotifier extends StateNotifier<ClassroomState> {
  final ClassroomService _service;

  ClassroomNotifier(this._service) : super(const ClassroomState());

  // ==================== Load Classrooms ====================

  /// Load classrooms for the current user (teacher or student).
  Future<void> loadClassrooms(String userId, bool isTeacher) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final classrooms = isTeacher
          ? await _service.getTeacherClassrooms(userId)
          : await _service.getStudentClassrooms(userId);
      state = state.copyWith(classrooms: classrooms, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ==================== Classroom CRUD ====================

  /// Create a new classroom (teacher).
  Future<void> createClassroom({
    required String name,
    required String description,
    required String teacherId,
    required String teacherName,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final classroom = await _service.createClassroom(
        name: name,
        description: description,
        teacherId: teacherId,
        teacherName: teacherName,
      );
      state = state.copyWith(
        classrooms: [classroom, ...state.classrooms],
        isLoading: false,
        successMessage: 'Classroom created! Join code: ${classroom.joinCode}',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Join a classroom using a join code (student).
  Future<void> joinClassroom({
    required String joinCode,
    required String studentId,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final classroom = await _service.joinClassroom(
        joinCode: joinCode,
        studentId: studentId,
      );
      state = state.copyWith(
        classrooms: [classroom, ...state.classrooms],
        isLoading: false,
        successMessage: 'Joined "${classroom.name}" successfully!',
      );
    } on ClassroomException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Leave a classroom (student).
  Future<void> leaveClassroom(String classroomId, String studentId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _service.leaveClassroom(
        classroomId: classroomId,
        studentId: studentId,
      );
      state = state.copyWith(
        classrooms:
            state.classrooms.where((c) => c.id != classroomId).toList(),
        isLoading: false,
        clearActiveClassroom: state.activeClassroom?.id == classroomId,
        successMessage: 'Left classroom.',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Delete a classroom (teacher).
  Future<void> deleteClassroom(String classroomId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _service.deleteClassroom(classroomId);
      state = state.copyWith(
        classrooms:
            state.classrooms.where((c) => c.id != classroomId).toList(),
        isLoading: false,
        clearActiveClassroom: state.activeClassroom?.id == classroomId,
        successMessage: 'Classroom deleted.',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Regenerate join code (teacher).
  Future<void> regenerateJoinCode(String classroomId) async {
    try {
      final newCode = await _service.regenerateJoinCode(classroomId);
      final updated = state.classrooms.map((c) {
        if (c.id == classroomId) return c.copyWith(joinCode: newCode);
        return c;
      }).toList();
      state = state.copyWith(
        classrooms: updated,
        activeClassroom: state.activeClassroom?.id == classroomId
            ? state.activeClassroom!.copyWith(joinCode: newCode)
            : state.activeClassroom,
        successMessage: 'New join code: $newCode',
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Select a classroom and load its assignments.
  Future<void> selectClassroom(Classroom classroom) async {
    state = state.copyWith(
      activeClassroom: classroom,
      isLoading: true,
      clearActiveAssignment: true,
      clearError: true,
    );
    try {
      final assignments = await _service.getAssignments(classroom.id);
      state = state.copyWith(assignments: assignments, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Go back to classroom list.
  void deselectClassroom() {
    state = state.copyWith(
      clearActiveClassroom: true,
      clearActiveAssignment: true,
      assignments: const [],
      submissions: const [],
    );
  }

  // ==================== Assignment CRUD ====================

  /// Create an assignment (teacher).
  Future<void> createAssignment({
    required String classroomId,
    required String title,
    required String description,
    required String teacherId,
    required Map<String, String> files,
    required String language,
    DateTime? dueDate,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final assignment = await _service.createAssignment(
        classroomId: classroomId,
        title: title,
        description: description,
        teacherId: teacherId,
        files: files,
        language: language,
        dueDate: dueDate,
      );
      state = state.copyWith(
        assignments: [assignment, ...state.assignments],
        isLoading: false,
        successMessage: 'Assignment created!',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Delete an assignment (teacher).
  Future<void> deleteAssignment(String classroomId, String assignmentId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _service.deleteAssignment(classroomId, assignmentId);
      state = state.copyWith(
        assignments:
            state.assignments.where((a) => a.id != assignmentId).toList(),
        isLoading: false,
        clearActiveAssignment: state.activeAssignment?.id == assignmentId,
        successMessage: 'Assignment deleted.',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Toggle assignment open/closed.
  Future<void> toggleAssignment(
    String classroomId,
    String assignmentId,
    bool isOpen,
  ) async {
    try {
      await _service.toggleAssignment(classroomId, assignmentId, isOpen);
      final updated = state.assignments.map((a) {
        if (a.id == assignmentId) return a.copyWith(isOpen: isOpen);
        return a;
      }).toList();
      state = state.copyWith(assignments: updated);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Select an assignment and load its submissions.
  Future<void> selectAssignment(Assignment assignment) async {
    state = state.copyWith(
      activeAssignment: assignment,
      isLoading: true,
      clearError: true,
    );
    try {
      final submissions =
          await _service.getSubmissions(assignment.classroomId, assignment.id);
      state = state.copyWith(submissions: submissions, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Go back to assignments list.
  void deselectAssignment() {
    state = state.copyWith(
      clearActiveAssignment: true,
      submissions: const [],
    );
  }

  // ==================== Submission CRUD ====================

  /// Submit work (student).
  Future<void> submitWork({
    required String classroomId,
    required String assignmentId,
    required String studentId,
    required String studentName,
    required Map<String, String> files,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final submission = await _service.submitWork(
        classroomId: classroomId,
        assignmentId: assignmentId,
        studentId: studentId,
        studentName: studentName,
        files: files,
      );
      // Replace or add submission
      final existing =
          state.submissions.indexWhere((s) => s.studentId == studentId);
      final updated = [...state.submissions];
      if (existing >= 0) {
        updated[existing] = submission;
      } else {
        updated.insert(0, submission);
      }
      state = state.copyWith(
        submissions: updated,
        isLoading: false,
        successMessage: 'Work submitted!',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Grade a submission (teacher).
  Future<void> gradeSubmission({
    required String classroomId,
    required String assignmentId,
    required String submissionId,
    required int grade,
    String? feedback,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _service.gradeSubmission(
        classroomId: classroomId,
        assignmentId: assignmentId,
        submissionId: submissionId,
        grade: grade,
        feedback: feedback,
      );
      final updated = state.submissions.map((s) {
        if (s.id == submissionId) {
          return s.copyWith(grade: grade, feedback: feedback);
        }
        return s;
      }).toList();
      state = state.copyWith(
        submissions: updated,
        isLoading: false,
        successMessage: 'Grade saved.',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Clear error/success messages.
  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}
