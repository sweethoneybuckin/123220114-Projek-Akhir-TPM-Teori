// lib/models/user_model.dart

class User {
  final int? id;
  final String username;
  final String email;
  final String passwordHash;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final String? profilePhoto; // New field for profile photo path

  User({
    this.id,
    required this.username,
    required this.email,
    required this.passwordHash,
    required this.createdAt,
    this.lastLoginAt,
    this.profilePhoto,
  });

  // Convert User object to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'password_hash': passwordHash,
      'created_at': createdAt.toIso8601String(),
      'last_login_at': lastLoginAt?.toIso8601String(),
      'profile_photo': profilePhoto,
    };
  }

  // Create User object from database Map
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      username: map['username'],
      email: map['email'],
      passwordHash: map['password_hash'],
      createdAt: DateTime.parse(map['created_at']),
      lastLoginAt: map['last_login_at'] != null 
          ? DateTime.parse(map['last_login_at']) 
          : null,
      profilePhoto: map['profile_photo'],
    );
  }

  // Create a copy of User with updated fields
  User copyWith({
    int? id,
    String? username,
    String? email,
    String? passwordHash,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    String? profilePhoto,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      profilePhoto: profilePhoto ?? this.profilePhoto,
    );
  }

  @override
  String toString() {
    return 'User{id: $id, username: $username, email: $email, createdAt: $createdAt, lastLoginAt: $lastLoginAt, profilePhoto: $profilePhoto}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        other.id == id &&
        other.username == username &&
        other.email == email;
  }

  @override
  int get hashCode {
    return id.hashCode ^ username.hashCode ^ email.hashCode;
  }
}