class CreateBudgetValidator {
  const CreateBudgetValidator._();

  static String? categoryUlid(String? value) {
    if (value == null || value.isEmpty) {
      return 'Kategori wajib dipilih';
    }
    return null;
  }

  static String? amountLimit(String? value) {
    if (value == null || value.isEmpty) {
      return 'Batas anggaran wajib diisi';
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
    if (value == null) {
      return 'Periode wajib dipilih';
    }
    return null;
  }

  static String? startDate(DateTime? value) {
    // * Optional for non-custom period
    return null;
  }

  static String? endDate(DateTime? value) {
    // * Optional for non-custom period
    return null;
  }
}
