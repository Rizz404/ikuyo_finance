import 'package:objectbox/objectbox.dart';
import 'package:ulid/ulid.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';

@Entity()
class Transaction {
  @Id()
  int id;

  @Unique()
  String ulid;

  // * Relasi ke Asset (required)
  final asset = ToOne<Asset>();

  // * Relasi ke Category (optional)
  final category = ToOne<Category>();

  double amount;

  // * Arah transaksi eksplisit (index CategoryType), null = data lama
  // * yang belum di-backfill; lihat TransactionTypeBackfill
  int? type;

  @Property(type: PropertyType.date)
  DateTime? transactionDate;

  String? description;
  String? imagePath;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  @Property(type: PropertyType.date)
  DateTime updatedAt;

  Transaction({
    this.id = 0,
    String? ulid,
    required this.amount,
    this.type,
    this.transactionDate,
    this.description,
    this.imagePath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : ulid = ulid ?? Ulid().toString(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Arah transaksi efektif untuk saldo & statistik
  /// * Prioritas: type eksplisit → tipe kategori → income (perilaku lama)
  @Transient()
  CategoryType get direction {
    final stored = type;
    if (stored != null && stored >= 0 && stored < CategoryType.values.length) {
      return CategoryType.values[stored];
    }
    return category.target?.categoryType ?? CategoryType.income;
  }

  bool get isExpense => direction == CategoryType.expense;
}
