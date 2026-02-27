/// CozyClean — 闪电战核心控制器
///
/// 使用 Riverpod 的 Notifier 模式管理 [BlitzState]。
///
/// 架构流程说明：
///   Controller 是分层架构中的 **业务逻辑协调者**，
///   不直接接触任何底层数据源（PhotoManager、Database），
///   而是通过 Repository 和 Service 的组合完成工作。
///
///   数据流：
///   ```
///   UI (pages/widgets)
///     ↓ 调用 Controller 方法（swipeRight、swipeLeft 等）
///   Controller ← 你在这里
///     ↓ 读取数据         ↓ 执行业务逻辑
///   Repository          Service
///     ↓                    ↓
///   DataSource + DB     BurstGroupingService（纯函数）
///   ```
///
///   初始化流程：
///   1. Controller.loadPhotos() 被 UI 的 initState 触发
///   2. Repository.requestPermission()  → 请求相册权限
///   3. Repository.fetchUnprocessedPhotos()  → 获取扁平照片列表
///   4. BurstGroupingService.groupBurstPhotos()  → 连拍分组
///   5. Repository.preloadThumbnails()  → 预加载缩略图
///   6. Repository.getUserEnergyStatus()  → 读取体力值
///   7. state = state.copyWith(...)  → 更新 UI
///
///   交互流程：
///   1. UI 监听 swiper 的 onSwipeEnd 回调
///   2. 调用 Controller.swipeRight/swipeLeft
///   3. Controller 更新 state（内存草稿）
///   4. UI 自动重建
///
/// 禁止事项（架构约束）：
///   - ❌ 不得 import PhotoManager
///   - ❌ 不得 import AppDatabase
///   - ❌ 不得 import DataSource
///   - ❌ 不得在 Controller 中执行 IO（文件读写、网络请求）
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
import 'package:cozy_clean/features/blitz/domain/services/burst_grouping_service.dart';
import 'package:cozy_clean/presentation/controllers/user_stats_controller.dart';

// ============================================================
// Isolate 分组支持 — 顶层函数（compute 要求）
// ============================================================

/// 连拍分组的 isolate 输入参数
///
/// 为什么不直接传 AssetEntity 列表：
///   AssetEntity 内部持有平台通道 (MethodChannel) 的引用，
///   而平台通道绑定在主 isolate 的事件循环上，无法跨 isolate 传递。
///   因此只提取轻量级的时间戳数据传入 isolate，
///   分组计算完毕后在主线程根据索引边界重建 PhotoGroup。
class _BurstGroupingParams {
  /// 每张照片的 createDateTime 毫秒时间戳（已按升序排列）
  final List<int> timestamps;

  /// 连拍判定阈值（毫秒）
  final int thresholdMs;

  const _BurstGroupingParams({
    required this.timestamps,
    required this.thresholdMs,
  });
}

/// 在 isolate 中执行的连拍分组纯函数（compute 要求顶层函数）
///
/// 算法与 BurstGroupingService.groupBurstPhotos 完全一致（O(n) 单遍扫描），
/// 但输入输出均为可跨 isolate 传递的基本类型。
///
/// 返回值：分组边界索引列表
///   例如 [0, 3, 5, 8] 表示：
///   - 第 0 组: photos[0..2]
///   - 第 1 组: photos[3..4]
///   - 第 2 组: photos[5..7]
///   最后一个元素是 photos.length，作为终止哨兵。
List<int> _computeBurstGroupBoundaries(_BurstGroupingParams params) {
  final timestamps = params.timestamps;
  if (timestamps.isEmpty) return const [];

  final List<int> boundaries = [0]; // 第一组起始于 index 0

  for (int i = 1; i < timestamps.length; i++) {
    final diff = (timestamps[i] - timestamps[i - 1]).abs();
    if (diff > params.thresholdMs) {
      boundaries.add(i); // 新组起始索引
    }
  }

  boundaries.add(timestamps.length); // 终止哨兵
  return boundaries;
}

