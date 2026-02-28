/// CozyClean — 闪电战核心控制器
///
/// 使用 Riverpod 的 Notifier 模式管理 [BlitzState]。
///
/// 四方向交互：
///   - swipeLeft(photo)  → 删除照片，加入 sessionDeleted
///   - swipeRight(photo) → 保留照片，加入 sessionKept
///   - swipeUp(photo)    → 收藏照片，加入 sessionFavorites（最多 6 张）
///   - swipeDown(photo)  → 跳过到待定区，加入 sessionPending
///
/// 架构约束：
///   - ❌ 不得 import PhotoManager / AppDatabase / DataSource
///   - ✅ 仅通过 Repository 获取数据
///   - ✅ 仅通过 Service 执行纯业务逻辑
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import 'package:cozy_clean/features/blitz/application/state/blitz_state.dart';
import 'package:cozy_clean/features/blitz/data/providers/blitz_data_providers.dart';
import 'package:cozy_clean/features/blitz/domain/models/photo_group.dart';
import 'package:cozy_clean/features/blitz/domain/repositories/onboarding_repository.dart';
import 'package:cozy_clean/features/blitz/domain/services/burst_grouping_service.dart';
import 'package:cozy_clean/presentation/controllers/user_stats_controller.dart';

// ============================================================
// Isolate 分组支持 — 顶层函数（compute 要求）
// ============================================================

/// 连拍分组的 isolate 输入参数
///
/// AssetEntity 无法跨 isolate 传递（持有 MethodChannel 引用），
/// 因此只传递轻量级时间戳数据。
class _BurstGroupingParams {
  final List<int> timestamps;
  final int thresholdMs;

  const _BurstGroupingParams({
    required this.timestamps,
    required this.thresholdMs,
  });
}

/// isolate 中执行的连拍分组（O(n) 单遍扫描）
///
/// 返回分组边界索引列表，例如 [0, 3, 5, 8]。
List<int> _computeBurstGroupBoundaries(_BurstGroupingParams params) {
  final timestamps = params.timestamps;
  if (timestamps.isEmpty) return const [];

  final List<int> boundaries = [0];
  for (int i = 1; i < timestamps.length; i++) {
    final diff = (timestamps[i] - timestamps[i - 1]).abs();
    if (diff > params.thresholdMs) {
      boundaries.add(i);
    }
  }
  boundaries.add(timestamps.length);
  return boundaries;
}

// ============================================================
// Riverpod Provider 定义
// ============================================================

/// 连拍分组服务 Provider（纯逻辑，无状态）
final burstGroupingServiceProvider = Provider<BurstGroupingService>((ref) {
  return const BurstGroupingService();
});

/// 闪电战控制器 Provider
final blitzControllerProvider =
    NotifierProvider<BlitzController, BlitzState>(BlitzController.new);

// ============================================================
// 闪电战控制器
// ============================================================

/// 闪电战 (Blitz Mode) 核心引擎控制器
///
/// 四方向操作控制器，所有状态变更通过 state = state.copyWith(...) 触发 UI 重建。
/// Controller 本身不执行任何 IO，是纯粹的业务逻辑协调者。
class BlitzController extends Notifier<BlitzState> {
  bool _loadingInProgress = false;

  @override
  BlitzState build() => const BlitzState(isLoading: true);

  BlitzRepository get _repository => ref.read(blitzRepositoryProvider);
  BurstGroupingService get _burstService =>
      ref.read(burstGroupingServiceProvider);
  OnboardingRepository get _onboardingRepository =>
      ref.read(onboardingRepositoryProvider);

  // ============================================================
  // 初始化与照片加载
  // ============================================================

  /// 从相册加载照片并执行连拍分组
  ///
  /// 流程：权限 → 获取照片 → 分组 → 预加载缩略图 → 读体力 → 更新 state
  Future<void> loadPhotos() async {
    if (_loadingInProgress) return;
    _loadingInProgress = true;

    state = state.copyWith(
      isLoading: true,
      errorMessage: () => null,
    );

    try {
      final hasPermission = await _repository.requestPermission();
      if (!hasPermission) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: () => '需要相册访问权限才能整理照片，请在设置中开启',
        );
        return;
      }

