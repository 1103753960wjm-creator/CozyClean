import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cozy_clean/core/services/blitz_rollout_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BlitzRolloutService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('预热开关默认开启并可切换', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = BlitzRolloutService(prefs);

      expect(service.isPrewarmEnabled, true);

      await service.setPrewarmEnabled(false);
      expect(service.isPrewarmEnabled, false);
    });

    test('埋点计数符合预期', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = BlitzRolloutService(prefs);

      await service.recordPrewarmHit();
      await service.recordPrewarmMiss();
      await service.recordDeletion(requestedCount: 3, deletedCount: 2);
      await service.recordDeletion(requestedCount: 2, deletedCount: 0);

      expect(service.prewarmHitCount, 1);
      expect(service.prewarmMissCount, 1);
      expect(service.deleteRequestCount, 5);
      expect(service.deleteSuccessCount, 1);
      expect(service.deleteFailureCount, 1);
    });
  });
}
