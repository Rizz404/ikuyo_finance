import 'package:ikuyo_finance/core/extensions/logger_extension.dart';
import 'package:ikuyo_finance/core/storage/objectbox_storage.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:ikuyo_finance/objectbox.g.dart';

/// Migrasi non-destruktif: isi Transaction.type untuk data lama
/// * Arah diambil dari kategori; tanpa kategori = income (cara saldo lama
///   dihitung), sehingga saldo aset tidak berubah
/// * Idempoten: hanya baris dengan type null yang disentuh
class TransactionTypeBackfill {
  final ObjectBoxStorage _storage;

  const TransactionTypeBackfill(this._storage);

  int run() {
    return _storage.store.runInTransaction(TxMode.write, () {
      final box = _storage.box<Transaction>();
      final query = box.query(Transaction_.type.isNull()).build();
      final legacy = query.find();
      query.close();
      if (legacy.isEmpty) return 0;

      for (final transaction in legacy) {
        transaction.type =
            transaction.category.target?.type ?? CategoryType.income.index;
      }
      box.putMany(legacy);
      logInfo('Backfill arah transaksi: ${legacy.length} baris');
      return legacy.length;
    });
  }
}
