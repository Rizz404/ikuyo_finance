import 'package:flutter/material.dart';

/// * Central registry for app icons - enables tree-shaking by using const Icons
/// * Store icon keys (e.g., 'wallet') in DB instead of codePoints
class IconRegistry {
  IconRegistry._();

  /// * Map of icon key to const IconData
  static const Map<String, IconData> _icons = {
    // * Asset icons
    'wallet': Icons.wallet,
    'account_balance': Icons.account_balance,
    'account_balance_wallet': Icons.account_balance_wallet,
    'credit_card': Icons.credit_card,
    'savings': Icons.savings,
    'attach_money': Icons.attach_money,
    'money': Icons.money,
    'currency_exchange': Icons.currency_exchange,
    'payments': Icons.payments,

    // * Category - Income
    'work_outline': Icons.work_outline,
    'card_giftcard': Icons.card_giftcard,
    'trending_up': Icons.trending_up,
    'laptop_mac': Icons.laptop_mac,
    'redeem': Icons.redeem,
    'more_horiz': Icons.more_horiz,
    'business_center': Icons.business_center,
    'monetization_on': Icons.monetization_on,

    // * Category - Expense
    'restaurant': Icons.restaurant,
    'directions_car': Icons.directions_car,
    'shopping_bag': Icons.shopping_bag,
    'movie': Icons.movie,
    'local_hospital': Icons.local_hospital,
    'school': Icons.school,
    'receipt_long': Icons.receipt_long,
    'home': Icons.home,
    'checkroom': Icons.checkroom,
    'fitness_center': Icons.fitness_center,
    'face_retouching_natural': Icons.face_retouching_natural,

    // * Common icons
    'category': Icons.category,
    'category_outlined': Icons.category_outlined,
    'image_outlined': Icons.image_outlined,
    'broken_image_outlined': Icons.broken_image_outlined,
    'shopping_cart': Icons.shopping_cart,
    'local_grocery_store': Icons.local_grocery_store,
    'fastfood': Icons.fastfood,
    'coffee': Icons.coffee,
    'local_cafe': Icons.local_cafe,
    'local_bar': Icons.local_bar,
    'flight': Icons.flight,
    'train': Icons.train,
    'subway': Icons.subway,
    'directions_bus': Icons.directions_bus,
    'two_wheeler': Icons.two_wheeler,
    'electric_scooter': Icons.electric_scooter,
    'sports_esports': Icons.sports_esports,
    'gamepad': Icons.gamepad,
    'headphones': Icons.headphones,
    'music_note': Icons.music_note,
    'theaters': Icons.theaters,
    'sports_soccer': Icons.sports_soccer,
    'sports_basketball': Icons.sports_basketball,
    'pool': Icons.pool,
    'spa': Icons.spa,
    'medical_services': Icons.medical_services,
    'medication': Icons.medication,
    'vaccines': Icons.vaccines,
    'phone_android': Icons.phone_android,
    'computer': Icons.computer,
    'devices': Icons.devices,
    'wifi': Icons.wifi,
    'electric_bolt': Icons.electric_bolt,
    'water_drop': Icons.water_drop,
    'local_gas_station': Icons.local_gas_station,
    'build': Icons.build,
    'handyman': Icons.handyman,
    'pets': Icons.pets,
    'child_care': Icons.child_care,
    'elderly': Icons.elderly,
    'celebration': Icons.celebration,
    'cake': Icons.cake,
    'card_travel': Icons.card_travel,
    'beach_access': Icons.beach_access,
    'photo_camera': Icons.photo_camera,
    'videocam': Icons.videocam,
    'book': Icons.book,
    'menu_book': Icons.menu_book,
    'newspaper': Icons.newspaper,
    'store': Icons.store,
    'storefront': Icons.storefront,
    'volunteer_activism': Icons.volunteer_activism,
    'favorite': Icons.favorite,
    'star': Icons.star,
  };

  /// * Get IconData from key, returns null if not found
  static IconData? getIcon(String? key) {
    if (key == null || key.isEmpty) return null;
    return _icons[key];
  }

  /// * Get IconData with fallback
  static IconData getIconOrDefault(
    String? key, {
    IconData fallback = Icons.category_outlined,
  }) {
    return getIcon(key) ?? fallback;
  }

  /// * Check if key exists in registry
  static bool hasIcon(String? key) {
    if (key == null || key.isEmpty) return false;
    return _icons.containsKey(key);
  }

  /// * Check if string is an icon key (not a file path)
  static bool isIconKey(String? value) {
    if (value == null || value.isEmpty) return false;
    // * File paths contain slashes or backslashes
    if (value.contains('/') || value.contains('\\')) return false;
    // * Old codePoint format (pure numbers)
    if (int.tryParse(value) != null) return false;
    return true;
  }

  /// * Get all available icon keys (for icon picker)
  static List<String> get availableKeys => _icons.keys.toList();

  /// * Get all icons as entries (for icon picker UI)
  static List<MapEntry<String, IconData>> get allIcons =>
      _icons.entries.toList();
}
