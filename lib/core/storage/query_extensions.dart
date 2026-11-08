import 'package:flutter/foundation.dart';
import 'package:objectbox/objectbox.dart';

/// * Hitungan query & baris per entitas untuk uji efisiensi (P03/F7)
/// * Hanya penjumlahan integer di memori; tidak menyimpan data entitas
class QueryStats {
  QueryStats._();

  static final Map<Type, int> _queries = {};
  static final Map<Type, int> _rows = {};

  static int queriesOf<T>() => _queries[T] ?? 0;
  static int rowsOf<T>() => _rows[T] ?? 0;

  @visibleForTesting
  static void reset() {
    _queries.clear();
    _rows.clear();
  }

  static void _record<T>(int rows) {
    _queries[T] = (_queries[T] ?? 0) + 1;
    _rows[T] = (_rows[T] ?? 0) + rows;
  }
}

/// * Query sekali pakai: build, jalankan, lalu selalu close (P03)
extension QueryBuilderClose<T> on QueryBuilder<T> {
  T? findFirstAndClose() {
    final query = build();
    try {
      final result = query.findFirst();
      QueryStats._record<T>(result == null ? 0 : 1);
      return result;
    } finally {
      query.close();
    }
  }

  List<T> findAndClose() {
    final query = build();
    try {
      final result = query.find();
      QueryStats._record<T>(result.length);
      return result;
    } finally {
      query.close();
    }
  }

  /// * Satu halaman langsung dari ObjectBox (offset/limit native), bukan
  ///   find-all lalu sublist; offset negatif diperlakukan sebagai 0
  List<T> findPageAndClose({required int offset, required int limit}) {
    final query = build();
    try {
      query
        ..offset = offset < 0 ? 0 : offset
        ..limit = limit;
      final result = query.find();
      QueryStats._record<T>(result.length);
      return result;
    } finally {
      query.close();
    }
  }

  List<int> findIdsAndClose() {
    final query = build();
    try {
      final result = query.findIds();
      QueryStats._record<T>(0);
      return result;
    } finally {
      query.close();
    }
  }

  int countAndClose() {
    final query = build();
    try {
      final result = query.count();
      QueryStats._record<T>(0);
      return result;
    } finally {
      query.close();
    }
  }
}
