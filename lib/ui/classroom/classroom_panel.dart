import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_ide/core/theme/theme_provider.dart';
import 'package:spark_ide/core/theme/spark_theme.dart';
import 'package:spark_ide/core/config/firebase_config.dart';
import 'package:spark_ide/providers/auth_provider.dart';
import 'package:spark_ide/providers/classroom_provider.dart';
import 'package:spark_ide/providers/tab_provider.dart';
import 'package:spark_ide/models/classroom.dart';
import 'dart:io';

/// Classroom panel shown in the sidebar.
class ClassroomPanel extends ConsumerStatefulWidget {
  const ClassroomPanel({super.key});

  @override
  ConsumerState<ClassroomPanel> createState() => _ClassroomPanelState();
}

class _ClassroomPanelState extends ConsumerState<ClassroomPanel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClassrooms();
    });
  }

  void _loadClassrooms() {
    final authState = ref.read(authProvider);
    if (authState.isSignedIn) {
      ref.read(classroomProvider.notifier).loadClassrooms(
            authState.profile!.uid,
            authState.isTeacher,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeColorsProvider);
    final authState = ref.watch(authProvider);
    final classState = ref.watch(classroomProvider);

    if (!FirebaseConfig.isConfigured) {
      return _NotConfiguredView(colors: colors);
    }

    if (!authState.isSignedIn) {
      return _NotSignedInView(colors: colors);
    }

    // Show assignment detail view
    if (classState.activeAssignment != null) {
      return _AssignmentDetailView(
        colors: colors,
        isTeacher: authState.isTeacher,
      );
    }

    // Show classroom detail view
    if (classState.activeClassroom != null) {
      return _ClassroomDetailView(
        colors: colors,
        isTeacher: authState.isTeacher,
      );
    }

    // Show classroom list
    return _ClassroomListView(
      colors: colors,
      isTeacher: authState.isTeacher,
    );
  }
}

