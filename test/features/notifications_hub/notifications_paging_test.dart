import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/notifications_hub/presentation/utils/notifications_paging.dart';

void main() {
  group('NotificationsPaging boundaries', () {
    test('initial and next page sizing are deterministic', () {
      expect(NotificationsPaging.initialVisible(pageSize: 50), 50);
      expect(NotificationsPaging.nextVisible(50, pageSize: 50), 100);
      expect(NotificationsPaging.nextVisible(-1, pageSize: 30), 30);
    });

    test('clamp keeps visible range inside valid bounds', () {
      expect(
        NotificationsPaging.clampVisible(totalCount: 0, requestedVisible: 20),
        0,
      );
      expect(
        NotificationsPaging.clampVisible(totalCount: 10, requestedVisible: 0),
        10,
      );
      expect(
        NotificationsPaging.clampVisible(totalCount: 120, requestedVisible: 60),
        60,
      );
      expect(
        NotificationsPaging.clampVisible(totalCount: 35, requestedVisible: 90),
        35,
      );
    });

    test('paging does not miss or reorder items across pages', () {
      final items = List<int>.generate(135, (index) => index);
      var visible = NotificationsPaging.initialVisible(pageSize: 60);

      var clamped = NotificationsPaging.clampVisible(
        totalCount: items.length,
        requestedVisible: visible,
      );
      var page = items.take(clamped).toList();
      expect(page, items.sublist(0, 60));
      expect(
        NotificationsPaging.hasMore(
          totalCount: items.length,
          visibleCount: clamped,
        ),
        isTrue,
      );

      visible = NotificationsPaging.nextVisible(visible, pageSize: 60);
      clamped = NotificationsPaging.clampVisible(
        totalCount: items.length,
        requestedVisible: visible,
      );
      page = items.take(clamped).toList();
      expect(page, items.sublist(0, 120));

      visible = NotificationsPaging.nextVisible(visible, pageSize: 60);
      clamped = NotificationsPaging.clampVisible(
        totalCount: items.length,
        requestedVisible: visible,
      );
      page = items.take(clamped).toList();
      expect(page, items);
      expect(
        NotificationsPaging.hasMore(
          totalCount: items.length,
          visibleCount: clamped,
        ),
        isFalse,
      );
    });
  });
}
