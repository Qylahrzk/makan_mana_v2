import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:makan_mana_v2/logic/cubits/theme_cubit.dart';
import 'package:makan_mana_v2/logic/cubits/user_preferences_cubit.dart';
import 'package:makan_mana_v2/presentation/screens/personalisation_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../../logic/cubits/auth_cubit.dart';
import '../../logic/cubits/profile_cubit.dart';
import '../../logic/cubits/favourite_cubit.dart';
import '../../models/user_model.dart';
import 'favourite_screen.dart';
import 'welcome_screen.dart';
import '../widgets/curved_header_painter.dart';

// ─── SUS Google Form URL ──────────────────────────────────────────────────────
// Replace the URL below with your actual Google Form link.
const _kSusFeedbackUrl = 'https://forms.gle/MhoC8jBwLZj5TbeQ9';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _appVersion;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _loadProfileData();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _appVersion = info.buildNumber.isNotEmpty
            ? '${info.version}+${info.buildNumber}'
            : info.version;
      });
    } catch (_) {
      if (mounted) setState(() => _appVersion = '2.0.0');
    }
  }

  Future<void> _loadProfileData() async {
    await Future.microtask(() {});
    if (!mounted) return;
    final authState = context.read<AuthCubit>().state;
    if (authState is AuthAuthenticated) {
      context.read<ProfileCubit>().loadProfile(authState.user.id);
      context.read<FavouriteCubit>().loadFavourite(authState.user.id);
      context.read<UserPreferencesCubit>().loadPreferences(authState.user.id);
    }
  }

  // ── Open SUS feedback form ────────────────────────────────────────────────
  Future<void> _openSusFeedback() async {
    final uri = Uri.parse(_kSusFeedbackUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Could not open the feedback form.'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not open the feedback form.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  // ── Theme picker sheet ────────────────────────────────────────────────────
  void _showThemeSheet(BuildContext context) {
    const themeOptions = [
      _ThemeOption(
        ThemeMode.system,
        Icons.brightness_auto_rounded,
        'System Default',
        "Follows your phone's dark/light setting",
      ),
      _ThemeOption(
        ThemeMode.light,
        Icons.light_mode_rounded,
        'Light Mode',
        'Always use light theme',
      ),
      _ThemeOption(
        ThemeMode.dark,
        Icons.dark_mode_rounded,
        'Dark Mode',
        'Always use dark theme',
      ),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return BlocProvider.value(
          value: context.read<ThemeCubit>(),
          child: BlocBuilder<ThemeCubit, ThemeMode>(
            builder: (ctx2, current) => Container(
              padding: EdgeInsets.fromLTRB(
                24,
                16,
                24,
                MediaQuery.of(ctx2).padding.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Appearance',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...themeOptions.map((t) {
                    final isSelected = current == t.mode;
                    return GestureDetector(
                      onTap: () {
                        ctx2.read<ThemeCubit>().setTheme(t.mode);
                        Navigator.pop(context);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF6C63FF).withValues(alpha: 0.08)
                              : Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? const Color(
                                    0xFF6C63FF,
                                  ).withValues(alpha: 0.35)
                                : Colors.grey.withValues(alpha: 0.15),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(
                                        0xFF6C63FF,
                                      ).withValues(alpha: 0.12)
                                    : Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                t.icon,
                                color: isSelected
                                    ? const Color(0xFF6C63FF)
                                    : Theme.of(context).colorScheme.onSurface
                                          .withValues(alpha: 0.45),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.label,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? const Color(0xFF6C63FF)
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    t.desc,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF6C63FF),
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Notifications sheet ───────────────────────────────────────────────────
  void _showNotificationSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          MediaQuery.of(ctx).padding.bottom + 24,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Notifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Push notifications are not available in this version.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 20),
            ...[
              {'emoji': '🍽️', 'label': 'New restaurant recommendations'},
              {'emoji': '❤️', 'label': 'Wishlist price drops & updates'},
              {'emoji': '📍', 'label': 'Nearby restaurant alerts'},
            ].map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Text(item['emoji']!, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 12),
                    Text(
                      item['label']!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Soon',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Got it',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Language sheet ────────────────────────────────────────────────────────
  void _showLanguageSheet(BuildContext context) {
    final languages = [
      {'flag': '🇬🇧', 'name': 'English', 'active': true},
      {'flag': '🇲🇾', 'name': 'Bahasa Malaysia', 'active': false},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          MediaQuery.of(ctx).padding.bottom + 24,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Language',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            ...languages.map(
              (lang) => GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  if (lang['active'] != true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${lang['name']} will be available in a future update',
                        ),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        margin: const EdgeInsets.all(16),
                      ),
                    );
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: lang['active'] == true
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: lang['active'] == true
                          ? AppColors.primary.withValues(alpha: 0.3)
                          : Colors.grey.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        lang['flag']! as String,
                        style: const TextStyle(fontSize: 22),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        lang['name']! as String,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: lang['active'] == true
                              ? AppColors.primary
                              : Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                      const Spacer(),
                      if (lang['active'] == true)
                        Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primary,
                          size: 20,
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Soon',
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.5),
                              fontWeight: FontWeight.w600,
                            ),
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

  // ── Edit name sheet ───────────────────────────────────────────────────────
  void _showEditNameSheet(BuildContext context, UserModel user) {
    final ctrl = TextEditingController(text: user.fullName);
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => BlocProvider.value(
        value: context.read<ProfileCubit>(),
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: Container(
            padding: EdgeInsets.fromLTRB(
              28,
              16,
              28,
              MediaQuery.of(sheetCtx).padding.bottom + 32,
            ),
            decoration: BoxDecoration(
              color: Theme.of(sheetCtx).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Theme.of(sheetCtx).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Edit Name',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(sheetCtx).colorScheme.onSurface,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: ctrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Name cannot be empty';
                      }
                      if (v.trim().length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      return null;
                    },
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(sheetCtx).colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Your full name',
                      prefixIcon: Icon(
                        Icons.person_outline_rounded,
                        size: 20,
                        color: Theme.of(
                          sheetCtx,
                        ).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      filled: true,
                      fillColor: Theme.of(
                        sheetCtx,
                      ).colorScheme.surfaceContainer,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(sheetCtx).dividerColor,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(sheetCtx).dividerColor,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  BlocBuilder<ProfileCubit, ProfileState>(
                    builder: (ctx, state) {
                      final saving = state is ProfileLoading;
                      return SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: saving
                              ? null
                              : () {
                                  if (!formKey.currentState!.validate()) return;
                                  ctx.read<ProfileCubit>().updateName(
                                    userId: user.id,
                                    fullName: ctrl.text.trim(),
                                  );
                                  Navigator.pop(context);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Save Changes',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Logout confirmation dialog ────────────────────────────────────────────
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Sign Out',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.5),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthCubit>().logout();
            },
            child: Text(
              'Sign Out',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      toolbarHeight: 110,
      title: const Padding(
        padding: EdgeInsets.only(left: 18),
        child: Text(
          'My Profile',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
            shadows: [
              Shadow(
                offset: Offset(0, 1.5),
                blurRadius: 4.0,
                color: Colors.black26,
              ),
            ],
          ),
        ),
      ),
      flexibleSpace: Stack(
        children: [
          ClipPath(
            clipper: const HeaderCurveClipper(),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: AppColors.oceanGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -1,
            left: -1,
            right: -1,
            child: CustomPaint(
              size: const Size(double.infinity, 48),
              painter: CurvedHeaderPainter.adaptive(context),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
    );

    final authState = context.watch<AuthCubit>().state;
    final isAuthenticated = authState is AuthAuthenticated;

    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthGuest) {
          Navigator.pushAndRemoveUntil(
            context,
            PageRouteBuilder(
              pageBuilder: (_, _, _) => const WelcomeScreen(),
              transitionDuration: const Duration(milliseconds: 400),
              transitionsBuilder: (_, anim, _, child) =>
                  FadeTransition(opacity: anim, child: child),
            ),
            (route) => false,
          );
        }
      },
      child: BlocListener<ProfileCubit, ProfileState>(
        listener: (context, state) {
          if (state is ProfileUpdateSuccess) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  margin: const EdgeInsets.all(16),
                  duration: const Duration(seconds: 2),
                ),
              );
          } else if (state is ProfileError) {
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
          extendBodyBehindAppBar: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: _buildAppBar(),
          body: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 110 + 4,
                ),
              ),
              // ── Profile Content ────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),

                      if (isAuthenticated) ...[
                        BlocBuilder<ProfileCubit, ProfileState>(
                          builder: (context, state) {
                            UserModel? user;
                            if (state is ProfileLoaded) {
                              user = state.user;
                            }
                            if (state is ProfileUpdateSuccess) {
                              user = state.user;
                            }
                            user ??= context.read<AuthCubit>().currentUser;
                            if (user == null) {
                              return const SizedBox.shrink();
                            }
                            return _ProfileCard(
                              user: user,
                              onEditName: () =>
                                  _showEditNameSheet(context, user!),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                      ],

                      // ── Activity ───────────────────────────────────────────
                      if (isAuthenticated) ...[
                        _SectionHeader(label: 'Activity'),
                        const SizedBox(height: 8),
                        _MenuCard(
                          items: [
                            _MenuItem(
                              icon: Icons.favorite_rounded,
                              iconColor: Colors.red,
                              label: 'My Wishlist',
                              trailing:
                                  BlocBuilder<FavouriteCubit, FavouriteState>(
                                    builder: (_, state) {
                                      if (state is FavouriteLoaded &&
                                          state.items.isNotEmpty) {
                                        return _CountBadge(
                                          count: state.items.length,
                                          color: Colors.red,
                                        );
                                      }
                                      return const SizedBox();
                                    },
                                  ),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const FavouriteScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Personalisation ────────────────────────────────────
                      _SectionHeader(label: 'Personalisation'),
                      const SizedBox(height: 8),

                      if (!isAuthenticated)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.secondary.withValues(alpha: 0.12),
                                AppColors.secondary.withValues(alpha: 0.04),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.secondary.withValues(
                                alpha: 0.25,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.lock_outline_rounded,
                                  color: AppColors.primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Sign up to use preferences',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Create an account to personalise your '
                                      'restaurant recommendations.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              TextButton(
                                onPressed: () =>
                                    Navigator.pushNamed(context, '/signup'),
                                style: TextButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Sign Up',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      _MenuCard(
                        items: [
                          _MenuItem(
                            icon: Icons.tune_rounded,
                            iconColor: AppColors.primary,
                            label: 'My Preferences',
                            trailing: isAuthenticated
                                ? BlocBuilder<
                                    UserPreferencesCubit,
                                    UserPreferencesState
                                  >(
                                    builder: (_, st) {
                                      final prefs = context
                                          .read<UserPreferencesCubit>()
                                          .current;
                                      return Text(
                                        prefs?.hasAnyPreference == true
                                            ? 'Configured ✓'
                                            : 'Not set',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: prefs?.hasAnyPreference == true
                                              ? AppColors.secondary
                                              : Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.4),
                                        ),
                                      );
                                    },
                                  )
                                : Icon(
                                    Icons.lock_outline_rounded,
                                    size: 16,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.3),
                                  ),
                            onTap: () {
                              if (!isAuthenticated) {
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Please sign up to use preferences',
                                      ),
                                      backgroundColor: AppColors.primary,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      margin: const EdgeInsets.all(16),
                                      action: SnackBarAction(
                                        label: 'Sign Up',
                                        textColor: Colors.white,
                                        onPressed: () => Navigator.pushNamed(
                                          context,
                                          '/signup',
                                        ),
                                      ),
                                    ),
                                  );
                                return;
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MultiBlocProvider(
                                    providers: [
                                      BlocProvider.value(
                                        value: context
                                            .read<UserPreferencesCubit>(),
                                      ),
                                      BlocProvider.value(
                                        value: context.read<AuthCubit>(),
                                      ),
                                    ],
                                    child: const PersonalisationScreen(),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ── Settings ───────────────────────────────────────────
                      _SectionHeader(label: 'Settings'),
                      const SizedBox(height: 8),
                      _MenuCard(
                        items: [
                          _MenuItem(
                            icon: Icons.dark_mode_rounded,
                            iconColor: const Color(0xFF6C63FF),
                            label: 'Appearance',
                            trailing: BlocBuilder<ThemeCubit, ThemeMode>(
                              builder: (ctx, mode) => GestureDetector(
                                onTap: () => _showThemeSheet(ctx),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF6C63FF,
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        mode == ThemeMode.dark
                                            ? Icons.dark_mode_rounded
                                            : mode == ThemeMode.light
                                            ? Icons.light_mode_rounded
                                            : Icons.brightness_auto_rounded,
                                        size: 12,
                                        color: const Color(0xFF6C63FF),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        ctx.read<ThemeCubit>().label,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF6C63FF),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            onTap: () => _showThemeSheet(context),
                            showChevron: false,
                          ),
                          _MenuItem(
                            icon: Icons.notifications_none_rounded,
                            iconColor: AppColors.secondary,
                            label: 'Notifications',
                            onTap: () => _showNotificationSheet(context),
                          ),
                          _MenuItem(
                            icon: Icons.language_rounded,
                            iconColor: AppColors.tertiary,
                            label: 'Language',
                            trailingText: 'English',
                            onTap: () => _showLanguageSheet(context),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ── About ──────────────────────────────────────────────
                      _SectionHeader(label: 'About'),
                      const SizedBox(height: 8),
                      _MenuCard(
                        items: [
                          _MenuItem(
                            icon: Icons.info_outline_rounded,
                            iconColor: AppColors.primary,
                            label: 'App Version',
                            trailingText: _appVersion ?? '...',
                            onTap: () {},
                            showChevron: false,
                          ),
                          _MenuItem(
                            icon: Icons.school_rounded,
                            iconColor: AppColors.secondary,
                            label: 'FYP Project',
                            trailingText: 'UiTM',
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRoutes.fypShowcase,
                            ),
                          ),

                          // ── SUS Feedback button ────────────────────────────
                          // Opens the Google Form SUS questionnaire in browser.
                          // Replace _kSusFeedbackUrl at the top of this file
                          // with your actual Google Form link.
                          _MenuItem(
                            icon: Icons.rate_review_rounded,
                            iconColor: const Color(0xFF7C4DFF),
                            label: 'Feedback',
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF7C4DFF,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Google Form',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF7C4DFF),
                                ),
                              ),
                            ),
                            onTap: _openSusFeedback,
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ── Sign Out / Sign In ─────────────────────────────────
                      if (isAuthenticated)
                        _MenuCard(
                          items: [
                            _MenuItem(
                              icon: Icons.logout_rounded,
                              iconColor: AppColors.error,
                              label: 'Sign Out',
                              labelColor: AppColors.error,
                              onTap: () => _showLogoutDialog(context),
                              showChevron: false,
                            ),
                          ],
                        )
                      else
                        _MenuCard(
                          items: [
                            _MenuItem(
                              icon: Icons.login_rounded,
                              iconColor: AppColors.primary,
                              label: 'Sign In',
                              labelColor: AppColors.primary,
                              onTap: () =>
                                  Navigator.pushNamed(context, '/login'),
                              showChevron: false,
                            ),
                          ],
                        ),

                      const SizedBox(height: 160),
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

// ─── Profile Card ─────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onEditName;
  const _ProfileCard({required this.user, required this.onEditName});

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(user.fullName);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppColors.oceanGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName.isNotEmpty ? user.fullName : 'No name set',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                if (user.createdAt != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 11,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Joined ${_formatJoinDate(user.createdAt!)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: onEditName,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.edit_rounded,
                size: 17,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || name.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  String _formatJoinDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          letterSpacing: 1.2,
        ),
      ),
    ),
  );
}

// ─── Menu Card ────────────────────────────────────────────────────────────────

class _MenuCard extends StatelessWidget {
  final List<_MenuItem> items;
  const _MenuCard({required this.items});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Column(
            children: [
              item,
              if (i < items.length - 1)
                Divider(
                  height: 1,
                  indent: 54,
                  endIndent: 16,
                  color: Theme.of(context).colorScheme.surfaceContainer,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─── Menu Item ────────────────────────────────────────────────────────────────

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color? labelColor;
  final String? trailingText;
  final Widget? trailing;
  final VoidCallback onTap;
  final bool showChevron;

  const _MenuItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.labelColor,
    this.trailingText,
    this.trailing,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: labelColor ?? Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            // ignore: use_null_aware_elements
            if (trailing != null) trailing!,
            if (trailingText != null)
              Text(
                trailingText!,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.4),
                  fontWeight: FontWeight.w500,
                ),
              ),
            if (showChevron) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.3),
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Count Badge ──────────────────────────────────────────────────────────────

class _CountBadge extends StatelessWidget {
  final int count;
  final Color color;
  const _CountBadge({required this.count, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      '$count',
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
    ),
  );
}

// ─── Theme Option ─────────────────────────────────────────────────────────────

class _ThemeOption {
  final ThemeMode mode;
  final IconData icon;
  final String label;
  final String desc;
  const _ThemeOption(this.mode, this.icon, this.label, this.desc);
}