// ============================================================
// Riverpod Provider 定义（仅 Controller 层自身的 Provider）
// ============================================================

/// BurstGroupingService Provider
///
/// 纯逻辑服务，无状态，可安全共享。
final burstGroupingServiceProvider = Provider<BurstGroupingService>((ref) {
  return const BurstGroupingService();
});

/// 闪电战控制器的 Provider
///
/// 使用 NotifierProvider 让 Riverpod 管理控制器的生命周期。
/// 数据层的 Provider（appDatabaseProvider、blitzRepositoryProvider 等）
/// 定义在 [blitz_data_providers.dart]，Controller 仅通过 blitzRepositoryProvider 访问数据。
final blitzControllerProvider =
    NotifierProvider<BlitzController, BlitzState>(BlitzController.new);

// ============================================================
// 闪电战控制器
// ============================================================

/// 闪电战 (Blitz Mode) 核心引擎控制器
///
/// 设计原则：
///   - 所有状态变更通过 state = state.copyWith(...) 触发 UI 重建
///   - 数据获取通过 [BlitzRepository] 完成（不直接访问 DB 或 PhotoManager）
///   - 连拍分组通过 [BurstGroupingService] 完成（纯函数，无副作用）
///   - Controller 本身不执行任何 IO，是纯粹的协调者
class BlitzController extends Notifier<BlitzState> {
  /// 私有防重入标志
  bool _loadingInProgress = false;

  @override
  BlitzState build() {
    return const BlitzState(isLoading: true);
  }

  /// 获取 Repository（通过 Riverpod 依赖注入）
  BlitzRepository get _repository => ref.read(blitzRepositoryProvider);

  /// 获取连拍分组服务（通过 Riverpod 依赖注入）
  BurstGroupingService get _burstService =>
      ref.read(burstGroupingServiceProvider);

  // ============================================================
  // 核心逻辑 1：初始化与照片加载
  // ============================================================

  /// 从相册加载照片并执行连拍分组
  ///
  /// 完整流程（所有 IO 委托给 Repository）：
  ///   1. 请求相册权限 → Repository.requestPermission()
  ///   2. 获取未处理照片 → Repository.fetchUnprocessedPhotos()
  ///   3. 连拍分组 → 主线程或 isolate（根据照片数量自动切换）
  ///   4. 预加载缩略图 → Repository.preloadThumbnails()
  ///   5. 读取体力状态 → Repository.getUserEnergyStatus()
  ///   6. 更新 state
  ///
  /// Isolate 策略：
  ///   当照片数 > [_isolateThreshold] 时，分组计算自动卸载到后台 isolate，
  ///   避免大量照片的 O(n) 遍历阻塞 UI 线程导致掉帧。
  ///   详见 [_groupPhotos] 方法的文档。
  Future<void> loadPhotos() async {
    if (_loadingInProgress) return;
    _loadingInProgress = true;

    state = state.copyWith(
      isLoading: true,
      errorMessage: () => null,
    );

    try {
      // 1. 请求相册权限
      final hasPermission = await _repository.requestPermission();
      if (!hasPermission) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: () => '需要相册访问权限才能整理照片，请在设置中开启',
        );
        return;
      }