/// Prompt when Firebase is not configured.
class _NotConfiguredView extends StatelessWidget {
  final ThemeColors colors;
  const _NotConfiguredView({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colors.sidebarBackground,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: 'CLASSROOMS', colors: colors),
          const SizedBox(height: 24),
          Icon(Icons.cloud_off, size: 32, color: colors.foreground.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(
            'Firebase is not configured.\nSet up Firebase to use classrooms.',
            style: TextStyle(
              color: colors.foreground.withValues(alpha: 0.5),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Prompt when user is not signed in.
class _NotSignedInView extends StatelessWidget {
  final ThemeColors colors;
  const _NotSignedInView({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colors.sidebarBackground,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: 'CLASSROOMS', colors: colors),
          const SizedBox(height: 24),
          Icon(Icons.person_outline, size: 32, color: colors.foreground.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(
            'Sign in to access classrooms.',
            style: TextStyle(
              color: colors.foreground.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Use the account icon in the activity bar to sign in.',
            style: TextStyle(
              color: colors.foreground.withValues(alpha: 0.35),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// List of classrooms.
class _ClassroomListView extends ConsumerWidget {
  final ThemeColors colors;
  final bool isTeacher;

  const _ClassroomListView({
    required this.colors,
    required this.isTeacher,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classState = ref.watch(classroomProvider);

    return Container(
      color: colors.sidebarBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with actions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
            child: Row(
              children: [
                Expanded(
                  child: _SectionHeader(
                    title: 'CLASSROOMS',
                    colors: colors,
                  ),
                ),
                if (isTeacher)
                  _HeaderButton(
                    icon: Icons.add,
                    tooltip: 'Create Classroom',
                    colors: colors,
                    onTap: () => _showCreateDialog(context, ref),
                  ),
                _HeaderButton(
                  icon: Icons.login,
                  tooltip: 'Join Classroom',
                  colors: colors,
                  onTap: () => _showJoinDialog(context, ref),
                ),
                _HeaderButton(
                  icon: Icons.refresh,
                  tooltip: 'Refresh',
                  colors: colors,
                  onTap: () {
                    final auth = ref.read(authProvider);
                    if (auth.isSignedIn) {
                      ref.read(classroomProvider.notifier).loadClassrooms(
                            auth.profile!.uid,
                            auth.isTeacher,
                          );
                    }
                  },
                ),
              ],
            ),
          ),

          // Error/success messages
          if (classState.error != null)
            _MessageBar(
              message: classState.error!,
              isError: true,
              colors: colors,
              onDismiss: () =>
                  ref.read(classroomProvider.notifier).clearMessages(),
            ),
          if (classState.successMessage != null)
            _MessageBar(
              message: classState.successMessage!,
              isError: false,
              colors: colors,
              onDismiss: () =>
                  ref.read(classroomProvider.notifier).clearMessages(),
            ),

          // Loading
          if (classState.isLoading && classState.classrooms.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.primary,
                  ),
                ),
              ),
            ),

          // Classroom list
          if (classState.classrooms.isEmpty && !classState.isLoading)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                isTeacher
                    ? 'No classrooms yet.\nClick + to create one.'
                    : 'No classrooms yet.\nAsk your teacher for a join code.',
                style: TextStyle(
                  color: colors.foreground.withValues(alpha: 0.4),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 2),
              itemCount: classState.classrooms.length,
              itemBuilder: (context, index) {
                final classroom = classState.classrooms[index];
                return _ClassroomTile(
                  classroom: classroom,
                  isTeacher: isTeacher,
                  colors: colors,
                  onTap: () => ref
                      .read(classroomProvider.notifier)
                      .selectClassroom(classroom),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return _InputDialog(
          title: 'Create Classroom',
          colors: colors,
          fields: [
            _DialogField(controller: nameCtrl, label: 'Name', autofocus: true),
            _DialogField(controller: descCtrl, label: 'Description (optional)'),
          ],
          confirmLabel: 'Create',
          onConfirm: () {
            final name = nameCtrl.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(ctx);
            final auth = ref.read(authProvider);
            ref.read(classroomProvider.notifier).createClassroom(
                  name: name,
                  description: descCtrl.text.trim(),
                  teacherId: auth.profile!.uid,
                  teacherName: auth.profile!.displayName,
                );
          },
        );
      },
    );
  }

  void _showJoinDialog(BuildContext context, WidgetRef ref) {
    final codeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return _InputDialog(
          title: 'Join Classroom',
          colors: colors,
          fields: [
            _DialogField(
              controller: codeCtrl,
              label: 'Join Code',
              autofocus: true,
              hint: 'e.g. ABC123',
            ),
          ],
          confirmLabel: 'Join',
          onConfirm: () {
            final code = codeCtrl.text.trim();
            if (code.isEmpty) return;
            Navigator.pop(ctx);
            final auth = ref.read(authProvider);
            ref.read(classroomProvider.notifier).joinClassroom(
                  joinCode: code,
                  studentId: auth.profile!.uid,
                );
          },
        );
      },
    );
  }
}

/// Classroom detail view — shows assignments.
class _ClassroomDetailView extends ConsumerWidget {
  final ThemeColors colors;
  final bool isTeacher;

  const _ClassroomDetailView({
    required this.colors,
    required this.isTeacher,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classState = ref.watch(classroomProvider);
    final classroom = classState.activeClassroom!;

    return Container(
      color: colors.sidebarBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back + title
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
            child: Row(
              children: [
                _HeaderButton(
                  icon: Icons.arrow_back,
                  tooltip: 'Back',
                  colors: colors,
                  onTap: () =>
                      ref.read(classroomProvider.notifier).deselectClassroom(),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    classroom.name,
                    style: TextStyle(
                      color: colors.foreground,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isTeacher)
                  _HeaderButton(
                    icon: Icons.add,
                    tooltip: 'New Assignment',
                    colors: colors,
                    onTap: () => _showCreateAssignmentDialog(context, ref),
                  ),
              ],
            ),
          ),

          // Join code (teacher sees it prominently)
          if (isTeacher)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    'Join code: ',
                    style: TextStyle(
                      color: colors.foreground.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                          ClipboardData(text: classroom.joinCode));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            classroom.joinCode,
                            style: TextStyle(
                              color: colors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'JetBrainsMono',
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.copy, size: 12, color: colors.primary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${classroom.studentCount} students',
                    style: TextStyle(
                      color: colors.foreground.withValues(alpha: 0.35),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),

          if (classroom.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                classroom.description,
                style: TextStyle(
                  color: colors.foreground.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          Divider(color: colors.border.withValues(alpha: 0.3), height: 12),

          // Messages
          if (classState.error != null)
            _MessageBar(
              message: classState.error!,
              isError: true,
              colors: colors,
              onDismiss: () =>
                  ref.read(classroomProvider.notifier).clearMessages(),
            ),
          if (classState.successMessage != null)
            _MessageBar(
              message: classState.successMessage!,
              isError: false,
              colors: colors,
              onDismiss: () =>
                  ref.read(classroomProvider.notifier).clearMessages(),
            ),

          // Assignments header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(
              'ASSIGNMENTS',
              style: TextStyle(
                color: colors.foreground.withValues(alpha: 0.4),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),

          // Loading
          if (classState.isLoading && classState.assignments.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.primary,
                  ),
                ),
              ),
            ),

          if (classState.assignments.isEmpty && !classState.isLoading)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                isTeacher
                    ? 'No assignments yet.\nClick + to share code.'
                    : 'No assignments yet.',
                style: TextStyle(
                  color: colors.foreground.withValues(alpha: 0.4),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),

          // Assignment list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 2),
              itemCount: classState.assignments.length,
              itemBuilder: (context, index) {
                final assignment = classState.assignments[index];
                return _AssignmentTile(
                  assignment: assignment,
                  isTeacher: isTeacher,
                  colors: colors,
                  onTap: () => ref
                      .read(classroomProvider.notifier)
                      .selectAssignment(assignment),
                );
              },
            ),
          ),

          // Bottom actions
          if (!isTeacher)
            Padding(
              padding: const EdgeInsets.all(8),
              child: _SmallButton(
                label: 'Leave Classroom',
                icon: Icons.exit_to_app,
                colors: colors,
                isDestructive: true,
                onTap: () {
                  final auth = ref.read(authProvider);
                  ref.read(classroomProvider.notifier).leaveClassroom(
                        classroom.id,
                        auth.profile!.uid,
                      );
                },
              ),
            ),

          if (isTeacher)
            Padding(
              padding: const EdgeInsets.all(8),
              child: _SmallButton(
                label: 'Delete Classroom',
                icon: Icons.delete_outline,
                colors: colors,
                isDestructive: true,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: colors.surface,
                      title: Text(
                        'Delete Classroom?',
                        style: TextStyle(
                          color: colors.foreground,
                          fontSize: 15,
                        ),
                      ),
                      content: Text(
                        'This will permanently delete "${classroom.name}" and all its assignments.',
                        style: TextStyle(
                          color: colors.foreground.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            'Cancel',
                            style: TextStyle(color: colors.foreground),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            ref
                                .read(classroomProvider.notifier)
                                .deleteClassroom(classroom.id);
                          },
                          child: Text(
                            'Delete',
                            style: TextStyle(color: colors.error),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _showCreateAssignmentDialog(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final classState = ref.read(classroomProvider);
    final classroom = classState.activeClassroom!;

    // Get current editor content as the assignment file
    final tabState = ref.read(tabProvider);
    final activeTab = tabState.activeTab;

    showDialog(
      context: context,
      builder: (ctx) {
        return _InputDialog(
          title: 'Share Code',
          colors: colors,
          fields: [
            _DialogField(
              controller: titleCtrl,
              label: 'Title',
              autofocus: true,
            ),
            _DialogField(
              controller: descCtrl,
              label: 'Description (optional)',
            ),
          ],
          extraContent: activeTab != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.attach_file,
                          size: 14,
                          color: colors.foreground.withValues(alpha: 0.5)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Attaching: ${activeTab.fileName}',
                          style: TextStyle(
                            color: colors.foreground.withValues(alpha: 0.6),
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )
              : null,
          confirmLabel: 'Share',
          onConfirm: () {
            final title = titleCtrl.text.trim();
            if (title.isEmpty) return;
            Navigator.pop(ctx);

            final files = <String, String>{};
            if (activeTab != null) {
              files[activeTab.fileName] = activeTab.content;
            }

            final auth = ref.read(authProvider);
            ref.read(classroomProvider.notifier).createAssignment(
                  classroomId: classroom.id,
                  title: title,
                  description: descCtrl.text.trim(),
                  teacherId: auth.profile!.uid,
                  files: files,
                  language: activeTab?.languageId ?? 'plaintext',
                );
          },
        );
      },
    );
  }
}

/// Assignment detail — shows files and submissions.
class _AssignmentDetailView extends ConsumerWidget {
  final ThemeColors colors;
  final bool isTeacher;

  const _AssignmentDetailView({
    required this.colors,
    required this.isTeacher,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classState = ref.watch(classroomProvider);
    final assignment = classState.activeAssignment!;
    final authState = ref.watch(authProvider);

    return Container(
      color: colors.sidebarBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back + title
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
            child: Row(
              children: [
                _HeaderButton(
                  icon: Icons.arrow_back,
                  tooltip: 'Back',
                  colors: colors,
                  onTap: () =>
                      ref.read(classroomProvider.notifier).deselectAssignment(),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    assignment.title,
                    style: TextStyle(
                      color: colors.foreground,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Open/Close toggle (teacher)
                if (isTeacher)
                  _HeaderButton(
                    icon: assignment.isOpen ? Icons.lock_open : Icons.lock,
                    tooltip: assignment.isOpen ? 'Close' : 'Reopen',
                    colors: colors,
                    onTap: () => ref
                        .read(classroomProvider.notifier)
                        .toggleAssignment(
                          assignment.classroomId,
                          assignment.id,
                          !assignment.isOpen,
                        ),
                  ),
              ],
            ),
          ),

          // Status badge
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: assignment.isOpen
                        ? colors.success.withValues(alpha: 0.15)
                        : colors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    assignment.isOpen ? 'Open' : 'Closed',
                    style: TextStyle(
                      color:
                          assignment.isOpen ? colors.success : colors.error,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  assignment.language,
                  style: TextStyle(
                    color: colors.foreground.withValues(alpha: 0.35),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          if (assignment.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                assignment.description,
                style: TextStyle(
                  color: colors.foreground.withValues(alpha: 0.6),
                  fontSize: 11,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          Divider(color: colors.border.withValues(alpha: 0.3), height: 12),

          // Shared files
          if (assignment.files.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                'FILES',
                style: TextStyle(
                  color: colors.foreground.withValues(alpha: 0.4),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            ...assignment.files.entries.map((entry) {
              return _FileTile(
                fileName: entry.key,
                colors: colors,
                onTap: () {
                  // Open the file content in a new tab
                  _openSharedFile(ref, entry.key, entry.value);
                },
              );
            }),
            Divider(color: colors.border.withValues(alpha: 0.3), height: 12),
          ],

          // Teacher: show submissions
          if (isTeacher) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                'SUBMISSIONS (${classState.submissions.length})',
                style: TextStyle(
                  color: colors.foreground.withValues(alpha: 0.4),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            if (classState.isLoading && classState.submissions.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.primary,
                    ),
                  ),
                ),
              ),
            if (classState.submissions.isEmpty && !classState.isLoading)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No submissions yet.',
                  style: TextStyle(
                    color: colors.foreground.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 2),
                itemCount: classState.submissions.length,
                itemBuilder: (context, index) {
                  final sub = classState.submissions[index];
                  return _SubmissionTile(
                    submission: sub,
                    colors: colors,
                    onTap: () {
                      // Open first file from submission
                      if (sub.files.isNotEmpty) {
                        final entry = sub.files.entries.first;
                        _openSharedFile(
                          ref,
                          '${sub.studentName}_${entry.key}',
                          entry.value,
                        );
                      }
                    },
                    onGrade: () => _showGradeDialog(context, ref, sub),
                  );
                },
              ),
            ),
          ],

          // Student: show submit button
          if (!isTeacher && assignment.isOpen) ...[
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Submit your current open file:',
                    style: TextStyle(
                      color: colors.foreground.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SmallButton(
                    label: 'Submit Current File',
                    icon: Icons.upload,
                    colors: colors,
                    onTap: () {
                      final tab = ref.read(tabProvider).activeTab;
                      if (tab == null) return;
                      ref.read(classroomProvider.notifier).submitWork(
                            classroomId: assignment.classroomId,
                            assignmentId: assignment.id,
                            studentId: authState.profile!.uid,
                            studentName: authState.profile!.displayName,
                            files: {tab.fileName: tab.content},
                          );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openSharedFile(WidgetRef ref, String fileName, String content) {
    // Write to a temp file and open it
    final tmpDir = Directory.systemTemp;
    final tmpFile = File('${tmpDir.path}/spark_shared_$fileName');
    tmpFile.writeAsStringSync(content);
    ref.read(tabProvider.notifier).openFile(tmpFile.path, fileName);
  }

  void _showGradeDialog(
    BuildContext context,
    WidgetRef ref,
    Submission sub,
  ) {
    final gradeCtrl = TextEditingController(
      text: sub.grade?.toString() ?? '',
    );
    final feedbackCtrl = TextEditingController(
      text: sub.feedback ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return _InputDialog(
          title: 'Grade: ${sub.studentName}',
          colors: colors,
          fields: [
            _DialogField(
              controller: gradeCtrl,
              label: 'Grade (0-100)',
              autofocus: true,
              isNumber: true,
            ),
            _DialogField(
              controller: feedbackCtrl,
              label: 'Feedback (optional)',
            ),
          ],
          confirmLabel: 'Save Grade',
          onConfirm: () {
            final grade = int.tryParse(gradeCtrl.text.trim());
            if (grade == null) return;
            Navigator.pop(ctx);
            final classState = ref.read(classroomProvider);
            ref.read(classroomProvider.notifier).gradeSubmission(
                  classroomId: classState.activeClassroom!.id,
                  assignmentId: classState.activeAssignment!.id,
                  submissionId: sub.id,
                  grade: grade.clamp(0, 100),
                  feedback: feedbackCtrl.text.trim().isEmpty
                      ? null
                      : feedbackCtrl.text.trim(),
                );
          },
        );
      },
    );
  }
}

// ==================== Reusable Widgets ====================

class _SectionHeader extends StatelessWidget {
  final String title;
  final ThemeColors colors;

  const _SectionHeader({required this.title, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: colors.foreground.withValues(alpha: 0.5),
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _HeaderButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final ThemeColors colors;
  final VoidCallback onTap;

  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.colors,
    required this.onTap,
  });

  @override
  State<_HeaderButton> createState() => _HeaderButtonState();
}

class _HeaderButtonState extends State<_HeaderButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _isHovered
                  ? widget.colors.foreground.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              widget.icon,
              size: 16,
              color: widget.colors.foreground.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClassroomTile extends StatefulWidget {
  final Classroom classroom;
  final bool isTeacher;
  final ThemeColors colors;
  final VoidCallback onTap;

  const _ClassroomTile({
    required this.classroom,
    required this.isTeacher,
    required this.colors,
    required this.onTap,
  });

  @override
  State<_ClassroomTile> createState() => _ClassroomTileState();
}

class _ClassroomTileState extends State<_ClassroomTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: _isHovered
              ? widget.colors.foreground.withValues(alpha: 0.04)
              : Colors.transparent,
          child: Row(
            children: [
              Icon(
                widget.isTeacher ? Icons.school : Icons.class_,
                size: 18,
                color: widget.colors.primary.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.classroom.name,
                      style: TextStyle(
                        color: widget.colors.foreground,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.isTeacher
                          ? '${widget.classroom.studentCount} students'
                          : widget.classroom.teacherName,
                      style: TextStyle(
                        color: widget.colors.foreground.withValues(alpha: 0.4),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: widget.colors.foreground.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssignmentTile extends StatefulWidget {
  final Assignment assignment;
  final bool isTeacher;
  final ThemeColors colors;
  final VoidCallback onTap;

  const _AssignmentTile({
    required this.assignment,
    required this.isTeacher,
    required this.colors,
    required this.onTap,
  });

  @override
  State<_AssignmentTile> createState() => _AssignmentTileState();
}

class _AssignmentTileState extends State<_AssignmentTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: _isHovered
              ? widget.colors.foreground.withValues(alpha: 0.04)
              : Colors.transparent,
          child: Row(
            children: [
              Icon(
                widget.assignment.isOpen
                    ? Icons.assignment_outlined
                    : Icons.assignment_late_outlined,
                size: 16,
                color: widget.assignment.isOpen
                    ? widget.colors.success
                    : widget.colors.foreground.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.assignment.title,
                      style: TextStyle(
                        color: widget.colors.foreground,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${widget.assignment.files.length} file(s)',
                      style: TextStyle(
                        color: widget.colors.foreground.withValues(alpha: 0.35),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: widget.colors.foreground.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileTile extends StatefulWidget {
  final String fileName;
  final ThemeColors colors;
  final VoidCallback onTap;

  const _FileTile({
    required this.fileName,
    required this.colors,
    required this.onTap,
  });

  @override
  State<_FileTile> createState() => _FileTileState();
}

class _FileTileState extends State<_FileTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          color: _isHovered
              ? widget.colors.foreground.withValues(alpha: 0.04)
              : Colors.transparent,
          child: Row(
            children: [
              Icon(
                Icons.description_outlined,
                size: 14,
                color: widget.colors.primary.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.fileName,
                  style: TextStyle(
                    color: widget.colors.foreground.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontFamily: 'JetBrainsMono',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.open_in_new,
                size: 12,
                color: widget.colors.foreground.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmissionTile extends StatefulWidget {
  final Submission submission;
  final ThemeColors colors;
  final VoidCallback onTap;
  final VoidCallback onGrade;

  const _SubmissionTile({
    required this.submission,
    required this.colors,
    required this.onTap,
    required this.onGrade,
  });

  @override
  State<_SubmissionTile> createState() => _SubmissionTileState();
}

class _SubmissionTileState extends State<_SubmissionTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final sub = widget.submission;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: _isHovered
              ? widget.colors.foreground.withValues(alpha: 0.04)
              : Colors.transparent,
          child: Row(
            children: [
              Icon(
                sub.isGraded
                    ? Icons.check_circle_outline
                    : Icons.pending_outlined,
                size: 14,
                color: sub.isGraded
                    ? widget.colors.success
                    : widget.colors.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sub.studentName,
                      style: TextStyle(
                        color: widget.colors.foreground,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      sub.isGraded ? 'Grade: ${sub.grade}/100' : 'Not graded',
                      style: TextStyle(
                        color: widget.colors.foreground.withValues(alpha: 0.4),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: widget.onGrade,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    sub.isGraded ? 'Edit' : 'Grade',
                    style: TextStyle(
                      color: widget.colors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBar extends StatelessWidget {
  final String message;
  final bool isError;
  final ThemeColors colors;
  final VoidCallback onDismiss;

  const _MessageBar({
    required this.message,
    required this.isError,
    required this.colors,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final color = isError ? colors.error : colors.success;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 11),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(Icons.close, size: 14, color: color),
          ),
        ],
      ),
    );
  }
}

class _SmallButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final ThemeColors colors;
  final bool isDestructive;
  final VoidCallback onTap;

  const _SmallButton({
    required this.label,
    required this.icon,
    required this.colors,
    this.isDestructive = false,
    required this.onTap,
  });

  @override
  State<_SmallButton> createState() => _SmallButtonState();
}

class _SmallButtonState extends State<_SmallButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final color =
        widget.isDestructive ? widget.colors.error : widget.colors.primary;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 30,
          decoration: BoxDecoration(
            color: _isHovered
                ? color.withValues(alpha: 0.1)
                : color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputDialog extends StatelessWidget {
  final String title;
  final ThemeColors colors;
  final List<_DialogField> fields;
  final Widget? extraContent;
  final String confirmLabel;
  final VoidCallback onConfirm;

  const _InputDialog({
    required this.title,
    required this.colors,
    required this.fields,
    this.extraContent,
    required this.confirmLabel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colors.border),
      ),
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                color: colors.foreground,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ...fields.map((field) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: field.controller,
                  autofocus: field.autofocus,
                  keyboardType: field.isNumber
                      ? TextInputType.number
                      : TextInputType.text,
                  style: TextStyle(
                    color: colors.foreground,
                    fontSize: 13,
                    fontFamily: 'JetBrainsMono',
                  ),
                  decoration: InputDecoration(
                    labelText: field.label,
                    hintText: field.hint,
                    labelStyle: TextStyle(
                      color: colors.foreground.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                    hintStyle: TextStyle(
                      color: colors.foreground.withValues(alpha: 0.3),
                      fontSize: 12,
                    ),
                    filled: true,
                    fillColor: colors.inputBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide:
                          BorderSide(color: colors.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                ),
              );
            }),
            ?extraContent,
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: colors.foreground.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onConfirm,
                  style: TextButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.buttonForeground,
                  ),
                  child: Text(confirmLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogField {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool autofocus;
  final bool isNumber;

  const _DialogField({
    required this.controller,
    required this.label,
    this.hint,
    this.autofocus = false,
    this.isNumber = false,
  });
}
