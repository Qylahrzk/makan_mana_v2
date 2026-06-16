import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/app_colors.dart';
import '../../logic/cubits/auth_cubit.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import 'main_nav.dart';
import '../widgets/premium_background.dart';

/// LoginScreen
///
/// Place in: lib/presentation/screens/login_screen.dart

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _submitAttempted = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitAttempted = true);
    context.read<AuthCubit>().login(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
  }

  void _goToMainNav() {
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const MainNavScreen(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
    );

    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          _goToMainNav();
        } else if (state is AuthError) {
          setState(() => _submitAttempted = false);
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.all(16),
              ),
            );
        }
      },
      child: Scaffold(
        body: PremiumGradientBackground(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    // ── Back ─────────────────────────────────────────────
                    _BackButton(),

                    const SizedBox(height: 32),

                    // ── Heading ──────────────────────────────────────────
                    Text(
                      'Welcome\nBack 👋',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.onSurface,
                        letterSpacing: -0.8,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to your Makan Mana account',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 36),

                    // ── Email ────────────────────────────────────────────
                    const _FieldLabel(label: 'Email Address'),
                    const SizedBox(height: 8),
                    _InputField(
                      controller: _emailCtrl,
                      hint: 'you@example.com',
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.email_outlined,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!v.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // ── Password ─────────────────────────────────────────
                    const _FieldLabel(label: 'Password'),
                    const SizedBox(height: 8),
                    _InputField(
                      controller: _passwordCtrl,
                      hint: '••••••••',
                      obscureText: _obscurePassword,
                      prefixIcon: Icons.lock_outline_rounded,
                      suffixIcon: GestureDetector(
                        onTap: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        child: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.grey[400],
                          size: 20,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (v.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),

                    // ── Forgot password ──────────────────────────────────
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordScreen(),
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 8,
                          ),
                        ),
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ── Sign In button ───────────────────────────────────
                    BlocBuilder<AuthCubit, AuthState>(
                      buildWhen: (prev, curr) =>
                          curr is AuthLoading ||
                          curr is AuthError ||
                          curr is AuthAuthenticated ||
                          prev is AuthLoading,
                      builder: (context, state) {
                        final loading =
                            state is AuthLoading && _submitAttempted;
                        return SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: loading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: AppColors.primary
                                  .withValues(alpha: 0.6),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // ── Divider ──────────────────────────────────────────
                    _OrDivider(),

                    const SizedBox(height: 20),

                    // ── Google button ────────────────────────────────────
                    _GoogleButton(
                      onTap: () => context.read<AuthCubit>().signInWithGoogle(),
                    ),

                    const SizedBox(height: 36),

                    // ── Sign up link ─────────────────────────────────────
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Don't have an account?",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SignupScreen(),
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                            ),
                            child: Text(
                              'Sign Up',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shared sub-widgets ───────────────────────────────────────────────────────

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey[300])),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'or continue with',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey[300])),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final IconData prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: isDark ? Colors.grey[500] : Colors.grey[500],
          fontSize: 14,
        ),
        prefixIcon: Icon(
          prefixIcon,
          size: 20,
          color: isDark ? Colors.grey[500] : Colors.grey[500],
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark ? AppColors.darkSurface : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GoogleButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'G',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF4285F4),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Continue with Google',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
