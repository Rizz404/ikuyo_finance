// Regression: P03. One-shot ObjectBox queries must always be closed, including
// when the query throws, instead of leaving native handles to the GC finalizer.
// Fakes stand in for the native Query handle so close() is observable; the
// repository paths themselves run on real ObjectBox in their own suites.
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/core/storage/query_extensions.dart';
import 'package:objectbox/objectbox.dart';

class _FakeQuery extends Fake implements Query<String> {
  _FakeQuery({this.fail = false});
  final bool fail;
  int closed = 0;

  void _maybeFail() {
    if (fail) throw StateError('native failure');
  }

  @override
  String? findFirst() {
    _maybeFail();
    return 'a';
  }

  @override
  List<String> find() {
    _maybeFail();
    return ['a', 'b'];
  }

  @override
  int count() {
    _maybeFail();
    return 2;
  }

  @override
  void close() => closed++;
}

class _FakeBuilder extends Fake implements QueryBuilder<String> {
  _FakeBuilder(this.query);
  final _FakeQuery query;

  @override
  Query<String> build() => query;
}

void main() {
  test('findFirstAndClose / findAndClose / countAndClose close the query', () {
    final q1 = _FakeQuery();
    final q2 = _FakeQuery();
    final q3 = _FakeQuery();

    expect(_FakeBuilder(q1).findFirstAndClose(), 'a');
    expect(_FakeBuilder(q2).findAndClose(), ['a', 'b']);
    expect(_FakeBuilder(q3).countAndClose(), 2);

    expect([q1.closed, q2.closed, q3.closed], [1, 1, 1]);
  });

  test('the query is closed even when it throws', () {
    final q1 = _FakeQuery(fail: true);
    final q2 = _FakeQuery(fail: true);
    final q3 = _FakeQuery(fail: true);

    expect(() => _FakeBuilder(q1).findFirstAndClose(), throwsStateError);
    expect(() => _FakeBuilder(q2).findAndClose(), throwsStateError);
    expect(() => _FakeBuilder(q3).countAndClose(), throwsStateError);

    expect([q1.closed, q2.closed, q3.closed], [1, 1, 1]);
  });
}
