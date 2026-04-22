import 'dart:async' show StreamSubscription;
import 'dart:developer';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import '../../data/supabase_service.dart';
import '../../data/notification_service.dart';
import '../../models/user_model.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final SupabaseService _supabaseService;
  StreamSubscription<supa.AuthState>? _authSubscription;

  AuthCubit(this._supabaseService) : super(AuthInitial());

  // ─────────────────────────────────────────
  // SESSION CHECK
  // ─────────────────────────────────────────

  Future<void> checkSession() async {
    try {
      final user = _supabaseService.currentAuthUser;
      if (user != null) {
        final userModel = await _supabaseService.getUserProfile(user.id);
        emit(AuthAuthenticated(userModel));
        _listenToAuthChanges();
        log('Session restored for: ${userModel.email}');
      } else {
        emit(AuthGuest());
        log('No active session — guest mode');
      }
    } catch (e) {
      log('checkSession error: $e');
      emit(AuthGuest());
    }
  }

  // ─────────────────────────────────────────
  // AUTH STATE STREAM
  // ─────────────────────────────────────────

  void _listenToAuthChanges() {
    _authSubscription?.cancel();
    _authSubscription = _supabaseService.authStateStream.listen(
      (authState) async {
        final event = authState.event;
        final session = authState.session;

        log('Auth state change: $event');

        if (event == supa.AuthChangeEvent.signedIn && session != null) {
          try {
            final userModel = await _supabaseService.getUserProfile(
              session.user.id,
            );
            emit(AuthAuthenticated(userModel));
            await NotificationService.instance.loginUser(userModel.id);
            log('Signed in: ${userModel.email}');
          } catch (e) {
            log('Auth stream signedIn error: $e');
            // FIX: Don't leave user stuck on AuthLoading if profile fetch
            // fails (e.g. new Google user with no profile row yet).
            // Build a minimal UserModel from the session data instead.
            final fallback = UserModel(
              id: session.user.id,
              email: session.user.email ?? '',
              fullName:
                  session.user.userMetadata?['full_name'] as String? ??
                  session.user.userMetadata?['name'] as String? ??
                  'User',
            );
            emit(AuthAuthenticated(fallback));
          }
        } else if (event == supa.AuthChangeEvent.signedOut) {
          emit(AuthGuest());
        } else if (event == supa.AuthChangeEvent.tokenRefreshed &&
            session != null) {
          log('Token refreshed for: ${session.user.email}');
        }
      },
      onError: (e) {
        log('Auth stream error: $e');
        // FIX: Don't silently swallow stream errors — emit guest so
        // the user isn't stuck on a loading screen
        emit(AuthGuest());
      },
    );
  }

  // ─────────────────────────────────────────
  // SIGN UP
  // ─────────────────────────────────────────

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    emit(AuthLoading());
    try {
      final user = await _supabaseService.signUpWithEmail(
        email: email,
        password: password,
        fullName: fullName,
      );
      emit(AuthAuthenticated(user));
      _listenToAuthChanges();
      log('SignUp complete: ${user.email}');
    } catch (e) {
      log('signUp cubit error: $e');
      emit(AuthError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  // ─────────────────────────────────────────
  // LOGIN
  // ─────────────────────────────────────────

  Future<void> login({required String email, required String password}) async {
    emit(AuthLoading());
    try {
      final user = await _supabaseService.signInWithEmail(
        email: email,
        password: password,
      );
      emit(AuthAuthenticated(user));
      _listenToAuthChanges();
      await NotificationService.instance.loginUser(user.id);
      log('Login complete: ${user.email}');
    } catch (e) {
      log('login cubit error: $e');
      emit(AuthError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  // ─────────────────────────────────────────
  // GOOGLE SIGN IN
  // ─────────────────────────────────────────
  //
  // Flow:
  //   1. Start listening to auth stream FIRST (before browser opens)
  //   2. Call supabase_service.signInWithGoogle() — opens browser
  //   3. User authenticates in browser
  //   4. Browser redirects to com.example.makan_mana_v2://login-callback
  //   5. AndroidManifest intent-filter catches the deep link
  //   6. Supabase SDK processes the callback → fires authStateStream signedIn
  //   7. _listenToAuthChanges() handles the signedIn event → emits AuthAuthenticated
  //
  // IMPORTANT: The redirect URL used in signInWithGoogle() MUST exactly match
  // what is registered in Supabase → Authentication → URL Configuration
  // → Redirect URLs. For v2 this must be:
  //   com.example.makan_mana_v2://login-callback

  Future<void> signInWithGoogle() async {
    emit(AuthLoading());
    try {
      // Start listening BEFORE opening the browser so we catch
      // the signedIn event that fires when the deep link returns
      _listenToAuthChanges();
      await _supabaseService.signInWithGoogle();
      // After this call the browser opens. Control returns here
      // immediately. The actual auth completion is handled by the
      // auth stream listener above — we don't emit here.
    } catch (e) {
      log('signInWithGoogle cubit error: $e');
      // FIX: Cancel the stream if we get an immediate error
      // so we don't leave a dangling listener
      _authSubscription?.cancel();
      emit(AuthError('Google sign-in failed. Please try again.'));
    }
  }

  // ─────────────────────────────────────────
  // GUEST MODE
  // ─────────────────────────────────────────

  void continueAsGuest() {
    log('Continuing as guest');
    emit(AuthGuest());
  }

  // ─────────────────────────────────────────
  // PASSWORD RESET
  // ─────────────────────────────────────────

  Future<void> sendPasswordReset(String email) async {
    emit(AuthLoading());
    try {
      await _supabaseService.sendPasswordResetEmail(email);
      emit(AuthPasswordResetSent());
      log('Password reset sent to: $email');
    } catch (e) {
      log('sendPasswordReset cubit error: $e');
      emit(AuthError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  // ─────────────────────────────────────────
  // LOGOUT
  // ─────────────────────────────────────────

  Future<void> logout() async {
    emit(AuthLoading());
    try {
      await _supabaseService.signOut();
      _authSubscription?.cancel();
      await NotificationService.instance.logoutUser();
      emit(AuthGuest());
      log('Logout complete');
    } catch (e) {
      log('logout cubit error: $e');
      emit(AuthError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  // ─────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────

  UserModel? get currentUser {
    final s = state;
    if (s is AuthAuthenticated) return s.user;
    return null;
  }

  bool get isAuthenticated => state is AuthAuthenticated;
  bool get isGuest => state is AuthGuest;

  // ─────────────────────────────────────────
  // CLEANUP
  // ─────────────────────────────────────────

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }
}
