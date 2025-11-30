class CreateCategoryValidator {
  const CreateCategoryValidator._();

  static String? name(String? value) {
    if (value == null || value.isEmpty) {
      return 'Nama kategori wajib diisi';
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
      return 'Tipe kategori wajib dipilih';
    }
    return null;
  }

  static String? icon(String? value) {
    // * Icon is optional
    return null;
  }

  static String? color(String? value) {
    // * Color is optional
    return null;
  }

  static String? parentUlid(String? value) {
    // * Parent is optional
    return null;
  }
}