      // 2. 获取未处理的照片（扁平列表，由 Repository 负责去重）
      final flatPhotos = await _repository.fetchUnprocessedPhotos();
      if (flatPhotos.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          photoGroups: const [],
        );
        return;
      }

      // 3. 连拍分组（自动根据照片数量选择主线程或 isolate）
      //    groupBurstPhotos 要求输入按 createDateTime 升序排列，
      //    Repository 返回按创建时间降序的列表，此处反转为升序。
      final sortedPhotos = List<AssetEntity>.from(flatPhotos.reversed);
      final groups = await _groupPhotos(sortedPhotos);
      debugPrint('[BlitzController] 分组完成: ${groups.length} 组 '
          '(来自 ${flatPhotos.length} 张照片)');

      // 4. 预加载缩略图（委托给 Repository）
      final cache = await _repository.preloadThumbnails(flatPhotos);

      // 5. 读取用户体力状态
      final energyStatus = await _repository.getUserEnergyStatus();

      // 6. 更新状态
      state = state.copyWith(
        photoGroups: groups,
        currentGroupIndex: 0,
        currentEnergy: energyStatus.energy,
        isLoading: false,
        errorMessage: () => null,
        favorites: const [],
        skipped: const [],
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
  // Isolate 智能分组策略
  // ============================================================

  /// 照片数量超过此阈值时，分组计算自动卸载到 isolate
  static const int _isolateThreshold = 300;

  /// 智能连拍分组 — 自动选择执行策略
  ///
  /// 为什么需要 isolate：
  ///   虽然分组算法本身是 O(n)，但当 n > 300 时，
  ///   遍历 + 对象创建的累积耗时可能超过 16ms（一帧的预算），
  ///   尤其在低端 Android 设备上会导致明显卡顿。
  ///   将计算卸载到后台 isolate 可以完全避免 UI 掉帧。
  ///
  /// 为什么不总是用 isolate：
  ///   isolate 的启动和数据序列化/反序列化本身有 2-5ms 开销，
  ///   当照片数量较少（≤ 300）时，主线程直接执行更快。
  ///
  /// AssetEntity 跨 isolate 限制：
  ///   AssetEntity 内部持有平台通道引用，无法跨 isolate 传递。
  ///   因此采用以下策略：
  ///   1. 主线程提取 createDateTime 时间戳（轻量 int 列表）
  ///   2. isolate 中仅计算分组边界索引
  ///   3. 主线程根据边界索引从原始 AssetEntity 列表切片重建 PhotoGroup
  Future<List<PhotoGroup>> _groupPhotos(List<AssetEntity> sortedPhotos) async {
    if (sortedPhotos.length <= _isolateThreshold) {
      // 少量照片：主线程直接分组，避免 isolate 启动开销
      debugPrint('[BlitzController] 主线程分组 (${sortedPhotos.length} 张)');
      return _burstService.groupBurstPhotos(sortedPhotos);
    }

    // 大量照片：卸载到 isolate 执行
    debugPrint('[BlitzController] Isolate 分组 (${sortedPhotos.length} 张, '
        '超过阈值 $_isolateThreshold)');

    // 1. 提取时间戳（可跨 isolate 的基本类型）
    final timestamps = sortedPhotos
        .map((p) => p.createDateTime.millisecondsSinceEpoch)
        .toList();

    // 2. 在 isolate 中计算分组边界
    final boundaries = await compute(
      _computeBurstGroupBoundaries,
      _BurstGroupingParams(
        timestamps: timestamps,
        thresholdMs: _burstService.burstThresholdMs,
      ),
    );

    if (boundaries.isEmpty) return const [];

    // 3. 根据边界索引在主线程重建 PhotoGroup
    final List<PhotoGroup> groups = [];
    for (int i = 0; i < boundaries.length - 1; i++) {
      final start = boundaries[i];
      final end = boundaries[i + 1];
      groups.add(PhotoGroup(photos: sortedPhotos.sublist(start, end)));
    }

    return groups;
  }

  // ============================================================
  // 核心逻辑 2：交互（纯内存草稿，不碰数据库）
  // ============================================================

  /// 右滑操作 — 收藏照片
  ///
  /// 返回值：
  ///   - `true`  → 操作成功
  ///   - `false` → 体力不足，操作被拦截
  ///
  /// 体力扣除实时持久化到 DB（通过 UserStatsController），
  /// 防止用户反复进入退出来刷体力。
  Future<bool> swipeRight(AssetEntity photo) async {
    final bool isPro = state.currentEnergy == double.infinity;

    if (!isPro && state.currentEnergy < 1.0) {
      return false;
    }

    state = state.copyWith(
      currentEnergy: isPro ? state.currentEnergy : state.currentEnergy - 1.0,
      currentGroupIndex: state.currentGroupIndex + 1,
      favorites: [...state.favorites, photo],
      lastSwipedPhoto: () => photo,
      lastSwipeWasSkip: () => false,
      errorMessage: () => null,
    );

    // 异步扣除体力到 DB
    try {
      await ref.read(userStatsControllerProvider).consumeEnergy(1.0);
    } catch (e) {
      debugPrint('[BlitzController] 体力扣除失败: $e');
    }

    return true;
  }

  /// 左滑操作 — 跳过照片
  ///
  /// 返回值与 [swipeRight] 对称。
  Future<bool> swipeLeft(AssetEntity photo) async {
    final bool isPro = state.currentEnergy == double.infinity;

    if (!isPro && state.currentEnergy < 1.0) {
      return false;
    }

    state = state.copyWith(
      currentEnergy: isPro ? state.currentEnergy : state.currentEnergy - 1.0,
      currentGroupIndex: state.currentGroupIndex + 1,
      skipped: [...state.skipped, photo],
      lastSwipedPhoto: () => photo,
      lastSwipeWasSkip: () => true,
      errorMessage: () => null,
    );

    // 异步扣除体力到 DB
    try {
      await ref.read(userStatsControllerProvider).consumeEnergy(1.0);
    } catch (e) {
      debugPrint('[BlitzController] 体力扣除失败: $e');
    }

    return true;
  }

  // ============================================================
  // 核心逻辑 3：撤销与草稿管理
  // ============================================================

  /// 撤销上一次滑动操作（仅限最后一张）
  ///
  /// 返回值：
  ///   - `true`  → 撤销成功
  ///   - `false` → 无可撤销操作
  ///
  /// 执行完毕后将哨兵置为 null，强制锁死连续撤销。
  bool undoLastSwipe() {
    final photo = state.lastSwipedPhoto;
    if (photo == null) return false;

    final wasSkip = state.lastSwipeWasSkip ?? false;
    final isPro = state.currentEnergy == double.infinity;

    if (wasSkip) {
      final newSkipped = List<AssetEntity>.from(state.skipped)
        ..removeWhere((p) => p.id == photo.id);
      state = state.copyWith(
        currentEnergy: isPro ? state.currentEnergy : state.currentEnergy + 1.0,
        currentGroupIndex: state.currentGroupIndex - 1,
        skipped: newSkipped,
        lastSwipedPhoto: () => null,
        lastSwipeWasSkip: () => null,
      );
    } else {
      final newFavorites = List<AssetEntity>.from(state.favorites)
        ..removeWhere((p) => p.id == photo.id);
      state = state.copyWith(
        currentEnergy: isPro ? state.currentEnergy : state.currentEnergy + 1.0,
        currentGroupIndex: state.currentGroupIndex - 1,
        favorites: newFavorites,
        lastSwipedPhoto: () => null,
        lastSwipeWasSkip: () => null,
      );
    }

    // 异步退还体力到 DB
    try {
      ref.read(userStatsControllerProvider).consumeEnergy(-1.0);
    } catch (e) {
      debugPrint('[BlitzController] 体力退还失败: $e');
    }

    return true;
  }

  /// 清空本轮内存草稿（用户中途退出时调用）
  ///
  /// 体力已实时扣除到 DB，这是有意为之——防止刷体力。
  void clearSessionDraft() {
    state = state.copyWith(
      favorites: const [],
      skipped: const [],
      lastSwipedPhoto: () => null,
      lastSwipeWasSkip: () => null,
    );
  }

  /// 清空所有照片处理记录并重新加载
  ///
  /// 场景：用户点击"重新整理一次"。
  /// 委托给 Repository 执行数据库操作。
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
