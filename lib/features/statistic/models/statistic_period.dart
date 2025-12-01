/// * Enum untuk tipe periode statistik
enum StatisticPeriodType { weekly, monthly, yearly, custom }

/// * Model untuk menyimpan data periode statistik
class StatisticPeriod {
  final StatisticPeriodType type;
  final DateTime startDate;
  final DateTime endDate;

  const StatisticPeriod({
    required this.type,
    required this.startDate,
    required this.endDate,
  });

  /// * Factory untuk periode mingguan
  factory StatisticPeriod.weekly({DateTime? referenceDate}) {
    final ref = referenceDate ?? DateTime.now();
    // * Mulai dari Senin minggu ini
    final startOfWeek = ref.subtract(Duration(days: ref.weekday - 1));
    final start = DateTime(
      startOfWeek.year,
      startOfWeek.month,
      startOfWeek.day,
    );
    final end = DateTime(start.year, start.month, start.day + 6, 23, 59, 59);

    return StatisticPeriod(
      type: StatisticPeriodType.weekly,
      startDate: start,
      endDate: end,
    );
  }

  /// * Factory untuk periode bulanan
  factory StatisticPeriod.monthly({DateTime? referenceDate}) {
    final ref = referenceDate ?? DateTime.now();
    final start = DateTime(ref.year, ref.month, 1);
    final end = DateTime(ref.year, ref.month + 1, 0, 23, 59, 59);

    return StatisticPeriod(
      type: StatisticPeriodType.monthly,
      startDate: start,
      endDate: end,
    );
  }

  /// * Factory untuk periode tahunan
  factory StatisticPeriod.yearly({DateTime? referenceDate}) {
    final ref = referenceDate ?? DateTime.now();
    final start = DateTime(ref.year, 1, 1);
    final end = DateTime(ref.year, 12, 31, 23, 59, 59);

    return StatisticPeriod(
      type: StatisticPeriodType.yearly,
      startDate: start,
      endDate: end,
    );
  }

  /// * Factory untuk periode kustom
  factory StatisticPeriod.custom({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return StatisticPeriod(
      type: StatisticPeriodType.custom,
      startDate: DateTime(startDate.year, startDate.month, startDate.day),
      endDate: DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59),
    );
  }

  /// * Pindah ke periode sebelumnya
  StatisticPeriod previous() {
    switch (type) {
      case StatisticPeriodType.weekly:
        final newStart = DateTime(
          startDate.year,
          startDate.month,
          startDate.day - 7,
        );
        return StatisticPeriod.weekly(referenceDate: newStart);
      case StatisticPeriodType.monthly:
        return StatisticPeriod.monthly(
          referenceDate: DateTime(startDate.year, startDate.month - 1, 1),
        );
      case StatisticPeriodType.yearly:
        return StatisticPeriod.yearly(
          referenceDate: DateTime(startDate.year - 1, 1, 1),
        );
      case StatisticPeriodType.custom:
        // * Hitung durasi dalam hari
        final durationDays = endDate.difference(startDate).inDays;
        final newEnd = DateTime(
          startDate.year,
          startDate.month,
          startDate.day - 1,
          23,
          59,
          59,
        );
        final newStart = DateTime(
          newEnd.year,
          newEnd.month,
          newEnd.day - durationDays,
        );
        return StatisticPeriod.custom(startDate: newStart, endDate: newEnd);
    }
  }

  /// * Pindah ke periode selanjutnya
  StatisticPeriod next() {
    switch (type) {
      case StatisticPeriodType.weekly:
        final newStart = DateTime(
          startDate.year,
          startDate.month,
          startDate.day + 7,
        );
        return StatisticPeriod.weekly(referenceDate: newStart);
      case StatisticPeriodType.monthly:
        return StatisticPeriod.monthly(
          referenceDate: DateTime(startDate.year, startDate.month + 1, 1),
        );
      case StatisticPeriodType.yearly:
        return StatisticPeriod.yearly(
          referenceDate: DateTime(startDate.year + 1, 1, 1),
        );
      case StatisticPeriodType.custom:
        // * Hitung durasi dalam hari
        final durationDays = endDate.difference(startDate).inDays;
        final newStart = DateTime(endDate.year, endDate.month, endDate.day + 1);
        final newEnd = DateTime(
          newStart.year,
          newStart.month,
          newStart.day + durationDays,
          23,
          59,
          59,
        );
        return StatisticPeriod.custom(startDate: newStart, endDate: newEnd);
    }
  }

  /// * Ubah tipe periode - reset ke current date untuk konsistensi
  StatisticPeriod changeType(StatisticPeriodType newType) {
    // * Selalu gunakan DateTime.now() saat ganti tipe untuk menghindari bug
    final now = DateTime.now();
    switch (newType) {
      case StatisticPeriodType.weekly:
        return StatisticPeriod.weekly(referenceDate: now);
      case StatisticPeriodType.monthly:
        return StatisticPeriod.monthly(referenceDate: now);
      case StatisticPeriodType.yearly:
        return StatisticPeriod.yearly(referenceDate: now);
      case StatisticPeriodType.custom:
        // * Untuk custom, keep existing dates
        return StatisticPeriod.custom(startDate: startDate, endDate: endDate);
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StatisticPeriod &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          startDate == other.startDate &&
          endDate == other.endDate;

  @override
  int get hashCode => type.hashCode ^ startDate.hashCode ^ endDate.hashCode;
}