      final flatPhotos = await _repository.fetchUnprocessedPhotos();
      if (flatPhotos.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          photoGroups: const [],
        );
        return;
      }

      final sortedPhotos = List<AssetEntity>.from(flatPhotos.reversed);
      final groups = await _groupPhotos(sortedPhotos);
      debugPrint('[BlitzController] 分组完成: ${groups.length} 组 '
          '(来自 ${flatPhotos.length} 张照片)');

      final cache = await _repository.preloadThumbnails(flatPhotos);
      final energyStatus = await _repository.getUserEnergyStatus();

      state = state.copyWith(
        photoGroups: groups,
        currentGroupIndex: 0,
        currentEnergy: energyStatus.energy,
        isLoading: false,
        errorMessage: () => null,
        sessionDeleted: const [],
        sessionKept: const [],
        sessionFavorites: const [],
        sessionPending: const [],
        thumbnailCache: cache,
      );

      debugPrint('[BlitzController] ✅ 加载完成: '
          '${groups.length} 组, 体力 ${energyStatus.energy}');
    } catch (e, stackTrace) {
      debugPrint('[BlitzController] ❌ 加载失败: $e\n$stackTrace');
      state = state.copyWith(
        isLoading: false,
        errorMessage: () => '加载照片失败: $e',
      );
    } finally {
      _loadingInProgress = false;
    }
  }

  // ============================================================
  // 新手引导状态控制
  // ============================================================

  /// 读取底层偏好设置，决定是否显示引导蒙版
  void loadOnboardingStatus() {
    try {
      final hasSeen = _onboardingRepository.hasSeenBlitzOnboarding();
      state = state.copyWith(
        showOnboarding: !hasSeen,
        onboardingLoaded: true,
      );
    } catch (e) {
      // SharedPreferences 可能在热重载后未正确注入，
      // 此时降级为不显示引导，避免阻塞整个页面。
      debugPrint('[BlitzController] ⚠️ 引导状态加载失败: $e');
      state = state.copyWith(
        showOnboarding: false,
        onboardingLoaded: true,
      );
    }
  }

  /// 关闭新手引导并异步写底层存储
  Future<void> dismissOnboarding() async {
    state = state.copyWith(showOnboarding: false);
    await _onboardingRepository.setSeenBlitzOnboarding();
  }

  // ============================================================
  // Isolate 智能分组策略
  // ============================================================

  static const int _isolateThreshold = 300;

  /// 自动选择主线程或 isolate 执行连拍分组
  Future<List<PhotoGroup>> _groupPhotos(List<AssetEntity> sortedPhotos) async {
    if (sortedPhotos.length <= _isolateThreshold) {
      debugPrint('[BlitzController] 主线程分组 (${sortedPhotos.length} 张)');
      return _burstService.groupBurstPhotos(sortedPhotos);
    }

    debugPrint('[BlitzController] Isolate 分组 (${sortedPhotos.length} 张)');

    final timestamps = sortedPhotos
        .map((p) => p.createDateTime.millisecondsSinceEpoch)
        .toList();

    final boundaries = await compute(
      _computeBurstGroupBoundaries,
      _BurstGroupingParams(
        timestamps: timestamps,
        thresholdMs: _burstService.burstThresholdMs,
      ),
    );

    if (boundaries.isEmpty) return const [];

    final List<PhotoGroup> groups = [];
    for (int i = 0; i < boundaries.length - 1; i++) {
      groups.add(PhotoGroup(
          photos: sortedPhotos.sublist(boundaries[i], boundaries[i + 1])));
    }
    return groups;
  }

  // ============================================================
  // 四方向交互（纯内存草稿，不碰数据库）
  // ============================================================

  /// 体力检查与扣除的公共逻辑
  ///
  /// 返回 false 表示体力不足，操作应被拦截。
  bool _checkAndConsumeEnergy() {
    final bool isPro = state.currentEnergy == double.infinity;
    if (!isPro && state.currentEnergy < 1.0) return false;
    return true;
  }

  /// 异步持久化体力扣除到 DB
  Future<void> _persistEnergyChange(double delta) async {
    try {
      await ref.read(userStatsControllerProvider).consumeEnergy(delta);
    } catch (e) {
      debugPrint('[BlitzController] 体力持久化失败: $e');
    }
  }

  /// ← 左滑 — 删除照片
  ///
  /// 返回 true 表示操作成功，false 表示体力不足被拦截。
  Future<bool> swipeLeft(AssetEntity photo) async {
    if (!_checkAndConsumeEnergy()) return false;
    final bool isPro = state.currentEnergy == double.infinity;

    state = state.copyWith(
      currentEnergy: isPro ? state.currentEnergy : state.currentEnergy - 1.0,
      currentGroupIndex: state.currentGroupIndex + 1,
      sessionDeleted: [...state.sessionDeleted, photo],
      lastSwipedPhoto: () => photo,
      lastSwipeDirection: () => BlitzState.directionLeft,
      errorMessage: () => null,
    );

    _persistEnergyChange(1.0);
    return true;
  }

  /// → 右滑 — 保留照片
  Future<bool> swipeRight(AssetEntity photo) async {
    if (!_checkAndConsumeEnergy()) return false;
    final bool isPro = state.currentEnergy == double.infinity;

    state = state.copyWith(
      currentEnergy: isPro ? state.currentEnergy : state.currentEnergy - 1.0,
      currentGroupIndex: state.currentGroupIndex + 1,
      sessionKept: [...state.sessionKept, photo],
      lastSwipedPhoto: () => photo,
      lastSwipeDirection: () => BlitzState.directionRight,
      errorMessage: () => null,
    );

    _persistEnergyChange(1.0);
    return true;
  }

  /// ↑ 上滑 — 收藏照片（最多 6 张）
  ///
  /// 当收藏已满时返回 false，UI 应当弹回卡片并提示。
  Future<bool> swipeUp(AssetEntity photo) async {
    if (state.isFavoritesFull) return false;
    if (!_checkAndConsumeEnergy()) return false;
    final bool isPro = state.currentEnergy == double.infinity;

    state = state.copyWith(
      currentEnergy: isPro ? state.currentEnergy : state.currentEnergy - 1.0,
      currentGroupIndex: state.currentGroupIndex + 1,
      sessionFavorites: [...state.sessionFavorites, photo],
      lastSwipedPhoto: () => photo,
      lastSwipeDirection: () => BlitzState.directionUp,
      errorMessage: () => null,
    );

    _persistEnergyChange(1.0);
    return true;
  }

  /// ↓ 下滑 — 跳过到待定区
  ///
  /// 不消耗体力（待定 = 尚未决策），只推进索引。
  bool swipeDown(AssetEntity photo) {
    state = state.copyWith(
      currentGroupIndex: state.currentGroupIndex + 1,
      sessionPending: [...state.sessionPending, photo],
      lastSwipedPhoto: () => photo,
      lastSwipeDirection: () => BlitzState.directionDown,
      errorMessage: () => null,
    );
    return true;
  }

  // ============================================================
  // 撤销与草稿管理
  // ============================================================

  /// 撤销上一次滑动操作（仅限最后一张）
  ///
  /// 根据 [lastSwipeDirection] 精确从对应列表中移除照片。
  /// 执行完毕后锁死连续撤销（lastSwipedPhoto = null）。
  bool undoLastSwipe() {
    final photo = state.lastSwipedPhoto;
    final direction = state.lastSwipeDirection;
    if (photo == null || direction == null) return false;

    final isPro = state.currentEnergy == double.infinity;

    // 根据方向从对应列表中移除
    List<AssetEntity> removeFrom(List<AssetEntity> list) =>
        List<AssetEntity>.from(list)..removeWhere((p) => p.id == photo.id);

    switch (direction) {
      case BlitzState.directionLeft:
        state = state.copyWith(
          currentEnergy:
              isPro ? state.currentEnergy : state.currentEnergy + 1.0,
          currentGroupIndex: state.currentGroupIndex - 1,
          sessionDeleted: removeFrom(state.sessionDeleted),
          lastSwipedPhoto: () => null,
          lastSwipeDirection: () => null,
        );
        _persistEnergyChange(-1.0);
        break;

      case BlitzState.directionRight:
        state = state.copyWith(
          currentEnergy:
              isPro ? state.currentEnergy : state.currentEnergy + 1.0,
          currentGroupIndex: state.currentGroupIndex - 1,
          sessionKept: removeFrom(state.sessionKept),
          lastSwipedPhoto: () => null,
          lastSwipeDirection: () => null,
        );
        _persistEnergyChange(-1.0);
        break;

      case BlitzState.directionUp:
        state = state.copyWith(
          currentEnergy:
              isPro ? state.currentEnergy : state.currentEnergy + 1.0,
          currentGroupIndex: state.currentGroupIndex - 1,
          sessionFavorites: removeFrom(state.sessionFavorites),
          lastSwipedPhoto: () => null,
          lastSwipeDirection: () => null,
        );
        _persistEnergyChange(-1.0);
        break;

      case BlitzState.directionDown:
        // 下滑不消耗体力，所以不退还
        state = state.copyWith(
          currentGroupIndex: state.currentGroupIndex - 1,
          sessionPending: removeFrom(state.sessionPending),
          lastSwipedPhoto: () => null,
          lastSwipeDirection: () => null,
        );
        break;
    }

    return true;
  }

  // ============================================================
  // 待定区回放
  // ============================================================

  /// 进入待定区回放阶段
  ///
  /// 主照片全部处理完毕后，如果 sessionPending 不为空，
  /// 由 UI 层调用此方法切换到回放阶段。
  void enterPendingReview() {
    if (state.sessionPending.isEmpty) return;

    state = state.copyWith(
      isReviewingPending: true,
      pendingReviewIndex: 0,
    );
  }

  /// 回放阶段 — 左滑删除待定照片
  ///
  /// 将当前待定照片加入 sessionDeleted，索引前进。
  /// 不消耗体力（已在正常阶段处理过一次）。
  /// 不从 sessionPending 中移除，仅推进 pendingReviewIndex。
  void reviewPendingLeft() {
    final photo = state.currentPendingPhoto;
    if (photo == null) return;

    state = state.copyWith(
      sessionDeleted: [...state.sessionDeleted, photo],
      pendingReviewIndex: state.pendingReviewIndex + 1,
    );
  }

  /// 回放阶段 — 右滑保留待定照片
  ///
  /// 将当前待定照片加入 sessionKept，索引前进。
  /// 不消耗体力，不从 sessionPending 中移除。
  void reviewPendingRight() {
    final photo = state.currentPendingPhoto;
    if (photo == null) return;

    state = state.copyWith(
      sessionKept: [...state.sessionKept, photo],
      pendingReviewIndex: state.pendingReviewIndex + 1,
    );
  }

  /// 回放阶段 — 上滑收藏待定照片
  ///
  /// 将当前待定照片加入 sessionFavorites，索引前进。
  /// 仍检查收藏上限（最多 6 张），超限时返回 false。
  /// 不消耗体力，不从 sessionPending 中移除。
  bool reviewPendingUp() {
    final photo = state.currentPendingPhoto;
    if (photo == null) return false;

    if (state.isFavoritesFull) return false;

    state = state.copyWith(
      sessionFavorites: [...state.sessionFavorites, photo],
      pendingReviewIndex: state.pendingReviewIndex + 1,
    );
    return true;
  }

  /// 结束待定区回放阶段
  ///
  /// 由 UI 层在检测到 isPendingReviewFinished 后调用，
  /// 在跳转结算页之前将 isReviewingPending 重置为 false。
  void finishPendingReview() {
    state = state.copyWith(
      isReviewingPending: false,
    );
  }

  /// 清空本轮内存草稿（用户中途退出时调用）
  void clearSessionDraft() {
    state = state.copyWith(
      sessionDeleted: const [],
      sessionKept: const [],
      sessionFavorites: const [],
      sessionPending: const [],
      lastSwipedPhoto: () => null,
      lastSwipeDirection: () => null,
      isReviewingPending: false,
      pendingReviewIndex: 0,
    );
  }

  /// 清空所有照片处理记录并重新加载
  Future<void> resetAllPhotoActions() async {
    HapticFeedback.lightImpact();
    await _repository.deleteAllPhotoActions();
    await loadPhotos();
  }

  // ============================================================
  // 辅助方法
  // ============================================================

  /// 判定某张卡片是否应当触发实际加载（防 OOM 策略）
  ///
  /// 保留前 1 张（备用撤销）+ 当前 + 后续 3 张。
  bool shouldCacheImage(int index) {
    if (state.photoGroups.isEmpty) return false;
    final lower = state.currentGroupIndex - 1;
    final upper = state.currentGroupIndex + 3;
    return index >= lower && index <= upper;
  }
}
