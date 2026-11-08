import 'package:objectbox/objectbox.dart';

/// * Query sekali pakai: build, jalankan, lalu selalu close (P03)
extension QueryBuilderClose<T> on QueryBuilder<T> {
  T? findFirstAndClose() {
    final query = build();
    try {
      return query.findFirst();
    } finally {
      query.close();
    }
  }

  List<T> findAndClose() {
    final query = build();
    try {
      return query.find();
    } finally {
      query.close();
    }
  }

  int countAndClose() {
    final query = build();
    try {
      return query.count();
    } finally {
      query.close();
    }
  }
}
