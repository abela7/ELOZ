import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/more/data/services/comprehensive_app_backup_service.dart';

void main() {
  test('backup service routes worker jobs through an isolate', () async {
    final service = ComprehensiveAppBackupService();
    ComprehensiveAppBackupService.debugWorkerLaunchCount = 0;

    final value = await service.runNoopIsolateJobForTest(42);

    expect(value, 42);
    expect(
      ComprehensiveAppBackupService.debugWorkerLaunchCount,
      greaterThan(0),
    );
  });
}
