import 'package:objectbox/objectbox.dart';
import 'package:ulid/ulid.dart';

enum CategoryType { income, expense }

@Entity()
class Category {
  @Id()
  int id;

  @Unique()
  String ulid;

  // * Self-referencing untuk nested category
  final parent = ToOne<Category>();

  String name;
  int type; // * Stored as int, mapped to CategoryType enum
  String? icon;
  String? color;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  @Property(type: PropertyType.date)
  DateTime updatedAt;

  Category({
    this.id = 0,
    String? ulid,
    required this.name,
    required this.type,
    this.icon,
    this.color,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : ulid = ulid ?? Ulid().toString(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  // * Helper getters/setters untuk type enum
  CategoryType get categoryType => CategoryType.values[type];
  set categoryType(CategoryType value) => type = value.index;
}
