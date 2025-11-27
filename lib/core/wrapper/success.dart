import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

class Success<T> extends Equatable {
  final String? message;
  final T? data;

  const Success({this.message, this.data});

  Success<T> copyWith({ValueGetter<String?>? message, ValueGetter<T?>? data}) {
    return Success<T>(
      message: message != null ? message() : this.message,
      data: data != null ? data() : this.data,
    );
  }

  Map<String, dynamic> toMap() {
    return {'message': message, 'data': data};
  }

  factory Success.fromMap(
    Map<String, dynamic> map,
    T Function(dynamic json)? fromJsonT,
  ) {
    return Success(
      message: map['message'],
      data: fromJsonT != null ? fromJsonT(map['data']) : map['data'] as T,
    );
  }

  String toJson() => json.encode(toMap());

  factory Success.fromJson(
    String source,
    T Function(dynamic json)? fromJsonT,
  ) => Success.fromMap(json.decode(source), fromJsonT);

  @override
  String toString() => 'Success(message: $message, data: $data)';

  @override
  List<Object?> get props => [message, data];
}

class SuccessCursor<T> extends Success<List<T>> with EquatableMixin {
  final CursorInfo cursor;

  SuccessCursor({
    required super.message,
    required super.data,
    required this.cursor,
  }) : super();

  @override
  SuccessCursor<T> copyWith({
    ValueGetter<String?>? message,
    ValueGetter<List<T>?>? data,
    ValueGetter<CursorInfo>? cursor,
  }) {
    return SuccessCursor<T>(
      message: message != null ? message() : this.message,
      data: data != null ? data() : this.data,
      cursor: cursor != null ? cursor() : this.cursor,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {'message': message, 'data': data, 'cursor': cursor.toMap()};
  }

  factory SuccessCursor.fromMap(
    Map<String, dynamic> map,
    T Function(dynamic json) fromJsonT,
  ) {
    return SuccessCursor<T>(
      message: map['message'],
      data: (map['data'] as List<dynamic>)
          .map((item) => fromJsonT(item))
          .toList(),
      cursor: CursorInfo.fromMap(map['cursor']),
    );
  }

  @override
  String toJson() => json.encode(toMap());

  factory SuccessCursor.fromJson(
    String source,
    T Function(dynamic json) fromJsonT,
  ) => SuccessCursor.fromMap(json.decode(source), fromJsonT);

  @override
  String toString() => 'SuccessCursor(cursor: $cursor)';

  @override
  List<Object> get props => [cursor];
}

class CursorInfo extends Equatable {
  final String nextCursor;
  final bool hasNextPage;
  final int perPage;

  const CursorInfo({
    required this.nextCursor,
    required this.hasNextPage,
    required this.perPage,
  });

  CursorInfo copyWith({String? nextCursor, bool? hasNextPage, int? perPage}) {
    return CursorInfo(
      nextCursor: nextCursor ?? this.nextCursor,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      perPage: perPage ?? this.perPage,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nextCursor': nextCursor,
      'hasNextPage': hasNextPage,
      'perPage': perPage,
    };
  }

  factory CursorInfo.fromMap(Map<String, dynamic> map) {
    return CursorInfo(
      nextCursor: map['nextCursor'] ?? '',
      hasNextPage: map['hasNextPage'] ?? false,
      perPage: map['perPage']?.toInt() ?? 0,
    );
  }

  String toJson() => json.encode(toMap());

  factory CursorInfo.fromJson(String source) =>
      CursorInfo.fromMap(json.decode(source));

  @override
  String toString() =>
      'CursorInfo(nextCursor: $nextCursor, hasNextPage: $hasNextPage, perPage: $perPage)';

  @override
  List<Object> get props => [nextCursor, hasNextPage, perPage];
}

class ActionSuccess extends Success {
  const ActionSuccess({super.message});

  @override
  List<Object?> get props => [message];
}
