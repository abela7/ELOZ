import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../services/finance_settings_service.dart';
import '../../utils/currency_utils.dart';

part 'account.g.dart';

/// Account type enum
enum AccountType {
  cash, // Physical cash
  bank, // Bank account
  card, // Credit/debit card
  mobileMoney, // Mobile money (M-Pesa, etc.)
  investment, // Investment account
  loan, // Loan account
  other, // Other type
}

/// Account/Wallet model with Hive persistence
/// Represents a financial account where money is stored or transferred
@HiveType(typeId: 23)
class Account extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? description;

  @HiveField(3)
  String type; // 'cash', 'bank', 'card', 'mobileMoney', 'investment', 'loan', 'other'

  @HiveField(4, defaultValue: 0.0)
  double balance; // Current balance

  @HiveField(5, defaultValue: 'ETB')
  String currency; // Currency code (e.g., 'ETB', 'USD')

  @HiveField(6)
  int? iconCodePoint;

  @HiveField(7)
  String? iconFontFamily;

  @HiveField(8)
  String? iconFontPackage;

  @HiveField(9, defaultValue: 0xFF4CAF50)
  int colorValue;

  @HiveField(10)
  DateTime createdAt;

  @HiveField(11, defaultValue: true)
  bool isActive; // Whether account is active

  @HiveField(12, defaultValue: true)
  bool includeInTotal; // Whether to include in total balance calculations

  @HiveField(13, defaultValue: 0)
  int sortOrder; // For custom ordering

  @HiveField(14)
  String? bankName; // For bank accounts

  @HiveField(15)
  String? accountNumber; // For bank/card accounts

  @HiveField(16)
  double? creditLimit; // For credit card accounts

  @HiveField(17)
  String? notes;

  @HiveField(18)
  DateTime? lastSyncDate; // Last time balance was synced/verified

  @HiveField(19, defaultValue: false)
  bool isDefault; // Whether this is the default account for transactions

  @HiveField(20, defaultValue: 0.0)
  double initialBalance; // The starting balance when account was created (for recalculation)

  Account({
    String? id,
    required this.name,
    this.description,
    this.type = 'cash',
    double balance = 0.0,
    this.currency = FinanceSettingsService.fallbackCurrency,
    this.iconCodePoint,
    this.iconFontFamily,
    this.iconFontPackage,
    int? colorValue,
    DateTime? createdAt,
    this.isActive = true,
    this.includeInTotal = true,
    this.sortOrder = 0,
    this.bankName,
    this.accountNumber,
    this.creditLimit,
    this.notes,
    this.lastSyncDate,
    this.isDefault = false,
    double? initialBalance,
    IconData? icon,
  }) : id = id ?? const Uuid().v4(),
       balance = balance,
       initialBalance = initialBalance ?? balance, // Store starting balance
       colorValue = colorValue ?? Colors.blue.value,
       createdAt = createdAt ?? DateTime.now() {
    // Set icon fields from IconData if provided
    if (icon != null) {
      this.iconCodePoint = icon.codePoint;
      this.iconFontFamily = icon.fontFamily;
      this.iconFontPackage = icon.fontPackage;
    }
  }

  /// Get IconData from stored code point
  IconData? get icon {
    if (iconCodePoint == null) return null;
    return IconData(
      iconCodePoint!,
      fontFamily: iconFontFamily ?? 'MaterialIcons',
      fontPackage: iconFontPackage,
    );
  }

  /// Set IconData by storing code point
  set icon(IconData? value) {
    iconCodePoint = value?.codePoint;
    iconFontFamily = value?.fontFamily;
    iconFontPackage = value?.fontPackage;
  }

  /// Get Color from stored value
  Color get color => Color(colorValue);

  /// Set Color by storing value
  set color(Color value) {
    colorValue = value.value;
  }

  /// Get account type enum
  AccountType get accountType {
    switch (type) {
      case 'bank':
        return AccountType.bank;
      case 'card':
        return AccountType.card;
      case 'mobileMoney':
        return AccountType.mobileMoney;
      case 'investment':
        return AccountType.investment;
      case 'loan':
        return AccountType.loan;
      case 'other':
        return AccountType.other;
      case 'cash':
      default:
        return AccountType.cash;
    }
  }

  /// Set account type from enum
  set accountType(AccountType value) {
    type = value.name;
  }

  /// Get formatted balance with currency
  String get formattedBalance {
    final currencySymbol = CurrencyUtils.getCurrencySymbol(currency);
    return '$currencySymbol${balance.toStringAsFixed(2)}';
  }

  /// Check if account is a credit card
  bool get isCreditCard =>
      accountType == AccountType.card && creditLimit != null;

  /// Get available credit (for credit cards)
  double get availableCredit {
    if (!isCreditCard || creditLimit == null) return 0;
    return creditLimit! + balance; // Balance is negative for credit cards
  }

  /// Get used credit percentage (for credit cards)
  double get creditUsagePercentage {
    if (!isCreditCard || creditLimit == null || creditLimit == 0) return 0;
    final used = creditLimit! + balance;
    return (used / creditLimit! * 100).clamp(0, 100);
  }

  /// Check if account is a debt account
  bool get isDebtAccount =>
      accountType == AccountType.loan || (isCreditCard && balance < 0);

  /// Get account type icon
  IconData get typeIcon {
    switch (accountType) {
      case AccountType.cash:
        return Icons.payments_rounded;
      case AccountType.bank:
        return Icons.account_balance_rounded;
      case AccountType.card:
        return Icons.credit_card_rounded;
      case AccountType.mobileMoney:
        return Icons.phone_android_rounded;
      case AccountType.investment:
        return Icons.trending_up_rounded;
      case AccountType.loan:
        return Icons.receipt_long_rounded;
      case AccountType.other:
        return Icons.account_balance_wallet_rounded;
    }
  }

  /// Get account type display name
  String get typeDisplayName {
    switch (accountType) {
      case AccountType.cash:
        return 'Cash';
      case AccountType.bank:
        return 'Bank Account';
      case AccountType.card:
        return 'Card';
      case AccountType.mobileMoney:
        return 'Mobile Money';
      case AccountType.investment:
        return 'Investment';
      case AccountType.loan:
        return 'Loan';
      case AccountType.other:
        return 'Other';
    }
  }

  /// Update balance by adding amount (positive for income, negative for expense)
  void updateBalance(double amount) {
    balance += amount;
    lastSyncDate = DateTime.now();
  }

  /// Create a copy with updated fields
  Account copyWith({
    String? id,
    String? name,
    String? description,
    String? type,
    double? balance,
    String? currency,
    int? iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
    int? colorValue,
    DateTime? createdAt,
    bool? isActive,
    bool? includeInTotal,
    int? sortOrder,
    String? bankName,
    String? accountNumber,
    double? creditLimit,
    String? notes,
    DateTime? lastSyncDate,
    bool? isDefault,
    double? initialBalance,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
      iconFontPackage: iconFontPackage ?? this.iconFontPackage,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      includeInTotal: includeInTotal ?? this.includeInTotal,
      sortOrder: sortOrder ?? this.sortOrder,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      creditLimit: creditLimit ?? this.creditLimit,
      notes: notes ?? this.notes,
      lastSyncDate: lastSyncDate ?? this.lastSyncDate,
      isDefault: isDefault ?? this.isDefault,
      initialBalance: initialBalance ?? this.initialBalance,
    );
  }
}
