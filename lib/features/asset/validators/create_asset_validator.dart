class CreateAssetValidator {
  const CreateAssetValidator._();

  static String? name(String? value) {
    if (value == null || value.isEmpty) {
      return 'Nama aset wajib diisi';
    }
    if (value.length < 2) {
      return 'Nama minimal 2 karakter';
    }
    if (value.length > 50) {
      return 'Nama maksimal 50 karakter';
    }
    return null;
  }

  static String? type(dynamic value) {
    if (value == null) {
      return 'Tipe aset wajib dipilih';
    }
    return null;
  }

  static String? balance(String? value) {
    if (value == null || value.isEmpty) {
      return null; // * Balance is optional, defaults to 0
    }
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null) {
      return 'Saldo tidak valid';
    }
    if (parsed < 0) {
      return 'Saldo tidak boleh negatif';
    }
    return null;
  }

  static String? icon(String? value) {
    // * Icon is optional
    return null;
  }
}
