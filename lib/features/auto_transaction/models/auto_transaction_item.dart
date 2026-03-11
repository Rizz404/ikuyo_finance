import 'package:objectbox/objectbox.dart';
import 'package:ulid/ulid.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_group.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';

@Entity()
class AutoTransactionItem {
  @Id()
  int id;

  @Unique()
  String ulid;

  // * Bisa disable 1 item tanpa hapus grup
  bool isActive;

  // * Urutan tampil dalam grup
  int sortOrder;

  // * Template transaksi — amount, asset, category, description dibaca dari sini saat eksekusi
  final transaction = ToOne<Transaction>();

  final group = ToOne<AutoTransactionGroup>();

  @Property(type: PropertyType.date)
  DateTime createdAt;

  @Property(type: PropertyType.date)
  DateTime updatedAt;

  AutoTransactionItem({
    this.id = 0,
    String? ulid,
    this.isActive = true,
    this.sortOrder = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : ulid = ulid ?? Ulid().toString(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();
}
