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
  // SESSION CHECK (called from SplashScreen)
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
  // AUTH STATE STREAM LISTENER
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
            final userModel =
                await _supabaseService.getUserProfile(session.user.id);
            emit(AuthAuthenticated(userModel));
            // Link OneSignal device — covers both email AND Google OAuth paths
            await NotificationService.instance.loginUser(userModel.id);
            log('Signed in: ${userModel.email}');
          } catch (e) {
            log('Auth stream signedIn error: $e');
          }
        } else if (event == supa.AuthChangeEvent.signedOut) {
          emit(AuthGuest());
        } else if (event == supa.AuthChangeEvent.tokenRefreshed &&
            session != null) {
          log('Token refreshed for: ${session.user.email}');
        }
      },
      onError: (e) => log('Auth stream error: $e'),
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

  Future<void> login({
    required String email,
    required String password,
  }) async {
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

  Future<void> signInWithGoogle() async {
    emit(AuthLoading());
    try {
      // ✅ Must start listening BEFORE opening the browser,
      // so when the deep link returns, the stream catches it immediately
      _listenToAuthChanges();
      await _supabaseService.signInWithGoogle();
    } catch (e) {
      log('signInWithGoogle cubit error: $e');
      emit(AuthError(e.toString().replaceAll('Exception: ', '')));
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
    final state = this.state;
    if (state is AuthAuthenticated) return state.user;
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