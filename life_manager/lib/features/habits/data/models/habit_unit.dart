import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'habit_unit.g.dart';

/// Model for habit measurement units
/// Allows users to create custom units for tracking numeric habits
@HiveType(typeId: 15)
class HabitUnit extends HiveObject {
  @HiveField(0)
  String id;

  /// Display name (e.g., "Hour", "Liter", "Page")
  @HiveField(1)
  String name;

  /// Short symbol (e.g., "hr", "L", "pg")
  @HiveField(2)
  String symbol;

  /// Plural name (e.g., "Hours", "Liters", "Pages")
  @HiveField(3)
  String pluralName;

  /// Category ID reference
  @HiveField(4)
  String categoryId;

  /// Whether this is a default/system unit
  @HiveField(5)
  bool isDefault;

  /// Icon code point for display
  @HiveField(6)
  int? iconCodePoint;

  @HiveField(7)
  String? iconFontFamily;

  @HiveField(8)
  String? iconFontPackage;

  @HiveField(9)
  DateTime createdAt;

  @HiveField(10)
  DateTime? updatedAt;

  /// For conversion between units (e.g., 60 min = 1 hour)
  /// Base unit in category has factor = 1
  @HiveField(11)
  double conversionFactor;

  /// Reference to base unit id for conversion
  @HiveField(12)
  String? baseUnitId;

  HabitUnit({
    String? id,
    required this.name,
    required this.symbol,
    String? pluralName,
    required this.categoryId,
    this.isDefault = false,
    this.iconCodePoint,
    this.iconFontFamily,
    this.iconFontPackage,
    DateTime? createdAt,
    this.updatedAt,
    this.conversionFactor = 1.0,
    this.baseUnitId,
  })  : id = id ?? const Uuid().v4(),
        pluralName = pluralName ?? '${name}s',
        createdAt = createdAt ?? DateTime.now();

  HabitUnit copyWith({
    String? id,
    String? name,
    String? symbol,
    String? pluralName,
    String? categoryId,
    bool? isDefault,
    int? iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? conversionFactor,
    String? baseUnitId,
  }) {
    return HabitUnit(
      id: id ?? this.id,
      name: name ?? this.name,
      symbol: symbol ?? this.symbol,
      pluralName: pluralName ?? this.pluralName,
      categoryId: categoryId ?? this.categoryId,
      isDefault: isDefault ?? this.isDefault,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
      iconFontPackage: iconFontPackage ?? this.iconFontPackage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      conversionFactor: conversionFactor ?? this.conversionFactor,
      baseUnitId: baseUnitId ?? this.baseUnitId,
    );
  }

  /// Format a value with this unit
  String format(double value) {
    final unitName = value == 1 ? name : pluralName;
    if (value == value.toInt()) {
      return '${value.toInt()} $unitName';
    }
    return '${value.toStringAsFixed(1)} $unitName';
  }

  /// Format with symbol (compact)
  String formatCompact(double value) {
    if (value == value.toInt()) {
      return '${value.toInt()}$symbol';
    }
    return '${value.toStringAsFixed(1)}$symbol';
  }

  // ============ Default Units Factory Methods ============
  // NOTE: These now require categoryId parameter

  /// Create default TIME units
  static List<HabitUnit> createTimeUnits(String timeCategoryId) {
    final hourId = const Uuid().v4();
    return [
      HabitUnit(
        id: hourId,
        name: 'Hour',
        symbol: 'hr',
        pluralName: 'Hours',
        categoryId: timeCategoryId,
        isDefault: true,
        iconCodePoint: 0xe8b5, // Icons.access_time
        iconFontFamily: 'MaterialIcons',
        conversionFactor: 1.0,
      ),
      HabitUnit(
        name: 'Minute',
        symbol: 'min',
        pluralName: 'Minutes',
        categoryId: timeCategoryId,
        isDefault: true,
        iconCodePoint: 0xe8b5,
        iconFontFamily: 'MaterialIcons',
        conversionFactor: 60.0,
        baseUnitId: hourId,
      ),
      HabitUnit(
        name: 'Second',
        symbol: 'sec',
        pluralName: 'Seconds',
        categoryId: timeCategoryId,
        isDefault: true,
        iconCodePoint: 0xe8b5,
        iconFontFamily: 'MaterialIcons',
        conversionFactor: 3600.0,
        baseUnitId: hourId,
      ),
    ];
  }

  /// Create default VOLUME units
  static List<HabitUnit> createVolumeUnits(String volumeCategoryId) {
    final literId = const Uuid().v4();
    return [
      HabitUnit(
        id: literId,
        name: 'Liter',
        symbol: 'L',
        pluralName: 'Liters',
        categoryId: volumeCategoryId,
        isDefault: true,
        iconCodePoint: 0xe3e7,
        iconFontFamily: 'MaterialIcons',
        conversionFactor: 1.0,
      ),
      HabitUnit(
        name: 'Milliliter',
        symbol: 'ml',
        pluralName: 'Milliliters',
        categoryId: volumeCategoryId,
        isDefault: true,
        iconCodePoint: 0xe3e7,
        iconFontFamily: 'MaterialIcons',
        conversionFactor: 1000.0,
        baseUnitId: literId,
      ),
      HabitUnit(
        name: 'Glass',
        symbol: 'glass',
        pluralName: 'Glasses',
        categoryId: volumeCategoryId,
        isDefault: true,
        iconCodePoint: 0xe3e7,
        iconFontFamily: 'MaterialIcons',
        conversionFactor: 4.0,
        baseUnitId: literId,
      ),
    ];
  }

