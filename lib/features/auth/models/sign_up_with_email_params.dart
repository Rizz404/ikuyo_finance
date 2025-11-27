import 'dart:convert';

import 'package:equatable/equatable.dart';

class SignUpWithEmailParams extends Equatable {
  final String email;
  final String password;

  const SignUpWithEmailParams({required this.email, required this.password});

  SignUpWithEmailParams copyWith({String? email, String? password}) {
    return SignUpWithEmailParams(
      email: email ?? this.email,
      password: password ?? this.password,
    );
  }

  Map<String, dynamic> toMap() {
    return {'email': email, 'password': password};
  }

  factory SignUpWithEmailParams.fromMap(Map<String, dynamic> map) {
    return SignUpWithEmailParams(
      email: map['email'] ?? '',
      password: map['password'] ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory SignUpWithEmailParams.fromJson(String source) =>
      SignUpWithEmailParams.fromMap(json.decode(source));

  @override
  String toString() =>
      'SignUpWithEmailParams(email: $email, password: $password)';

  @override
  List<Object> get props => [email, password];
}
