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
    this.transactionDate,
    this.description,
    this.imagePath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : ulid = ulid ?? Ulid().toString(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();
}
