import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/app_colors.dart';
import '../../logic/cubits/auth_cubit.dart';
import 'login_screen.dart';
import 'main_nav.dart';
import '../widgets/premium_background.dart';

/// ENHANCED SignupScreen v2
/// - Full white opaque input fields
/// - Strong glassmorphism with backdrop blur effect appearance
/// - Real-time password validation indicators
/// - Better visual hierarchy
///
/// Place in: lib/presentation/screens/signup_screen.dart

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreedToTerms = false;
  bool _submitAttempted = false;
  late AnimationController _fadeController;

  late FocusNode _nameFocus;
  late FocusNode _emailFocus;
  late FocusNode _passwordFocus;
  late FocusNode _confirmFocus;

  bool _passwordMeetsLength = false;
  bool _passwordsMatch = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _nameFocus = FocusNode();
    _emailFocus = FocusNode();
    _passwordFocus = FocusNode();
    _confirmFocus = FocusNode();

    _passwordCtrl.addListener(_onPasswordChanged);
    _confirmCtrl.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _fadeController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  void _onPasswordChanged() {
    setState(() {
      _passwordMeetsLength = _passwordCtrl.text.length >= 8;
      _passwordsMatch =
          _passwordCtrl.text == _confirmCtrl.text &&
          _passwordCtrl.text.isNotEmpty;
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Please agree to the Terms & Privacy Policy'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      return;
    }
    setState(() => _submitAttempted = true);
    context.read<AuthCubit>().signUp(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      fullName: _nameCtrl.text.trim(),
    );
  }

  void _goToMainNav() {
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const MainNavScreen(),
        transitionDuration: const Duration(milliseconds: 500),
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
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.all(16),
              ),
            );
        }
      },
      child: Scaffold(
        body: PremiumGradientBackground(
          style: 'soft',
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _fadeController,
                  curve: Curves.easeOut,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),

                      _BackButton(onTap: () => Navigator.pop(context)),

                      const SizedBox(height: 48),

                      _ScreenHeader(
                        title: 'Create\nAccount',
                        subtitle: 'Join Makan Mana and discover great food',
                        isDark: isDark,
                      ),

                      const SizedBox(height: 44),

                      // Full Name field
                      _FormFieldGroup(
                        label: 'Full Name',
                        child: _EnhancedInputField(
                          controller: _nameCtrl,
                          focusNode: _nameFocus,
                          hint: 'Your full name',
                          prefixIcon: Icons.person_outline_rounded,
                          keyboardType: TextInputType.name,
                          isDark: isDark,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter your full name';
                            }
                            if (v.trim().length < 2) {
                              return 'Name must be at least 2 characters';
                            }
                            return null;
                          },
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Email field
                      _FormFieldGroup(
                        label: 'Email Address',
                        child: _EnhancedInputField(
                          controller: _emailCtrl,
                          focusNode: _emailFocus,
                          hint: 'you@example.com',
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: Icons.email_outlined,
                          isDark: isDark,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!v.contains('@') || !v.contains('.')) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Password field with indicator
                      _PasswordFieldWithIndicator(
                        label: 'Password',
                        controller: _passwordCtrl,
                        focusNode: _passwordFocus,
                        obscure: _obscurePassword,
                        onToggle: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        meetsLength: _passwordMeetsLength,
                        isDark: isDark,
                      ),

                      const SizedBox(height: 28),

                      // Confirm Password field
                      _FormFieldGroup(
                        label: 'Confirm Password',
                        child: _EnhancedInputField(
                          controller: _confirmCtrl,
                          focusNode: _confirmFocus,
                          hint: 'Re-enter your password',
                          obscureText: _obscureConfirm,
                          prefixIcon: Icons.lock_outline_rounded,
                          isDark: isDark,
                          hasError:
                              _confirmCtrl.text.isNotEmpty && !_passwordsMatch,
                          suffixIcon: _PasswordVisibilityToggle(
                            obscure: _obscureConfirm,
                            onToggle: () => setState(
                              () => _obscureConfirm = !_obscureConfirm,
                            ),
                            isDark: isDark,
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (v != _passwordCtrl.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                      ),

                      // Password match indicator
                      if (_confirmCtrl.text.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _PasswordMatchIndicator(
                          match: _passwordsMatch,
                          isDark: isDark,
                        ),
                      ],

                      const SizedBox(height: 32),

                      // Terms checkbox
                      _TermsCheckbox(
                        agreed: _agreedToTerms,
                        onChanged: (value) =>
                            setState(() => _agreedToTerms = value ?? false),
                        isDark: isDark,
                      ),

                      const SizedBox(height: 36),

                      // Create Account button
                      _CreateAccountButton(isDark: isDark),

                      const SizedBox(height: 32),

                      // Sign in link
                      _SignInLink(isDark: isDark),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
      ),
    );
  }
}

class _ScreenHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isDark;

  const _ScreenHeader({
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
            letterSpacing: -0.8,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 50,
          height: 5,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white70 : const Color(0xFF64748B),
            height: 1.6,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _FormFieldGroup extends StatelessWidget {
  final String label;
  final Widget child;

  const _FormFieldGroup({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _EnhancedInputField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final IconData prefixIcon;
  final Widget? suffixIcon;
  final bool isDark;
  final bool hasError;
  final String? Function(String?)? validator;

  const _EnhancedInputField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.prefixIcon,
    required this.isDark,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
    this.hasError = false,
    this.validator,
  });

  @override
  State<_EnhancedInputField> createState() => _EnhancedInputFieldState();
}

class _EnhancedInputFieldState extends State<_EnhancedInputField> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode;
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.hasError
        ? AppColors.error
        : (_isFocused
              ? AppColors.primary
              : Colors.white.withValues(alpha: 0.3));

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isFocused ? 0.12 : 0.08),
            blurRadius: _isFocused ? 20 : 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        validator: widget.validator,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1E293B),
        ),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: TextStyle(
            color: const Color(0xFFA0AEC0),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(
            widget.prefixIcon,
            size: 20,
            color: const Color(0xFF64748B),
          ),
          suffixIcon: widget.suffixIcon,
          filled: true,
          fillColor: Colors.white, // FULL WHITE
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: borderColor, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: borderColor, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.primary, width: 2.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.error, width: 2.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.error, width: 2.5),
          ),
          errorStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: AppColors.error,
          ),
        ),
      ),
    );
  }
}

