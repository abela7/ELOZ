/// Utility class for currency operations - NO HARDCODED VALUES in displays
/// All currency data is centralized here for consistency
class CurrencyUtils {
  /// Currency data map - single source of truth
  static const Map<String, Map<String, String>> _currencyData = {
    'ETB': {'symbol': 'Br', 'name': 'Ethiopian Birr'},
    'USD': {'symbol': '\$', 'name': 'US Dollar'},
    'EUR': {'symbol': '€', 'name': 'Euro'},
    'GBP': {'symbol': '£', 'name': 'British Pound'},
    'JPY': {'symbol': '¥', 'name': 'Japanese Yen'},
    'CNY': {'symbol': '¥', 'name': 'Chinese Yuan'},
    'INR': {'symbol': '₹', 'name': 'Indian Rupee'},
    'AUD': {'symbol': 'A\$', 'name': 'Australian Dollar'},
    'CAD': {'symbol': 'C\$', 'name': 'Canadian Dollar'},
    'CHF': {'symbol': 'Fr', 'name': 'Swiss Franc'},
    'KRW': {'symbol': '₩', 'name': 'South Korean Won'},
    'BRL': {'symbol': 'R\$', 'name': 'Brazilian Real'},
    'MXN': {'symbol': 'Mex\$', 'name': 'Mexican Peso'},
    'ZAR': {'symbol': 'R', 'name': 'South African Rand'},
    'AED': {'symbol': 'د.إ', 'name': 'UAE Dirham'},
    'SAR': {'symbol': '﷼', 'name': 'Saudi Riyal'},
    'TRY': {'symbol': '₺', 'name': 'Turkish Lira'},
    'RUB': {'symbol': '₽', 'name': 'Russian Ruble'},
    'PLN': {'symbol': 'zł', 'name': 'Polish Zloty'},
    'SEK': {'symbol': 'kr', 'name': 'Swedish Krona'},
    'NOK': {'symbol': 'kr', 'name': 'Norwegian Krone'},
    'DKK': {'symbol': 'kr', 'name': 'Danish Krone'},
    'SGD': {'symbol': 'S\$', 'name': 'Singapore Dollar'},
    'HKD': {'symbol': 'HK\$', 'name': 'Hong Kong Dollar'},
    'THB': {'symbol': '฿', 'name': 'Thai Baht'},
    'MYR': {'symbol': 'RM', 'name': 'Malaysian Ringgit'},
    'IDR': {'symbol': 'Rp', 'name': 'Indonesian Rupiah'},
    'PHP': {'symbol': '₱', 'name': 'Philippine Peso'},
    'VND': {'symbol': '₫', 'name': 'Vietnamese Dong'},
    'PKR': {'symbol': '₨', 'name': 'Pakistani Rupee'},
    'BDT': {'symbol': '৳', 'name': 'Bangladeshi Taka'},
    'NGN': {'symbol': '₦', 'name': 'Nigerian Naira'},
    'EGP': {'symbol': 'E£', 'name': 'Egyptian Pound'},
    'KES': {'symbol': 'KSh', 'name': 'Kenyan Shilling'},
    'NZD': {'symbol': 'NZ\$', 'name': 'New Zealand Dollar'},
    'CZK': {'symbol': 'Kč', 'name': 'Czech Koruna'},
    'HUF': {'symbol': 'Ft', 'name': 'Hungarian Forint'},
    'ILS': {'symbol': '₪', 'name': 'Israeli Shekel'},
  };

  /// Convert currency code to symbol
  static String getCurrencySymbol(String currencyCode) {
    final data = _currencyData[currencyCode.toUpperCase()];
    return data?['symbol'] ?? currencyCode;
  }

  /// Get currency name from code
  static String getCurrencyName(String currencyCode) {
    final data = _currencyData[currencyCode.toUpperCase()];
    return data?['name'] ?? currencyCode;
  }

  /// Format amount with currency symbol
  static String formatAmount(double amount, String currencyCode) {
    return '${getCurrencySymbol(currencyCode)}${amount.toStringAsFixed(2)}';
  }

  /// Format amount with currency symbol and name
  static String formatAmountFull(double amount, String currencyCode) {
    return '${getCurrencySymbol(currencyCode)}${amount.toStringAsFixed(2)} $currencyCode';
  }

  /// Get all available currencies
  static List<String> get allCurrencyCodes => _currencyData.keys.toList();
}
