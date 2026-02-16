class NotificationsPaging {
  static const int defaultPageSize = 60;

  static int initialVisible({int pageSize = defaultPageSize}) {
    return pageSize;
  }

  static int nextVisible(int currentVisible, {int pageSize = defaultPageSize}) {
    if (currentVisible < 0) {
      return pageSize;
    }
    return currentVisible + pageSize;
  }

  static int clampVisible({
    required int totalCount,
    required int requestedVisible,
  }) {
    if (totalCount <= 0) {
      return 0;
    }
    if (requestedVisible <= 0) {
      return totalCount < defaultPageSize ? totalCount : defaultPageSize;
    }
    return requestedVisible < totalCount ? requestedVisible : totalCount;
  }

  static bool hasMore({required int totalCount, required int visibleCount}) {
    return visibleCount < totalCount;
  }
}
