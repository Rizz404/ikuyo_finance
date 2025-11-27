import 'dart:convert';

import 'package:equatable/equatable.dart';

class SignInWithEmailParams extends Equatable {
  final String email;
  final String password;

  const SignInWithEmailParams({required this.email, required this.password});

  SignInWithEmailParams copyWith({String? email, String? password}) {
    return SignInWithEmailParams(
      email: email ?? this.email,
      password: password ?? this.password,
    );
  }

  Map<String, dynamic> toMap() {
    return {'email': email, 'password': password};
  }

  factory SignInWithEmailParams.fromMap(Map<String, dynamic> map) {
    return SignInWithEmailParams(
      email: map['email'] ?? '',
      password: map['password'] ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory SignInWithEmailParams.fromJson(String source) =>
      SignInWithEmailParams.fromMap(json.decode(source));

  @override
  String toString() =>
      'SignInWithEmailParams(email: $email, password: $password)';

  @override
  List<Object> get props => [email, password];
}
