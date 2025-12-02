import 'package:ikuyo_finance/core/storage/objectbox_storage.dart';
import 'package:ikuyo_finance/core/utils/logger.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';

/// Seeder untuk data awal aplikasi
/// Hanya dijalankan sekali saat pertama kali install
class DatabaseSeeder {
  final ObjectBoxStorage _storage;

  DatabaseSeeder(this._storage);

  /// Seed semua data default
  Future<void> seedAll() async {
    await _seedCategories();
    await _seedAssets();
  }

  /// Seed kategori default
  Future<void> _seedCategories() async {
    final box = _storage.box<Category>();

    // * Skip jika sudah ada data
    if (box.count() > 0) {
      this.logInfo('Categories already seeded, skipping...');
      return;
    }

    this.logInfo('Seeding default categories...');

    final categories = [
      // * Income categories
      Category(
        name: 'Gaji',
        type: CategoryType.income.index,
        icon: 'work_outline',
        color: '#4CAF50',
      ),
      Category(
        name: 'Bonus',
        type: CategoryType.income.index,
        icon: 'card_giftcard',
        color: '#8BC34A',
      ),
      Category(
        name: 'Investasi',
        type: CategoryType.income.index,
        icon: 'trending_up',
        color: '#009688',
      ),
      Category(
        name: 'Freelance',
        type: CategoryType.income.index,
        icon: 'laptop_mac',
        color: '#00BCD4',
      ),
      Category(
        name: 'Hadiah',
        type: CategoryType.income.index,
        icon: 'redeem',
        color: '#E91E63',
      ),
      Category(
        name: 'Lainnya',
        type: CategoryType.income.index,
        icon: 'more_horiz',
        color: '#9E9E9E',
      ),

      // * Expense categories
      Category(
        name: 'Makanan',
        type: CategoryType.expense.index,
        icon: 'restaurant',
        color: '#FF5722',
      ),
      Category(
        name: 'Transportasi',
        type: CategoryType.expense.index,
        icon: 'directions_car',
        color: '#795548',
      ),
      Category(
        name: 'Belanja',
        type: CategoryType.expense.index,
        icon: 'shopping_bag',
        color: '#F44336',
      ),
      Category(
        name: 'Hiburan',
        type: CategoryType.expense.index,
        icon: 'movie',
        color: '#9C27B0',
      ),
      Category(
        name: 'Kesehatan',
        type: CategoryType.expense.index,
        icon: 'local_hospital',
        color: '#E91E63',
      ),
      Category(
        name: 'Pendidikan',
        type: CategoryType.expense.index,
        icon: 'school',
        color: '#3F51B5',
      ),
      Category(
        name: 'Tagihan',
        type: CategoryType.expense.index,
        icon: 'receipt_long',
        color: '#607D8B',
      ),
      Category(
        name: 'Rumah Tangga',
        type: CategoryType.expense.index,
        icon: 'home',
        color: '#FF9800',
      ),
      Category(
        name: 'Pakaian',
        type: CategoryType.expense.index,
        icon: 'checkroom',
        color: '#673AB7',
      ),
      Category(
        name: 'Olahraga',
        type: CategoryType.expense.index,
        icon: 'fitness_center',
        color: '#4CAF50',
      ),
      Category(
        name: 'Kecantikan',
        type: CategoryType.expense.index,
        icon: 'face_retouching_natural',
        color: '#E91E63',
      ),
      Category(
        name: 'Pengeluaran Lainnya',
        type: CategoryType.expense.index,
        icon: 'more_horiz',
        color: '#9E9E9E',
      ),
    ];

    box.putMany(categories);
    this.logInfo('Seeded ${categories.length} categories');
  }

  /// Seed asset default
  Future<void> _seedAssets() async {
    final box = _storage.box<Asset>();

    // * Skip jika sudah ada data
    if (box.count() > 0) {
      this.logInfo('Assets already seeded, skipping...');
      return;
    }

    this.logInfo('Seeding default assets...');

    final assets = [
      Asset(
        name: 'Dompet',
        type: AssetType.cash.index,
        balance: 0,
        icon: 'wallet',
      ),
      Asset(
        name: 'SeaBank',
        type: AssetType.bank.index,
        balance: 0,
        icon: 'account_balance',
      ),
      Asset(
        name: 'NeoBank',
        type: AssetType.bank.index,
        balance: 0,
        icon: 'account_balance',
      ),
      Asset(
        name: 'BNI',
        type: AssetType.bank.index,
        balance: 0,
        icon: 'account_balance',
      ),
      Asset(
        name: 'Mandiri',
        type: AssetType.bank.index,
        balance: 0,
        icon: 'account_balance',
      ),
      Asset(
        name: 'Jago',
        type: AssetType.bank.index,
        balance: 0,
        icon: 'account_balance',
      ),
      Asset(
        name: 'Dana',
        type: AssetType.eWallet.index,
        balance: 0,
        icon: 'account_balance_wallet',
      ),
      Asset(
        name: 'Shopeepay',
        type: AssetType.eWallet.index,
        balance: 0,
        icon: 'account_balance_wallet',
      ),
      Asset(
        name: 'GoPay',
        type: AssetType.eWallet.index,
        balance: 0,
        icon: 'account_balance_wallet',
      ),
    ];

    box.putMany(assets);
    this.logInfo('Seeded ${assets.length} assets');
  }
}
