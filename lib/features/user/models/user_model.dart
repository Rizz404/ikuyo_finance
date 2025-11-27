import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

enum UserRole {
  admin('Admin'),
  user('User');

  const UserRole(this.value);

  final String value;
}

class UserModel extends Equatable {
  final String id;
  final String supabaseId;
  final String name;
  final String email;
  final String password;
  final UserRole role;
  final String profilePicture;
  final String phoneNumber;
  final String bio;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.id,
    required this.supabaseId,
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    required this.profilePicture,
    required this.phoneNumber,
    required this.bio,
    this.createdAt,
    this.updatedAt,
  });

  UserModel copyWith({
    String? id,
    String? supabaseId,
    String? name,
    String? email,
    String? password,
    UserRole? role,
    String? profilePicture,
    String? phoneNumber,
    String? bio,
    ValueGetter<DateTime?>? createdAt,
    ValueGetter<DateTime?>? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      supabaseId: supabaseId ?? this.supabaseId,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      role: role ?? this.role,
      profilePicture: profilePicture ?? this.profilePicture,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      bio: bio ?? this.bio,
      createdAt: createdAt != null ? createdAt() : this.createdAt,
      updatedAt: updatedAt != null ? updatedAt() : this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'supabaseId': supabaseId,
      'name': name,
      'email': email,
      'password': password,
      'role': role.value,
      'profilePicture': profilePicture,
      'phoneNumber': phoneNumber,
      'bio': bio,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      supabaseId: map['supabaseId'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      password: map['password'] ?? '',
      role: UserRole.values.firstWhere((e) => e.value == map['role']),
      profilePicture: map['profilePicture'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      bio: map['bio'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'])
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory UserModel.fromJson(String source) =>
      UserModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'UserModel(id: $id, supabaseId: $supabaseId, name: $name, email: $email, password: $password, role: $role, profilePicture: $profilePicture, phoneNumber: $phoneNumber, bio: $bio, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  List<Object?> get props {
    return [
      id,
      supabaseId,
      name,
      email,
      password,
      role,
      profilePicture,
      phoneNumber,
      bio,
      createdAt,
      updatedAt,
    ];
  }
}
