part of 'profile_cubit.dart';

abstract class ProfileState {
  const ProfileState();
}

/// No profile loaded yet.
class ProfileInitial extends ProfileState {}

/// Fetching profile from Supabase.
class ProfileLoading extends ProfileState {}

/// Profile loaded successfully.
class ProfileLoaded extends ProfileState {
  final UserModel user;
  const ProfileLoaded(this.user);
}

/// Name or avatar updated successfully.
class ProfileUpdateSuccess extends ProfileState {
  final UserModel user;
  final String message;
  const ProfileUpdateSuccess({required this.user, required this.message});
}

/// An operation failed.
class ProfileError extends ProfileState {
  final String message;
  const ProfileError(this.message);
}