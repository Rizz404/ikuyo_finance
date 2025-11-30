class UpdateCategoryValidator {
  const UpdateCategoryValidator._();

  static String? ulid(String? value) {
    if (value == null || value.isEmpty) {
      return 'ULID wajib diisi';
    }
    return null;
  }

  static String? name(String? value) {
    if (value == null || value.isEmpty) {
      return null; // * Optional for update
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
    // * Optional for update
    return null;
  }

  static String? icon(String? value) {
    // * Optional for update
    return null;
  }

  static String? color(String? value) {
    // * Optional for update
    return null;
  }

  static String? parentUlid(String? value) {
    // * Optional for update
    return null;
  }
}
