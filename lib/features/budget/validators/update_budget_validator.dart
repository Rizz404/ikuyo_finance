class UpdateBudgetValidator {
  const UpdateBudgetValidator._();

  static String? ulid(String? value) {
    if (value == null || value.isEmpty) {
      return 'ULID wajib diisi';
    }
    return null;
  }

  static String? categoryUlid(String? value) {
    // * Optional for update
    return null;
  }

  static String? amountLimit(String? value) {
    if (value == null || value.isEmpty) {
      return null; // * Optional for update
    }
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null) {
      return 'Batas anggaran tidak valid';
    }
    if (parsed <= 0) {
      return 'Batas anggaran harus lebih dari 0';
    }
    return null;
  }

  static String? period(dynamic value) {
    // * Optional for update
    return null;
  }

  static String? startDate(DateTime? value) {
    // * Optional for update
    return null;
  }

  static String? endDate(DateTime? value) {
    // * Optional for update
    return null;
  }
}
