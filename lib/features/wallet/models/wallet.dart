import 'package:objectbox/objectbox.dart';
import 'package:ulid/ulid.dart';

enum WalletType { cash, bank, ewallet, investment }

@Entity()
class Wallet {
  @Id()
  int id;

  @Unique()
  String ulid;

  String name;
  int type; // * Stored as int, mapped to WalletType enum
  double balance;
  String? icon;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  @Property(type: PropertyType.date)
  DateTime updatedAt;

  Wallet({
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
  WalletType get walletType => WalletType.values[type];
  set walletType(WalletType value) => type = value.index;
}
