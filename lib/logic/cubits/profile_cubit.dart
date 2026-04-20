import 'dart:developer';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/supabase_service.dart';
import '../../models/user_model.dart';

part 'profile_state.dart';

/// ProfileCubit
///
/// Manages loading and updating the user's profile.
///
/// Place in: lib/logic/cubits/profile_cubit.dart

class ProfileCubit extends Cubit<ProfileState> {
  final SupabaseService _supabaseService;

  ProfileCubit(this._supabaseService) : super(ProfileInitial());

  Future<void> loadProfile(String userId) async {
    emit(ProfileLoading());
    try {
      final user = await _supabaseService.getUserProfile(userId);
      emit(ProfileLoaded(user));
    } catch (e) {
      log('loadProfile error: $e');
      emit(const ProfileError('Failed to load profile.'));
    }
  }

  Future<void> updateName({
    required String userId,
    required String fullName,
  }) async {
    emit(ProfileLoading());
    try {
      final updatedUser = await _supabaseService.updateUserProfile(
        userId: userId,
        fullName: fullName,
      );
      emit(ProfileUpdateSuccess(
        user: updatedUser,
        message: 'Name updated successfully.',
      ));
    } catch (e) {
      log('updateName error: $e');
      emit(const ProfileError('Failed to update name.'));
    }
  }

  Future<void> updateAvatar({
    required String userId,
    required String avatarUrl,
  }) async {
    emit(ProfileLoading());
    try {
      final updatedUser = await _supabaseService.updateUserProfile(
        userId: userId,
        avatarUrl: avatarUrl,
      );
      emit(ProfileUpdateSuccess(
        user: updatedUser,
        message: 'Profile photo updated.',
      ));
    } catch (e) {
      log('updateAvatar error: $e');
      emit(const ProfileError('Failed to update avatar.'));
    }
  }
}