import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cozy_clean/core/providers/shared_prefs_provider.dart';

/// Blitz 秒开能力的灰度开关与基础埋点服务。
final blitzRolloutServiceProvider = Provider<BlitzRolloutService>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  return BlitzRolloutService(prefs);
});

/// Blitz 灰度控制与轻量埋点。
class BlitzRolloutService {
  static const String _kPrewarmEnabled = 'blitz_prewarm_enabled';
  static const String _kPrewarmHitCount = 'blitz_metric_prewarm_hit';
  static const String _kPrewarmMissCount = 'blitz_metric_prewarm_miss';
  static const String _kDeleteRequestCount = 'blitz_metric_delete_request';
  static const String _kDeleteSuccessCount = 'blitz_metric_delete_success';
  static const String _kDeleteFailureCount = 'blitz_metric_delete_failure';

  const BlitzRolloutService(this._prefs);

  final SharedPreferences _prefs;

  /// 是否启用 Blitz 预热秒开链路，默认开启。
  bool get isPrewarmEnabled => _prefs.getBool(_kPrewarmEnabled) ?? true;

  /// 切换预热链路开关。
  Future<void> setPrewarmEnabled(bool enabled) async {
    await _prefs.setBool(_kPrewarmEnabled, enabled);
  }

  /// 记录一次预热命中。
  Future<void> recordPrewarmHit() => _increment(_kPrewarmHitCount);

  /// 记录一次预热未命中。
  Future<void> recordPrewarmMiss() => _increment(_kPrewarmMissCount);

  /// 记录一次删除请求与结果。
  Future<void> recordDeletion({
    required int requestedCount,
    required int deletedCount,
  }) async {
    await _incrementBy(_kDeleteRequestCount, requestedCount);
    if (requestedCount == 0 || deletedCount > 0) {
      await _increment(_kDeleteSuccessCount);
    } else {
      await _increment(_kDeleteFailureCount);
    }
  }

  /// 返回当前埋点快照，便于调试与线上排查。
  Map<String, int> metricsSnapshot() {
    return <String, int>{
      _kPrewarmHitCount: _prefs.getInt(_kPrewarmHitCount) ?? 0,
      _kPrewarmMissCount: _prefs.getInt(_kPrewarmMissCount) ?? 0,
      _kDeleteRequestCount: _prefs.getInt(_kDeleteRequestCount) ?? 0,
      _kDeleteSuccessCount: _prefs.getInt(_kDeleteSuccessCount) ?? 0,
      _kDeleteFailureCount: _prefs.getInt(_kDeleteFailureCount) ?? 0,
    };
  }

  int get prewarmHitCount => _prefs.getInt(_kPrewarmHitCount) ?? 0;
  int get prewarmMissCount => _prefs.getInt(_kPrewarmMissCount) ?? 0;
  int get deleteRequestCount => _prefs.getInt(_kDeleteRequestCount) ?? 0;
  int get deleteSuccessCount => _prefs.getInt(_kDeleteSuccessCount) ?? 0;
  int get deleteFailureCount => _prefs.getInt(_kDeleteFailureCount) ?? 0;

  Future<void> _increment(String key) => _incrementBy(key, 1);

  Future<void> _incrementBy(String key, int delta) async {
    final current = _prefs.getInt(key) ?? 0;
    await _prefs.setInt(key, current + delta);
  }
}
