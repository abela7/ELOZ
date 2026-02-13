import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'sleep_template.g.dart';

/// Sleep log template for fast manual logging.
///
/// Stores time-only presets (bed/wake), optionally nap mode.
///
/// Schema Version: 1
/// - v1: Initial schema with 11 fields (HiveField 0-10)
@HiveType(typeId: 53)
class SleepTemplate extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  int bedHour;

  @HiveField(3)
  int bedMinute;

  @HiveField(4)
  int wakeHour;

  @HiveField(5)
  int wakeMinute;

  @HiveField(6)
  bool isNap;

  @HiveField(7)
  DateTime createdAt;

  @HiveField(8)
  DateTime? updatedAt;

  @HiveField(9)
  bool isDefault;

  @HiveField(10)
  int schemaVersion;

  SleepTemplate({
    String? id,
    required this.name,
    required this.bedHour,
    required this.bedMinute,
    required this.wakeHour,
    required this.wakeMinute,
    this.isNap = false,
    DateTime? createdAt,
    this.updatedAt,
    this.isDefault = false,
    this.schemaVersion = 1,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  static const int currentSchemaVersion = 1;

  bool get crossesMidnight {
    if (wakeHour < bedHour) return true;
    if (wakeHour == bedHour && wakeMinute <= bedMinute) return true;
    return false;
  }

  int get durationMinutes {
    final bed = bedHour * 60 + bedMinute;
    final wake = wakeHour * 60 + wakeMinute;
    if (crossesMidnight) {
      return (24 * 60 - bed) + wake;
    }
    return wake - bed;
  }

  SleepTemplate copyWith({
    String? id,
    String? name,
    int? bedHour,
    int? bedMinute,
    int? wakeHour,
    int? wakeMinute,
    bool? isNap,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDefault,
    int? schemaVersion,
  }) {
    return SleepTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      bedHour: bedHour ?? this.bedHour,
      bedMinute: bedMinute ?? this.bedMinute,
      wakeHour: wakeHour ?? this.wakeHour,
      wakeMinute: wakeMinute ?? this.wakeMinute,
      isNap: isNap ?? this.isNap,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDefault: isDefault ?? this.isDefault,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }

}

