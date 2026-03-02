import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_ide/models/user_profile.dart';
import 'package:spark_ide/services/auth/auth_service.dart' show AuthService, AuthServiceException;
import 'package:spark_ide/core/config/firebase_config.dart';

/// Provider for the auth service singleton.
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Provider for the current auth state.
final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final service = ref.watch(authServiceProvider);
  return AuthNotifier(service);
});

/// Auth state.
class AuthState {
  final UserProfile? profile;
  final bool isLoading;
  final String? error;
  final bool isInitialized;

  const AuthState({
    this.profile,
    this.isLoading = false,
    this.error,
    this.isInitialized = false,
  });

  bool get isSignedIn => profile != null;
  bool get isTeacher => profile?.isTeacher ?? false;
  bool get isStudent => profile?.isStudent ?? true;

  AuthState copyWith({
    UserProfile? profile,
    bool? isLoading,
    String? error,
    bool? isInitialized,
    bool clearProfile = false,
    bool clearError = false,
  }) {
    return AuthState(
      profile: clearProfile ? null : (profile ?? this.profile),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

/// Auth state notifier.
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _service;
  StreamSubscription<User?>? _authSub;

  AuthNotifier(this._service) : super(const AuthState()) {
    _init();
  }

  void _init() {
    if (!FirebaseConfig.isConfigured) {
      state = state.copyWith(isInitialized: true);
      return;
    }

    _authSub = _service.authStateChanges.listen((user) async {
      if (user != null) {
        try {
          final profile = await _service.getProfile(user.uid);
          if (profile != null) {
            state = state.copyWith(
              profile: profile,
              isInitialized: true,
              clearError: true,
            );
          } else {
            // Profile doesn't exist yet (edge case)
            state = state.copyWith(isInitialized: true, clearProfile: true);
          }
        } catch (e) {
          state = state.copyWith(
            isInitialized: true,
            error: e.toString(),
            clearProfile: true,
          );
        }
      } else {
        state = state.copyWith(
          isInitialized: true,
          clearProfile: true,
          clearError: true,
        );
      }
    });
  }

  /// Register with email/password.
  Future<void> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final profile = await _service.registerWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
      state = state.copyWith(profile: profile, isLoading: false);
    } on AuthServiceException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendlyError(e));
    }
  }

  /// Sign in with email/password.
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final profile = await _service.signInWithEmail(
        email: email,
        password: password,
      );
      state = state.copyWith(profile: profile, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendlyError(e));
    }
  }

  /// Sign in with Google.
  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final profile = await _service.signInWithGoogle();
      state = state.copyWith(profile: profile, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendlyError(e));
    }
  }

  /// Sign in with GitHub.
  Future<void> signInWithGitHub() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final profile = await _service.signInWithGitHub();
      state = state.copyWith(profile: profile, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendlyError(e));
    }
  }

  /// Sign out.
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _service.signOut();
      state = state.copyWith(
        isLoading: false,
        clearProfile: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendlyError(e));
    }
  }

  /// Send password reset email.
  Future<void> sendPasswordReset(String email) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _service.sendPasswordResetEmail(email);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendlyError(e));
    }
  }

  /// Update user role.
  Future<void> updateRole(UserRole role) async {
    if (state.profile == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updated = await _service.updateRole(state.profile!.uid, role);
      state = state.copyWith(profile: updated, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendlyError(e));
    }
  }

  /// Update display name.
  Future<void> updateDisplayName(String name) async {
    if (state.profile == null) return;
    try {
      final updated = state.profile!.copyWith(displayName: name);
      await _service.updateProfile(updated);
      state = state.copyWith(profile: updated);
    } catch (e) {
      state = state.copyWith(error: _friendlyError(e));
    }
  }

  /// Clear error.
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('user-not-found')) return 'No account found with this email.';
    if (msg.contains('wrong-password')) return 'Incorrect password.';
    if (msg.contains('email-already-in-use')) return 'Email is already registered.';
    if (msg.contains('weak-password')) return 'Password is too weak.';
    if (msg.contains('invalid-email')) return 'Invalid email address.';
    if (msg.contains('network-request-failed')) return 'Network error. Check your connection.';
    if (msg.contains('cancelled')) return 'Sign-in was cancelled.';
    if (msg.contains('too-many-requests')) return 'Too many attempts. Try again later.';
    return msg.length > 100 ? '${msg.substring(0, 100)}...' : msg;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
