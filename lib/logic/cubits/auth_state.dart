part of 'auth_cubit.dart';

abstract class AuthState {}

/// App has just launched — checking session status.
class AuthInitial extends AuthState {}

/// An auth operation is in progress (login, signup, logout, Google OAuth).
class AuthLoading extends AuthState {}

/// User is fully authenticated with a valid session.
class AuthAuthenticated extends AuthState {
  final UserModel user;
  AuthAuthenticated(this.user);
}

/// User chose to continue as guest — no account.
class AuthGuest extends AuthState {}

/// An auth operation failed — message is shown in UI.
class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

/// Password reset email was sent successfully.
class AuthPasswordResetSent extends AuthState {}
