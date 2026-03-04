import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cozy_clean/core/providers/shared_prefs_provider.dart';

/// 依赖注入：提供 OnboardingRepository 实例
final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return OnboardingRepository(prefs);
});

/// 闪电战新手引导持久化仓储
/// 负责与底层 shared_preferences 交互，隔离 UI 层对存储的直接访问。
class OnboardingRepository {
  final SharedPreferences _prefs;

  static const String _kHasSeenBlitzOnboarding = 'has_seen_blitz_onboarding';
  static const String _kHasSeenIntroSwiper = 'has_seen_intro_swiper';

  OnboardingRepository(this._prefs);

  /// 检查用户是否已经看过 App 全屏开屏引导
  bool hasSeenIntroSwiper() {
    return _prefs.getBool(_kHasSeenIntroSwiper) ?? false;
  }

  /// 标记用户已经看过 App 全屏开屏引导
  Future<void> setSeenIntroSwiper() async {
    await _prefs.setBool(_kHasSeenIntroSwiper, true);
  }

  /// 检查用户是否已经看过闪电战操作导引蒙版
  /// 默认返回 false（没看过）
  bool hasSeenBlitzOnboarding() {
    return _prefs.getBool(_kHasSeenBlitzOnboarding) ?? false;
  }

  /// 标记用户已经看过了闪电战操作导引蒙版
  Future<void> setSeenBlitzOnboarding() async {
    await _prefs.setBool(_kHasSeenBlitzOnboarding, true);
  }

  /// 重置引导状态（用于测试或重新展示）
  Future<void> clearSeenBlitzOnboarding() async {
    await _prefs.remove(_kHasSeenBlitzOnboarding);
    await _prefs.remove(_kHasSeenIntroSwiper);
  }
}
