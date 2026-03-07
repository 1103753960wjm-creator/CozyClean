import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_clean/core/state/blitz_prewarm_state.dart';

void main() {
  group('BlitzPrewarmState', () {
    test('copyWith 可更新字段并保持不可变集合', () {
      final state = BlitzPrewarmState(
        status: PrewarmStatus.scanning,
        assets: const <AssetLite>[
          AssetLite(id: 'a1', timestamp: 1000),
        ],
        // ignore: prefer_const_literals_to_create_immutables
        groups: <PhotoGroupLite>[
          PhotoGroupLite(assetIds: const <String>['a1']),
        ],
      );

      final next = state.copyWith(
        status: PrewarmStatus.ready,
        isStale: true,
      );

      expect(next.status, PrewarmStatus.ready);
      expect(next.isStale, true);
      expect(next.assets.length, 1);
      expect(next.groups.length, 1);

      expect(
        () => next.assets.add(const AssetLite(id: 'x', timestamp: 1)),
        throwsUnsupportedError,
      );
      expect(
        () => next.groups.add(PhotoGroupLite(assetIds: const <String>['x'])),
        throwsUnsupportedError,
      );
    });
  });
}
