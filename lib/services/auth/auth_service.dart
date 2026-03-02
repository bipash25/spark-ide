import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:spark_ide/models/user_profile.dart';
import 'package:spark_ide/core/config/firebase_config.dart';

/// Authentication service wrapping Firebase Auth + Firestore profile storage.
class AuthService {
  // Lazy — only accessed when Firebase is actually configured & initialized.
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  GoogleSignIn get _googleSignIn => GoogleSignIn();

  /// Whether Firebase is configured with real credentials.
  bool get isConfigured => FirebaseConfig.isConfigured;

  /// Current Firebase auth user (null if not signed in).
  User? get currentUser => isConfigured ? _auth.currentUser : null;

  /// Stream of auth state changes.
  Stream<User?> get authStateChanges =>
      isConfigured ? _auth.authStateChanges() : const Stream.empty();

  // ==================== Email/Password ====================

  /// Register with email and password.
  Future<UserProfile> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.updateDisplayName(displayName);

    final profile = UserProfile(
      uid: credential.user!.uid,
      email: email,
      displayName: displayName,
      role: UserRole.student,
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );

    await _saveProfile(profile);
    return profile;
  }

  /// Sign in with email and password.
  Future<UserProfile> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return await _getOrCreateProfile(credential.user!);
  }

  // ==================== Google Sign-In ====================

  /// Sign in with Google.
  Future<UserProfile> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw AuthServiceException(
        code: 'cancelled',
        message: 'Google sign-in was cancelled.',
      );
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    return await _getOrCreateProfile(userCredential.user!);
  }

  // ==================== GitHub Sign-In ====================

  /// Sign in with GitHub via OAuth.
  Future<UserProfile> signInWithGitHub() async {
    final githubProvider = GithubAuthProvider();
    githubProvider.addScope('read:user');
    githubProvider.addScope('user:email');

    final userCredential = await _auth.signInWithProvider(githubProvider);
    return await _getOrCreateProfile(userCredential.user!);
  }

  // ==================== Sign Out ====================

  /// Sign out from all providers.
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ==================== Password Reset ====================

  /// Send password reset email.
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ==================== Profile Management ====================

  /// Get user profile from Firestore.
  Future<UserProfile?> getProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserProfile.fromMap(doc.data()!);
  }

  /// Update user profile in Firestore.
  Future<void> updateProfile(UserProfile profile) async {
    await _saveProfile(profile);
  }

  /// Update user role (student <-> teacher).
  Future<UserProfile> updateRole(String uid, UserRole role) async {
    final profile = await getProfile(uid);
    if (profile == null) {
      throw Exception('User profile not found');
    }
    final updated = profile.copyWith(role: role);
    await _saveProfile(updated);
    return updated;
  }

  // ==================== Internal Helpers ====================

  Future<UserProfile> _getOrCreateProfile(User user) async {
    var profile = await getProfile(user.uid);
    if (profile == null) {
      profile = UserProfile(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? user.email?.split('@').first ?? '',
        photoUrl: user.photoURL,
        role: UserRole.student,
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
      );
      await _saveProfile(profile);
    } else {
      profile = profile.copyWith(lastLoginAt: DateTime.now());
      await _saveProfile(profile);
    }
    return profile;
  }

  Future<void> _saveProfile(UserProfile profile) async {
    await _firestore
        .collection('users')
        .doc(profile.uid)
        .set(profile.toMap(), SetOptions(merge: true));
  }
}

/// Custom exception for cleaner error handling.
class AuthServiceException implements Exception {
  final String code;
  final String message;

  const AuthServiceException({
    required this.code,
    required this.message,
  });

  @override
  String toString() => message;
}