class _PasswordFieldWithIndicator extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool obscure;
  final VoidCallback onToggle;
  final bool meetsLength;
  final bool isDark;

  const _PasswordFieldWithIndicator({
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.obscure,
    required this.onToggle,
    required this.meetsLength,
    required this.isDark,
  });

  @override
  State<_PasswordFieldWithIndicator> createState() =>
      _PasswordFieldWithIndicatorState();
}

class _PasswordFieldWithIndicatorState
    extends State<_PasswordFieldWithIndicator> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: widget.isDark ? Colors.white : const Color(0xFF1E293B),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        _EnhancedInputField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          hint: 'Min. 8 characters',
          obscureText: widget.obscure,
          prefixIcon: Icons.lock_outline_rounded,
          isDark: widget.isDark,
          suffixIcon: _PasswordVisibilityToggle(
            obscure: widget.obscure,
            onToggle: widget.onToggle,
            isDark: widget.isDark,
          ),
          validator: (v) {
            if (v == null || v.isEmpty) {
              return 'Please enter a password';
            }
            if (v.length < 8) {
              return 'Password must be at least 8 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        // Password strength indicator
        AnimatedOpacity(
          opacity: widget.controller.text.isNotEmpty ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.meetsLength
                      ? Colors.green
                      : Colors.grey.withValues(alpha: 0.3),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.meetsLength
                    ? 'Strong password'
                    : 'At least 8 characters',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.meetsLength
                      ? Colors.green
                      : (widget.isDark
                            ? Colors.white.withValues(alpha: 0.5)
                            : Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PasswordVisibilityToggle extends StatelessWidget {
  final bool obscure;
  final VoidCallback onToggle;
  final bool isDark;

  const _PasswordVisibilityToggle({
    required this.obscure,
    required this.onToggle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: const Color(0xFF64748B),
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _PasswordMatchIndicator extends StatelessWidget {
  final bool match;
  final bool isDark;

  const _PasswordMatchIndicator({required this.match, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: match ? Colors.green : AppColors.error,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          match ? 'Passwords match' : 'Passwords do not match',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: match ? Colors.green : AppColors.error,
          ),
        ),
      ],
    );
  }
}

class _TermsCheckbox extends StatelessWidget {
  final bool agreed;
  final ValueChanged<bool?> onChanged;
  final bool isDark;

  const _TermsCheckbox({
    required this.agreed,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!agreed),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: agreed,
                  onChanged: onChanged,
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  side: BorderSide(color: Colors.grey[400]!, width: 1.5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.grey[700],
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
                    children: [
                      const TextSpan(text: 'I agree to the '),
                      TextSpan(
                        text: 'Terms of Service',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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

class _CreateAccountButton extends StatelessWidget {
  final bool isDark;

  const _CreateAccountButton({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      buildWhen: (prev, curr) =>
          curr is AuthLoading ||
          curr is AuthError ||
          curr is AuthAuthenticated ||
          prev is AuthLoading,
      builder: (context, state) {
        final loading = state is AuthLoading;
        return SizedBox(
          width: double.infinity,
          height: 56,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: loading
                  ? null
                  : () {
                      final form = context
                          .findAncestorStateOfType<_SignupScreenState>();
                      form?._submit();
                    },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppColors.freshMakanGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: loading
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SignInLink extends StatelessWidget {
  final bool isDark;

  const _SignInLink({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Already have an account? ',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  'Sign In',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
