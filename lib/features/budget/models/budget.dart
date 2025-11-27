import 'package:objectbox/objectbox.dart';
import 'package:ulid/ulid.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';

enum BudgetPeriod { monthly, weekly, yearly, custom }

@Entity()
class Budget {
  @Id()
  int id;

  @Unique()
  String ulid;

  // * Relasi ke Category (required)
  final category = ToOne<Category>();

  double amountLimit;
  int period; // * Stored as int, mapped to BudgetPeriod enum

  @Property(type: PropertyType.date)
  DateTime? startDate;

  @Property(type: PropertyType.date)
  DateTime? endDate;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  @Property(type: PropertyType.date)
  DateTime updatedAt;

  Budget({
    this.id = 0,
    String? ulid,
    required this.amountLimit,
    this.period = 0, // * Default: monthly
    this.startDate,
    this.endDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : ulid = ulid ?? Ulid().toString(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  // * Helper getters/setters untuk period enum
  BudgetPeriod get budgetPeriod => BudgetPeriod.values[period];
  set budgetPeriod(BudgetPeriod value) => period = value.index;
}
