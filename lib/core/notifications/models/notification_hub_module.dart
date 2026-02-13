class NotificationHubModule {
  final String moduleId;
  final String displayName;
  final String description;
  final int idRangeStart;
  final int idRangeEnd;
  final int iconCodePoint;
  final String iconFontFamily;
  final String? iconFontPackage;
  final int colorValue;
  final bool defaultEnabled;

  const NotificationHubModule({
    required this.moduleId,
    required this.displayName,
    required this.description,
    required this.idRangeStart,
    required this.idRangeEnd,
    required this.iconCodePoint,
    this.iconFontFamily = 'MaterialIcons',
    this.iconFontPackage,
    required this.colorValue,
    this.defaultEnabled = true,
  });

  int get rangeSize {
    if (idRangeEnd < idRangeStart) {
      return 0;
    }
    return idRangeEnd - idRangeStart + 1;
  }

  bool containsNotificationId(int notificationId) {
    return notificationId >= idRangeStart && notificationId <= idRangeEnd;
  }
}
