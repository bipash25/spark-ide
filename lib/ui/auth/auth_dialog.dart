import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_ide/core/theme/theme_provider.dart';
import 'package:spark_ide/core/theme/spark_theme.dart';
import 'package:spark_ide/core/config/firebase_config.dart';
import 'package:spark_ide/providers/auth_provider.dart';
import 'package:spark_ide/models/user_profile.dart';

/// Auth dialog — Login / Register / Profile
class AuthDialog extends ConsumerStatefulWidget {
  const AuthDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => const AuthDialog(),
    );
  }

  @override
  ConsumerState<AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends ConsumerState<AuthDialog> {
  bool _isRegister = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailFocus = FocusNode();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _emailFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeColorsProvider);
    final authState = ref.watch(authProvider);

    // If signed in, show profile view
    if (authState.isSignedIn) {
      return _ProfileDialog(colors: colors);
    }

    if (!FirebaseConfig.isConfigured) {
      return _NotConfiguredDialog(colors: colors);
    }

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.border),
      ),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.bolt, color: colors.primary, size: 24),
                const SizedBox(width: 8),
                Text(
                  _isRegister ? 'Create Account' : 'Sign In',
                  style: TextStyle(
                    color: colors.foreground,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: colors.foreground, size: 18),
                  splashRadius: 16,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Error message
            if (authState.error != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: colors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: colors.error, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        authState.error!,
                        style: TextStyle(color: colors.error, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Name field (register only)
            if (_isRegister) ...[
              _AuthField(
                controller: _nameController,
                label: 'Display Name',
                icon: Icons.person_outline,
                colors: colors,
              ),
              const SizedBox(height: 12),
            ],

            // Email field
            _AuthField(
              controller: _emailController,
              focusNode: _emailFocus,
              label: 'Email',
              icon: Icons.email_outlined,
              colors: colors,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),

            // Password field
            _AuthField(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock_outline,
              colors: colors,
              obscure: _obscurePassword,
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                  color: colors.foreground.withValues(alpha: 0.5),
                ),
                splashRadius: 14,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 18),

            // Submit button
            _PrimaryButton(
              label: _isRegister ? 'Create Account' : 'Sign In',
              isLoading: authState.isLoading,
              colors: colors,
              onTap: _submit,
            ),
            const SizedBox(height: 12),

            // Divider
            Row(
              children: [
                Expanded(child: Divider(color: colors.border)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or continue with',
                    style: TextStyle(
                      color: colors.foreground.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: colors.border)),
              ],
            ),
            const SizedBox(height: 12),

            // Social sign-in buttons
            Row(
              children: [
                Expanded(
                  child: _SocialButton(
                    icon: Icons.g_mobiledata,
                    label: 'Google',
                    colors: colors,
                    isLoading: authState.isLoading,
                    onTap: () =>
                        ref.read(authProvider.notifier).signInWithGoogle(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SocialButton(
                    icon: Icons.code,
                    label: 'GitHub',
                    colors: colors,
                    isLoading: authState.isLoading,
                    onTap: () =>
                        ref.read(authProvider.notifier).signInWithGitHub(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Toggle login/register
            Center(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isRegister = !_isRegister;
                    ref.read(authProvider.notifier).clearError();
                  });
                },
                child: Text.rich(
                  TextSpan(
                    text: _isRegister
                        ? 'Already have an account? '
                        : "Don't have an account? ",
                    style: TextStyle(
                      color: colors.foreground.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                    children: [
                      TextSpan(
                        text: _isRegister ? 'Sign In' : 'Register',
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      return;
    }

    if (_isRegister) {
      final name = _nameController.text.trim();
      if (name.isEmpty) return;
      ref.read(authProvider.notifier).registerWithEmail(
            email: email,
            password: password,
            displayName: name,
          );
    } else {
      ref.read(authProvider.notifier).signInWithEmail(
            email: email,
            password: password,
          );
    }
  }
}

/// Profile view when user is signed in.
class _ProfileDialog extends ConsumerWidget {
  final ThemeColors colors;

  const _ProfileDialog({required this.colors});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final profile = authState.profile!;

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.border),
      ),
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Text(
                  'Profile',
                  style: TextStyle(
                    color: colors.foreground,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: colors.foreground, size: 18),
                  splashRadius: 16,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Avatar
            CircleAvatar(
              radius: 32,
              backgroundColor: colors.primary.withValues(alpha: 0.2),
              backgroundImage: profile.photoUrl != null
                  ? NetworkImage(profile.photoUrl!)
                  : null,
              child: profile.photoUrl == null
                  ? Text(
                      profile.displayName.isNotEmpty
                          ? profile.displayName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 12),

            // Name
            Text(
              profile.displayName,
              style: TextStyle(
                color: colors.foreground,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),

            // Email
            Text(
              profile.email,
              style: TextStyle(
                color: colors.foreground.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),

            // Role badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: profile.isTeacher
                    ? colors.warning.withValues(alpha: 0.15)
                    : colors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                profile.isTeacher ? 'Teacher' : 'Student',
                style: TextStyle(
                  color: profile.isTeacher ? colors.warning : colors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Switch role
            _ProfileAction(
              icon: Icons.swap_horiz,
              label: profile.isTeacher
                  ? 'Switch to Student'
                  : 'Switch to Teacher',
              colors: colors,
              onTap: () {
                ref.read(authProvider.notifier).updateRole(
                      profile.isTeacher ? UserRole.student : UserRole.teacher,
                    );
              },
            ),
            const SizedBox(height: 8),

            // Sign out
            _ProfileAction(
              icon: Icons.logout,
              label: 'Sign Out',
              colors: colors,
              isDestructive: true,
              onTap: () {
                Navigator.pop(context);
                ref.read(authProvider.notifier).signOut();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when Firebase is not configured.
class _NotConfiguredDialog extends StatelessWidget {
  final ThemeColors colors;

  const _NotConfiguredDialog({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.border),
      ),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_off, color: colors.warning, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Firebase Not Configured',
                  style: TextStyle(
                    color: colors.foreground,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: colors.foreground, size: 18),
                  splashRadius: 16,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'To use authentication and classroom features, you need to set up Firebase:\n\n'
              '1. Create a project at console.firebase.google.com\n'
              '2. Enable Email/Password, Google, and GitHub authentication\n'
              '3. Create a Firestore database\n'
              '4. Update lib/core/config/firebase_config.dart with your config values\n'
              '5. Set isConfigured = true',
              style: TextStyle(
                color: colors.foreground.withValues(alpha: 0.7),
                fontSize: 12,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Got it',
                  style: TextStyle(color: colors.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== Shared Widgets ====================

class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final IconData icon;
  final ThemeColors colors;
  final bool obscure;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;

  const _AuthField({
    required this.controller,
    this.focusNode,
    required this.label,
    required this.icon,
    required this.colors,
    this.obscure = false,
    this.suffixIcon,
    this.keyboardType,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      style: TextStyle(
        color: colors.foreground,
        fontSize: 13,
        fontFamily: 'JetBrainsMono',
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: colors.foreground.withValues(alpha: 0.5),
          fontSize: 12,
        ),
        prefixIcon: Icon(icon, size: 18, color: colors.foreground.withValues(alpha: 0.5)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: colors.inputBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }
}

class _PrimaryButton extends StatefulWidget {
  final String label;
  final bool isLoading;
  final ThemeColors colors;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.isLoading,
    required this.colors,
    required this.onTap,
  });

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.isLoading ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 42,
          decoration: BoxDecoration(
            color: _isHovered
                ? widget.colors.primary.withValues(alpha: 0.85)
                : widget.colors.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: widget.colors.buttonForeground,
                    ),
                  )
                : Text(
                    widget.label,
                    style: TextStyle(
                      color: widget.colors.buttonForeground,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final ThemeColors colors;
  final bool isLoading;
  final VoidCallback onTap;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.colors,
    required this.isLoading,
    required this.onTap,
  });

  @override
  State<_SocialButton> createState() => _SocialButtonState();
}

class _SocialButtonState extends State<_SocialButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.isLoading ? null : widget.onTap,
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: _isHovered
                ? widget.colors.foreground.withValues(alpha: 0.08)
                : widget.colors.inputBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: widget.colors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: widget.colors.foreground.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.colors.foreground.withValues(alpha: 0.8),
                  fontSize: 12,
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

class _ProfileAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final ThemeColors colors;
  final bool isDestructive;
  final VoidCallback onTap;

  const _ProfileAction({
    required this.icon,
    required this.label,
    required this.colors,
    this.isDestructive = false,
    required this.onTap,
  });

  @override
  State<_ProfileAction> createState() => _ProfileActionState();
}

class _ProfileActionState extends State<_ProfileAction> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isDestructive
        ? widget.colors.error
        : widget.colors.foreground;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _isHovered
                ? color.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: color.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: TextStyle(
                  color: color.withValues(alpha: 0.8),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