  /// Create default WEIGHT units
  static List<HabitUnit> createWeightUnits(String weightCategoryId) {
    final kgId = const Uuid().v4();
    return [
      HabitUnit(
        id: kgId,
        name: 'Kilogram',
        symbol: 'kg',
        pluralName: 'Kilograms',
        categoryId: weightCategoryId,
        isDefault: true,
        iconCodePoint: 0xe3a5,
        iconFontFamily: 'MaterialIcons',
        conversionFactor: 1.0,
      ),
      HabitUnit(
        name: 'Gram',
        symbol: 'g',
        pluralName: 'Grams',
        categoryId: weightCategoryId,
        isDefault: true,
        iconCodePoint: 0xe3a5,
        iconFontFamily: 'MaterialIcons',
        conversionFactor: 1000.0,
        baseUnitId: kgId,
      ),
      HabitUnit(
        name: 'Pound',
        symbol: 'lb',
        pluralName: 'Pounds',
        categoryId: weightCategoryId,
        isDefault: true,
        iconCodePoint: 0xe3a5,
        iconFontFamily: 'MaterialIcons',
        conversionFactor: 2.205,
        baseUnitId: kgId,
      ),
    ];
  }

  /// Create default DISTANCE units
  static List<HabitUnit> createDistanceUnits(String distanceCategoryId) {
    final kmId = const Uuid().v4();
    return [
      HabitUnit(
        id: kmId,
        name: 'Kilometer',
        symbol: 'km',
        pluralName: 'Kilometers',
        categoryId: distanceCategoryId,
        isDefault: true,
        iconCodePoint: 0xe566,
        iconFontFamily: 'MaterialIcons',
        conversionFactor: 1.0,
      ),
      HabitUnit(
        name: 'Meter',
        symbol: 'm',
        pluralName: 'Meters',
        categoryId: distanceCategoryId,
        isDefault: true,
        iconCodePoint: 0xe566,
        iconFontFamily: 'MaterialIcons',
        conversionFactor: 1000.0,
        baseUnitId: kmId,
      ),
      HabitUnit(
        name: 'Mile',
        symbol: 'mi',
        pluralName: 'Miles',
        categoryId: distanceCategoryId,
        isDefault: true,
        iconCodePoint: 0xe566,
        iconFontFamily: 'MaterialIcons',
        conversionFactor: 0.621,
        baseUnitId: kmId,
      ),
      HabitUnit(
        name: 'Step',
        symbol: 'steps',
        pluralName: 'Steps',
        categoryId: distanceCategoryId,
        isDefault: true,
        iconCodePoint: 0xe566,
        iconFontFamily: 'MaterialIcons',
        conversionFactor: 1312.0,
        baseUnitId: kmId,
      ),
    ];
  }

  /// Create default COUNT units
  static List<HabitUnit> createCountUnits(String countCategoryId) {
    return [
      HabitUnit(
        name: 'Time',
        symbol: 'x',
        pluralName: 'Times',
        categoryId: countCategoryId,
        isDefault: true,
        iconCodePoint: 0xe8f4,
        iconFontFamily: 'MaterialIcons',
        conversionFactor: 1.0,
      ),
      HabitUnit(
        name: 'Page',
        symbol: 'pg',
        pluralName: 'Pages',
        categoryId: countCategoryId,
        isDefault: true,
        iconCodePoint: 0xe865,
        iconFontFamily: 'MaterialIcons',
        conversionFactor: 1.0,
      ),
      HabitUnit(
        name: 'Rep',
        symbol: 'reps',
        pluralName: 'Reps',
        categoryId: countCategoryId,
        isDefault: true,
        iconCodePoint: 0xe3a5,
        iconFontFamily: 'MaterialIcons',
        conversionFactor: 1.0,
      ),
      HabitUnit(
        name: 'Set',
        symbol: 'sets',
        pluralName: 'Sets',
        categoryId: countCategoryId,
        isDefault: true,
        iconCodePoint: 0xe3a5,
        iconFontFamily: 'MaterialIcons',
        conversionFactor: 1.0,
      ),
      HabitUnit(
        name: 'Item',
        symbol: 'items',
        pluralName: 'Items',
        categoryId: countCategoryId,
        isDefault: true,
        iconCodePoint: 0xe8f4,
        iconFontFamily: 'MaterialIcons',
        conversionFactor: 1.0,
      ),
      HabitUnit(
        name: 'Chapter',
        symbol: 'ch',
        pluralName: 'Chapters',
        categoryId: countCategoryId,
        isDefault: true,
        iconCodePoint: 0xe865,
        iconFontFamily: 'MaterialIcons',
        conversionFactor: 1.0,
      ),
      HabitUnit(
        name: 'Calorie',
        symbol: 'cal',
        pluralName: 'Calories',
        categoryId: countCategoryId,
        isDefault: true,
        iconCodePoint: 0xe532,
        iconFontFamily: 'MaterialIcons',
        conversionFactor: 1.0,
      ),
    ];
  }
}
