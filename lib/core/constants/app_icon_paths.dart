/// * Helper class untuk mendapatkan path icon berdasarkan kategori/asset
class AppIconPaths {
  AppIconPaths._();

  // * Base paths
  static const String _categoriesBase = 'assets/icons/categories/';
  static const String _assetsBase = 'assets/icons/assets/';

  // * Category icons - Income
  static const String salary = '${_categoriesBase}ic_salary.svg';
  static const String bonus = '${_categoriesBase}ic_bonus.svg';
  static const String investment = '${_categoriesBase}ic_investment.svg';
  static const String freelance = '${_categoriesBase}ic_freelance.svg';
  static const String gift = '${_categoriesBase}ic_gift.svg';
  static const String incomeOther = '${_categoriesBase}ic_income_other.svg';

  // * Category icons - Expense
  static const String food = '${_categoriesBase}ic_food.svg';
  static const String transport = '${_categoriesBase}ic_transport.svg';
  static const String shopping = '${_categoriesBase}ic_shopping.svg';
  static const String entertainment = '${_categoriesBase}ic_entertainment.svg';
  static const String health = '${_categoriesBase}ic_health.svg';
  static const String education = '${_categoriesBase}ic_education.svg';
  static const String bill = '${_categoriesBase}ic_bill.svg';
  static const String household = '${_categoriesBase}ic_household.svg';
  static const String clothing = '${_categoriesBase}ic_clothing.svg';
  static const String sport = '${_categoriesBase}ic_sport.svg';
  static const String beauty = '${_categoriesBase}ic_beauty.svg';
  static const String expenseOther = '${_categoriesBase}ic_expense_other.svg';

  // * Asset icons
  static const String wallet = '${_assetsBase}ic_wallet.svg';
  static const String bank = '${_assetsBase}ic_bank.svg';
  static const String eWallet = '${_assetsBase}ic_ewallet.svg';

  /// * Get icon path from stored icon string
  static String? getIconPath(String? iconString) {
    if (iconString == null || iconString.isEmpty) return null;

    // * Jika sudah berupa path, return langsung
    if (iconString.startsWith('assets/')) return iconString;

    // * Map dari icon name ke path
    final iconMap = <String, String>{
      // Income
      'salary': salary,
      'bonus': bonus,
      'investment': investment,
      'freelance': freelance,
      'gift': gift,
      'income_other': incomeOther,
      // Expense
      'food': food,
      'transport': transport,
      'shopping': shopping,
      'entertainment': entertainment,
      'health': health,
      'education': education,
      'bill': bill,
      'household': household,
      'clothing': clothing,
      'sport': sport,
      'beauty': beauty,
      'expense_other': expenseOther,
      // Assets
      'wallet': wallet,
      'bank': bank,
      'ewallet': eWallet,
    };

    return iconMap[iconString.toLowerCase()];
  }
}
