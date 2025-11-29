class CreateTransactionValidator {
  const CreateTransactionValidator._();

  static String? amount(String? value) {
    if (value == null || value.isEmpty) {
      return 'Jumlah wajib diisi';
    }
    final amount = double.tryParse(value.replaceAll('.', ''));
    if (amount == null || amount <= 0) {
      return 'Jumlah harus lebih dari 0';
    }
    return null;
  }

  static String? assetUlid(String? value) {
    if (value == null || value.isEmpty) {
      return 'Asset wajib dipilih';
    }
    return null;
  }

  static String? categoryUlid(String? value) {
    // * Category is optional for transaction
    return null;
  }

  static String? transactionDate(DateTime? value) {
    // * Transaction date is optional, defaults to now
    return null;
  }

  static String? description(String? value) {
    if (value != null && value.length > 500) {
      return 'Deskripsi maksimal 500 karakter';
    }
    return null;
  }

  static String? imagePath(String? value) {
    // * Image path is optional
    return null;
  }
}
