/// Describes a category/section within a module's notifications.
///
/// E.g. Finance module has sections: Bills, Debts, Budgets, Savings Goals.
/// Each section groups related notification types.
class HubNotificationSection {
  /// Unique section ID scoped to the module, e.g. `'bills'`, `'debts'`.
  final String id;

  /// Human-readable section name, e.g. `'Bills & Subscriptions'`.
  final String displayName;

  /// Optional description.
  final String description;

  /// Material icon code point for the section.
  final int iconCodePoint;

  /// Icon font family (defaults to MaterialIcons).
  final String iconFontFamily;

  /// Icon font package.
  final String? iconFontPackage;

  /// Section accent color value (ARGB).
  final int colorValue;

  const HubNotificationSection({
    required this.id,
    required this.displayName,
    this.description = '',
    required this.iconCodePoint,
    this.iconFontFamily = 'MaterialIcons',
    this.iconFontPackage,
    required this.colorValue,
  });
}
