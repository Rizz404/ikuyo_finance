import 'package:objectbox/objectbox.dart';
import 'package:ulid/ulid.dart';

enum AssetType { cash, bank, easset, investment }

@Entity()
class Asset {
  @Id()
  int id;

  @Unique()
  String ulid;

  String name;
  int type; // * Stored as int, mapped to AssetType enum
  double balance;
  String? icon;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  @Property(type: PropertyType.date)
  DateTime updatedAt;

  Asset({
    this.id = 0,
    String? ulid,
    required this.name,
    required this.type,
    this.balance = 0,
    this.icon,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : ulid = ulid ?? Ulid().toString(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  // * Helper getters/setters untuk type enum
  AssetType get assetType => AssetType.values[type];
  set assetType(AssetType value) => type = value.index;
}
