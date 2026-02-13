import 'package:flutter/material.dart';
import '../models/transaction_category.dart';
import '../repositories/transaction_category_repository.dart';

/// Service to initialize default system transaction categories
class DefaultCategoriesService {
  final TransactionCategoryRepository _repository;

  DefaultCategoriesService(this._repository);

  /// Initialize default categories if none exist
  /// Only runs on first install - after that, the user has full control
  Future<void> initializeDefaultCategories() async {
    final existing = await _repository.getAllCategories();

    // If categories already exist, do nothing - user has full control
    if (existing.isNotEmpty) {
      return;
    }

    // Income Categories
    final incomeCategories = [
      TransactionCategory(
        name: 'Salary',
        description: 'Monthly salary and wages',
        iconCodePoint: Icons.business_center_rounded.codePoint,
        iconFontFamily: 'MaterialIcons',
        colorValue: const Color(0xFF4CAF50).value,
        type: 'income',
        isSystemCategory: true,
        sortOrder: 1,
      ),
      TransactionCategory(
        name: 'Freelance',
        description: 'Freelance work and side projects',
        iconCodePoint: Icons.computer_rounded.codePoint,
        iconFontFamily: 'MaterialIcons',
        colorValue: const Color(0xFF2196F3).value,
        type: 'income',
        isSystemCategory: true,
        sortOrder: 2,
      ),
      TransactionCategory(
        name: 'Investment',
        description: 'Returns from investments',
        iconCodePoint: Icons.trending_up_rounded.codePoint,
        iconFontFamily: 'MaterialIcons',
        colorValue: const Color(0xFF00BCD4).value,
        type: 'income',
        isSystemCategory: true,
        sortOrder: 3,
      ),
      TransactionCategory(
        name: 'Gift',
        description: 'Money received as gifts',
        iconCodePoint: Icons.card_giftcard_rounded.codePoint,
        iconFontFamily: 'MaterialIcons',
        colorValue: const Color(0xFFE91E63).value,
        type: 'income',
        isSystemCategory: true,
        sortOrder: 4,
      ),
      TransactionCategory(
        name: 'Refund',
        description: 'Refunds and reimbursements',
        iconCodePoint: Icons.replay_rounded.codePoint,
        iconFontFamily: 'MaterialIcons',
        colorValue: const Color(0xFF9C27B0).value,
        type: 'income',
        isSystemCategory: true,
        sortOrder: 5,
      ),
    ];

    // Expense Categories - using fixed IDs for expense screen integration
    final expenseCategories = [
      TransactionCategory(
        id: 'cat_shopping',
        name: 'Shopping & Groceries',
        description: 'Daily purchases and essentials',
        iconCodePoint: Icons.shopping_cart_rounded.codePoint,
        iconFontFamily: 'MaterialIcons',
        colorValue: const Color(0xFF4CAF50).value,
        type: 'expense',
        isSystemCategory: true,
        sortOrder: 10,
      ),
      TransactionCategory(
        id: 'cat_food',
        name: 'Food & Dining',
        description: 'Groceries, restaurants, and food delivery',
        iconCodePoint: Icons.restaurant_rounded.codePoint,
        iconFontFamily: 'MaterialIcons',
        colorValue: const Color(0xFFFF9800).value,
        type: 'expense',
        isSystemCategory: true,
        sortOrder: 11,
      ),
      TransactionCategory(
        id: 'cat_transport',
        name: 'Transportation',
        description: 'Fuel, public transport, taxi, car maintenance',
        iconCodePoint: Icons.directions_car_rounded.codePoint,
        iconFontFamily: 'MaterialIcons',
        colorValue: const Color(0xFF2196F3).value,
        type: 'expense',
        isSystemCategory: true,
        sortOrder: 12,
      ),
      TransactionCategory(
        id: 'cat_entertainment',
        name: 'Entertainment',
        description: 'Movies, games, hobbies, and fun activities',
        iconCodePoint: Icons.movie_rounded.codePoint,
        iconFontFamily: 'MaterialIcons',
        colorValue: const Color(0xFF9C27B0).value,
        type: 'expense',
        isSystemCategory: true,
        sortOrder: 13,
      ),
      TransactionCategory(
        id: 'cat_social',
        name: 'Social Life',
        description: 'Friends, outings, and social gatherings',
        iconCodePoint: Icons.people_rounded.codePoint,
        iconFontFamily: 'MaterialIcons',
        colorValue: const Color(0xFFE91E63).value,
        type: 'expense',
        isSystemCategory: true,
        sortOrder: 14,
      ),
      TransactionCategory(
        id: 'cat_church',
        name: 'Church & Spiritual',
        description: 'Tithes, offerings, and spiritual donations',
        iconCodePoint: Icons.church_rounded.codePoint,
        iconFontFamily: 'MaterialIcons',
        colorValue: const Color(0xFF3F51B5).value,
        type: 'expense',
        isSystemCategory: true,
        sortOrder: 15,
      ),
      TransactionCategory(
        id: 'cat_family',
        name: 'Family',
        description: 'Family expenses and support',
        iconCodePoint: Icons.family_restroom_rounded.codePoint,
        iconFontFamily: 'MaterialIcons',
        colorValue: const Color(0xFF009688).value,
        type: 'expense',
        isSystemCategory: true,
        sortOrder: 16,
      ),
      TransactionCategory(
        id: 'cat_health',
        name: 'Health & Medical',
        description: 'Medical bills, pharmacy, health insurance',
        iconCodePoint: Icons.medical_services_rounded.codePoint,
        iconFontFamily: 'MaterialIcons',
        colorValue: const Color(0xFFF44336).value,
        type: 'expense',
        isSystemCategory: true,
        sortOrder: 17,
      ),
      TransactionCategory(
        id: 'cat_education',
        name: 'Education',
        description: 'Tuition, books, courses, and learning materials',
        iconCodePoint: Icons.school_rounded.codePoint,
        iconFontFamily: 'MaterialIcons',
        colorValue: const Color(0xFFFFC107).value,
        type: 'expense',
        isSystemCategory: true,
        sortOrder: 18,
      ),
      TransactionCategory(
        id: 'cat_personal',
        name: 'Personal Care',
        description: 'Haircut, spa, gym, personal grooming',
        iconCodePoint: Icons.spa_rounded.codePoint,
        iconFontFamily: 'MaterialIcons',
        colorValue: const Color(0xFF00BCD4).value,
        type: 'expense',
        isSystemCategory: true,
        sortOrder: 19,
      ),
      TransactionCategory(
        name: 'Bills & Utilities',
        description: 'Electricity, water, internet, phone bills',
        iconCodePoint: Icons.receipt_long_rounded.codePoint,
        iconFontFamily: 'MaterialIcons',
        colorValue: const Color(0xFF607D8B).value,
        type: 'expense',
        isSystemCategory: true,
        sortOrder: 20,
      ),
      TransactionCategory(
        name: 'Rent',
        description: 'Monthly rent or mortgage payments',
        iconCodePoint: Icons.home_rounded.codePoint,
        iconFontFamily: 'MaterialIcons',
        colorValue: const Color(0xFF795548).value,
        type: 'expense',
        isSystemCategory: true,
        sortOrder: 21,
      ),
      TransactionCategory(
        name: 'Insurance',
        description: 'Life, health, car, and other insurance',
        iconCodePoint: Icons.shield_rounded.codePoint,
        iconFontFamily: 'MaterialIcons',
        colorValue: const Color(0xFF009688).value,
        type: 'expense',
        isSystemCategory: true,
        sortOrder: 22,
      ),
      TransactionCategory(
        name: 'Travel',
        description: 'Vacation, flights, hotels, and travel expenses',
        iconCodePoint: Icons.flight_takeoff_rounded.codePoint,
        iconFontFamily: 'MaterialIcons',
        colorValue: const Color(0xFF2196F3).value,
        type: 'expense',
        isSystemCategory: true,
        sortOrder: 23,
      ),
      TransactionCategory(
        name: 'Subscriptions',
        description: 'Netflix, Spotify, magazines, memberships',
        iconCodePoint: Icons.subscriptions_rounded.codePoint,
        iconFontFamily: 'MaterialIcons',
        colorValue: const Color(0xFF673AB7).value,
        type: 'expense',
        isSystemCategory: true,
        sortOrder: 24,
      ),
      TransactionCategory(
        name: 'Pets',
        description: 'Pet food, veterinary, pet supplies',
        iconCodePoint: Icons.pets_rounded.codePoint,
        iconFontFamily: 'MaterialIcons',
        colorValue: const Color(0xFF8BC34A).value,
        type: 'expense',
        isSystemCategory: true,
        sortOrder: 25,
      ),
      TransactionCategory(
        name: 'Charity',
        description: 'Donations and charitable giving',
        iconCodePoint: Icons.volunteer_activism_rounded.codePoint,
        iconFontFamily: 'MaterialIcons',
        colorValue: const Color(0xFFFF5722).value,
        type: 'expense',
        isSystemCategory: true,
        sortOrder: 26,
      ),
      TransactionCategory(
        name: 'Other',
        description: 'Miscellaneous expenses',
        iconCodePoint: Icons.more_horiz_rounded.codePoint,
        iconFontFamily: 'MaterialIcons',
        colorValue: const Color(0xFF9E9E9E).value,
        type: 'expense',
        isSystemCategory: true,
        sortOrder: 27,
      ),
    ];

    // Create all categories
    for (final category in [...incomeCategories, ...expenseCategories]) {
      await _repository.createCategory(category);
    }
  }

}
