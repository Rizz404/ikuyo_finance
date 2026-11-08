import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:ikuyo_finance/objectbox.g.dart';

/// * Tanggal efektif transaksi = transactionDate ?? createdAt (F6, NEW-3)
/// * transactionDate eksplisit selalu menang; createdAt hanya dipakai untuk
///   baris lama yang transactionDate-nya null (data tidak ditulis ulang)
extension TransactionEffectiveDate on Transaction {
  DateTime get effectiveDate => transactionDate ?? createdAt;
}

/// * Kondisi query ObjectBox untuk rentang tanggal efektif.
/// * [from] inklusif; [to] inklusif bila [toInclusive] (akhir periode
///   = milidetik terakhir), atau eksklusif untuk rentang setengah terbuka.
/// * Mengembalikan null bila kedua batas null (tanpa filter tanggal).
Condition<Transaction>? effectiveDateCondition({
  DateTime? from,
  DateTime? to,
  bool toInclusive = true,
}) {
  if (from == null && to == null) return null;

  Condition<Transaction>? range(QueryDateProperty<Transaction> p) {
    final lower = from == null ? null : p.greaterOrEqualDate(from);
    final upper = to == null
        ? null
        : toInclusive
        ? p.lessOrEqualDate(to)
        : p.lessThanDate(to);
    if (lower != null && upper != null) return lower.and(upper);
    return lower ?? upper;
  }

  return range(Transaction_.transactionDate)!.or(
    Transaction_.transactionDate.isNull().and(range(Transaction_.createdAt)!),
  );
}
