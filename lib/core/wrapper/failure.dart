import 'dart:convert';

import 'package:equatable/equatable.dart';

class Failure extends Equatable {
  final String message;

  const Failure({required this.message});

  Failure copyWith({String? message}) {
    return Failure(message: message ?? this.message);
  }

  Map<String, dynamic> toMap() {
    return {'message': message};
  }

  factory Failure.fromMap(Map<String, dynamic> map) {
    return Failure(message: map['message'] ?? '');
  }

  String toJson() => json.encode(toMap());

  factory Failure.fromJson(String source) =>
      Failure.fromMap(json.decode(source));

  @override
  String toString() => 'Failure(message: $message)';

  @override
  List<Object> get props => [message];
}
