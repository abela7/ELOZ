import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

/// Daily mood log entry.
class MoodEntry extends HiveObject {
  static const Object _unset = Object();

  MoodEntry({
    String? id,
    required this.moodId,
    /// Deprecated single-reason field kept for reading old Hive records.
    String? reasonId,
    List<String>? reasonIds,
    this.customNote,
    required this.loggedAt,
    DateTime? createdAt,
    this.updatedAt,
    this.source = 'manual',
    this.deletedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       // Merge: reasonIds wins; fall back to wrapping the legacy reasonId.
       reasonIds = reasonIds?.isNotEmpty == true
           ? reasonIds!
           : (reasonId != null && reasonId.trim().isNotEmpty
               ? [reasonId.trim()]
               : const []);

  final String id;
  final String moodId;
  final List<String> reasonIds;
  final String? customNote;
  final DateTime loggedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String source;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  /// First reason ID for backward-compat callers that only expect one.
  String? get reasonId => reasonIds.isEmpty ? null : reasonIds.first;

  String get dayKey {
    final local = loggedAt.toLocal();
    final yyyy = local.year.toString().padLeft(4, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '$yyyy$mm$dd';
  }

  MoodEntry copyWith({
    String? id,
    String? moodId,
    Object? reasonIds = _unset,
    Object? customNote = _unset,
    DateTime? loggedAt,
    DateTime? createdAt,
    Object? updatedAt = _unset,
    String? source,
    Object? deletedAt = _unset,
  }) {
    return MoodEntry(
      id: id ?? this.id,
      moodId: moodId ?? this.moodId,
      reasonIds: reasonIds == _unset
          ? this.reasonIds
          : (reasonIds as List<String>?) ?? const [],
      customNote: customNote == _unset
          ? this.customNote
          : customNote as String?,
      loggedAt: loggedAt ?? this.loggedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt == _unset ? this.updatedAt : updatedAt as DateTime?,
      source: source ?? this.source,
      deletedAt: deletedAt == _unset ? this.deletedAt : deletedAt as DateTime?,
    );
  }
}

class MoodEntryAdapter extends TypeAdapter<MoodEntry> {
  @override
  final int typeId = 62;

  @override
  MoodEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }

    // Field 9 = new List<String> reasonIds (may be null on old records).
    final rawReasonIds = fields[9];
    List<String>? reasonIds;
    if (rawReasonIds is List && rawReasonIds.isNotEmpty) {
      reasonIds = rawReasonIds.cast<String>();
    }

    return MoodEntry(
      id: fields[0] as String?,
      moodId: fields[1] as String? ?? '',
      // Field 2 = legacy String reasonId — only used when field 9 absent.
      reasonId: fields[2] as String?,
      reasonIds: reasonIds,
      customNote: fields[3] as String?,
      loggedAt: fields[4] as DateTime? ?? DateTime.now(),
      createdAt: fields[5] as DateTime?,
      updatedAt: fields[6] as DateTime?,
      source: fields[7] as String? ?? 'manual',
      deletedAt: fields[8] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, MoodEntry obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.moodId)
      // Keep writing field 2 as the first reasonId for any old code reading it.
      ..writeByte(2)
      ..write(obj.reasonId)
      ..writeByte(3)
      ..write(obj.customNote)
      ..writeByte(4)
      ..write(obj.loggedAt)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.updatedAt)
      ..writeByte(7)
      ..write(obj.source)
      ..writeByte(8)
      ..write(obj.deletedAt)
      // Field 9 = new multi-reason list.
      ..writeByte(9)
      ..write(obj.reasonIds);
  }
}
