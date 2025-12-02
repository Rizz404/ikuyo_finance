import 'package:flutter/material.dart';
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
        icon: Icons.work_outline.codePoint.toString(),
        color: '#4CAF50',
      ),
      Category(
        name: 'Bonus',
        type: CategoryType.income.index,
        icon: Icons.card_giftcard.codePoint.toString(),
        color: '#8BC34A',
      ),
      Category(
        name: 'Investasi',
        type: CategoryType.income.index,
        icon: Icons.trending_up.codePoint.toString(),
        color: '#009688',
      ),
      Category(
        name: 'Freelance',
        type: CategoryType.income.index,
        icon: Icons.laptop_mac.codePoint.toString(),
        color: '#00BCD4',
      ),
      Category(
        name: 'Hadiah',
        type: CategoryType.income.index,
        icon: Icons.redeem.codePoint.toString(),
        color: '#E91E63',
      ),
      Category(
        name: 'Lainnya',
        type: CategoryType.income.index,
        icon: Icons.more_horiz.codePoint.toString(),
        color: '#9E9E9E',
      ),

      // * Expense categories
      Category(
        name: 'Makanan',
        type: CategoryType.expense.index,
        icon: Icons.restaurant.codePoint.toString(),
        color: '#FF5722',
      ),
      Category(
        name: 'Transportasi',
        type: CategoryType.expense.index,
        icon: Icons.directions_car.codePoint.toString(),
        color: '#795548',
      ),
      Category(
        name: 'Belanja',
        type: CategoryType.expense.index,
        icon: Icons.shopping_bag.codePoint.toString(),
        color: '#F44336',
      ),
      Category(
        name: 'Hiburan',
        type: CategoryType.expense.index,
        icon: Icons.movie.codePoint.toString(),
        color: '#9C27B0',
      ),
      Category(
        name: 'Kesehatan',
        type: CategoryType.expense.index,
        icon: Icons.local_hospital.codePoint.toString(),
        color: '#E91E63',
      ),
      Category(
        name: 'Pendidikan',
        type: CategoryType.expense.index,
        icon: Icons.school.codePoint.toString(),
        color: '#3F51B5',
      ),
      Category(
        name: 'Tagihan',
        type: CategoryType.expense.index,
        icon: Icons.receipt_long.codePoint.toString(),
        color: '#607D8B',
      ),
      Category(
        name: 'Rumah Tangga',
        type: CategoryType.expense.index,
        icon: Icons.home.codePoint.toString(),
        color: '#FF9800',
      ),
      Category(
        name: 'Pakaian',
        type: CategoryType.expense.index,
        icon: Icons.checkroom.codePoint.toString(),
        color: '#673AB7',
      ),
      Category(
        name: 'Olahraga',
        type: CategoryType.expense.index,
        icon: Icons.fitness_center.codePoint.toString(),
        color: '#4CAF50',
      ),
      Category(
        name: 'Kecantikan',
        type: CategoryType.expense.index,
        icon: Icons.face_retouching_natural.codePoint.toString(),
        color: '#E91E63',
      ),
      Category(
        name: 'Pengeluaran Lainnya',
        type: CategoryType.expense.index,
        icon: Icons.more_horiz.codePoint.toString(),
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
        icon: Icons.wallet.codePoint.toString(),
      ),
      Asset(
        name: 'SeaBank',
        type: AssetType.bank.index,
        balance: 0,
        icon: Icons.account_balance.codePoint.toString(),
      ),
      Asset(
        name: 'NeoBank',
        type: AssetType.bank.index,
        balance: 0,
        icon: Icons.account_balance.codePoint.toString(),
      ),
      Asset(
        name: 'BNI',
        type: AssetType.bank.index,
        balance: 0,
        icon: Icons.account_balance.codePoint.toString(),
      ),
      Asset(
        name: 'Mandiri',
        type: AssetType.bank.index,
        balance: 0,
        icon: Icons.account_balance.codePoint.toString(),
      ),
      Asset(
        name: 'Jago',
        type: AssetType.bank.index,
        balance: 0,
        icon: Icons.account_balance.codePoint.toString(),
      ),
      Asset(
        name: 'Dana',
        type: AssetType.eWallet.index,
        balance: 0,
        icon: Icons.account_balance_wallet.codePoint.toString(),
      ),
      Asset(
        name: 'Shopeepay',
        type: AssetType.eWallet.index,
        balance: 0,
        icon: Icons.account_balance_wallet.codePoint.toString(),
      ),
      Asset(
        name: 'GoPay',
        type: AssetType.eWallet.index,
        balance: 0,
        icon: Icons.account_balance_wallet.codePoint.toString(),
      ),
    ];

    box.putMany(assets);
    this.logInfo('Seeded ${assets.length} assets');
  }
}
