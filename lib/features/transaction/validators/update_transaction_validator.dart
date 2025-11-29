class UpdateTransactionValidator {
  const UpdateTransactionValidator._();

  static String? ulid(String? value) {
    if (value == null || value.isEmpty) {
      return 'ULID wajib diisi';
    }
    return null;
  }

  static String? amount(String? value) {
    if (value == null || value.isEmpty) {
      return null; // * Optional for update
    }
    final amount = double.tryParse(value.replaceAll('.', ''));
    if (amount == null || amount <= 0) {
      return 'Jumlah harus lebih dari 0';
    }
    return null;
  }

  static String? assetUlid(String? value) {
    // * Optional for update
    return null;
  }

  static String? categoryUlid(String? value) {
    // * Optional for update
    return null;
  }

  static String? transactionDate(DateTime? value) {
    // * Optional for update
    return null;
  }

  static String? description(String? value) {
    if (value != null && value.length > 500) {
      return 'Deskripsi maksimal 500 karakter';
    }
    return null;
  }

  static String? imagePath(String? value) {
    // * Optional for update
    return null;
  }
}
