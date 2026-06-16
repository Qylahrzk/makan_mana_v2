import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/app_colors.dart';
import '../../logic/cubits/auth_cubit.dart';
import '../widgets/premium_background.dart';

/// ForgotPasswordScreen
///
/// Sends a password reset email via Supabase.
/// Place in: lib/presentation/screens/forgot_password_screen.dart

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthCubit>().sendPasswordReset(_emailCtrl.text.trim());
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
        if (state is AuthPasswordResetSent) {
          _showSuccessSheet(context);
        } else if (state is AuthError) {
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    // ── Back button ──────────────────────────────────────
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surface.withValues(alpha: 0.6),
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
                    ),

                    const SizedBox(height: 40),

                    // ── Icon ─────────────────────────────────────────────
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.lock_reset_rounded,
                        size: 34,
                        color: AppColors.primary,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Header ───────────────────────────────────────────
                    Text(
                      'Forgot\nPassword? 🔑',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.onSurface,
                        letterSpacing: -0.8,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "No worries! Enter your email and we'll send you a reset link.",
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        height: 1.6,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // ── Email field ──────────────────────────────────────
                    Text(
                      'Email Address',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!v.contains('@') || !v.contains('.')) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'you@example.com',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[500],
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.email_outlined,
                          size: 20,
                          color: isDark ? Colors.grey[500] : Colors.grey[500],
                        ),
                        filled: true,
                        fillColor: isDark
                            ? AppColors.darkSurface
                            : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.08),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.08),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.error,
                            width: 1.5,
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.error,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Send Reset Link button ────────────────────────────
                    BlocBuilder<AuthCubit, AuthState>(
                      builder: (context, state) {
                        final loading = state is AuthLoading;
                        return SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: loading ? null : () => _submit(context),
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
                                    'Send Reset Link',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),

                    const Spacer(),

                    // ── Back to login ─────────────────────────────────────
                    Center(
                      child: TextButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          size: 16,
                          color: AppColors.secondary,
                        ),
                        label: Text(
                          'Back to Sign In',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondary,
                          ),
                        ),
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

  // ── Success bottom sheet ───────────────────────────────────────────────
  void _showSuccessSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.fromLTRB(
          28,
          28,
          28,
          MediaQuery.of(context).padding.bottom + 28,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 28),

            // Success icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF4E7F64).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mark_email_read_rounded,
                size: 36,
                color: Color(0xFF4E7F64),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Check Your Email',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We sent a password reset link to\n${_emailCtrl.text.trim()}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),

            // Done button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // close sheet
                  Navigator.pop(context); // back to login
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Back to Sign In',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
