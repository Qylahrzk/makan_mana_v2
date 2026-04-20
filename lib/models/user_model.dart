import 'package:equatable/equatable.dart';

/// Represents an authenticated user in the app.
/// Maps to the 'users' table in Supabase.

class UserModel extends Equatable {
  final String id;
  final String email;
  final String fullName;
  final String? avatarUrl;
  final DateTime? createdAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.avatarUrl,
    this.createdAt,
  });

  // ─────────────────────────────────────────
  // FACTORY CONSTRUCTORS
  // ─────────────────────────────────────────

  /// Creates a UserModel from Supabase users table JSON.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  /// Creates a UserModel directly from Supabase Auth User object.
  /// Use this right after login/signup before the users table is queried.
  factory UserModel.fromSupabaseUser(Map<String, dynamic> userMetadata, String id, String email) {
    return UserModel(
      id: id,
      email: email,
      fullName: userMetadata['full_name']?.toString() ??
          userMetadata['name']?.toString() ?? '',
      avatarUrl: userMetadata['avatar_url']?.toString(),
    );
  }

  // ─────────────────────────────────────────
  // SERIALIZATION
  // ─────────────────────────────────────────

  /// Converts UserModel to JSON for upserting into Supabase users table.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'avatar_url': avatarUrl,
    };
  }

  // ─────────────────────────────────────────
  // COPY WITH
  // ─────────────────────────────────────────

  UserModel copyWith({
    String? id,
    String? email,
    String? fullName,
    String? avatarUrl,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // ─────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────

  /// Returns first name only from fullName.
  /// e.g. "Aqilah Razak" → "Aqilah"
  String get firstName {
    final parts = fullName.trim().split(' ');
    return parts.isNotEmpty ? parts.first : fullName;
  }

  /// Returns true if the user has a profile photo.
  bool get hasAvatar => avatarUrl != null && avatarUrl!.isNotEmpty;

  @override
  List<Object?> get props => [id, email, fullName, avatarUrl, createdAt];

  @override
  String toString() =>
      'UserModel(id: $id, email: $email, fullName: $fullName)';
}