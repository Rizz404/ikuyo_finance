import 'package:objectbox/objectbox.dart';

/// Penanda mata uang tempat semua nominal di database disimpan.
/// Ditulis dalam transaksi yang sama dengan konversi nominal, sehingga
/// menjadi sumber kebenaran; preferensi hanya cermin yang diselaraskan.
@Entity()
class CurrencyMarker {
  @Id()
  int id;

  String currency;

  @Property(type: PropertyType.date)
  DateTime updatedAt;

  CurrencyMarker({this.id = 0, required this.currency, DateTime? updatedAt})
    : updatedAt = updatedAt ?? DateTime.now();
}
