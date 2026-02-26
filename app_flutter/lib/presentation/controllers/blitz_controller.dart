/// CozyClean — 闪电战核心控制器
///
/// 使用 Riverpod 的 Notifier 模式管理 BlitzState。
/// 职责：
///   1. 从系统相册加载照片并去重（排除已处理过的）
///   2. 处理用户的左滑 (Delete) / 右滑 (Keep) 操作
///   3. 提供滑动窗口缓存策略函数
library;

import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import 'package:cozy_clean/data/local/app_database.dart';
import 'package:cozy_clean/presentation/controllers/blitz_state.dart';
import 'package:cozy_clean/presentation/controllers/user_stats_controller.dart';

// ============================================
// Riverpod Provider 定义
// ============================================

/// AppDatabase 的全局 Provider
/// 为什么用 Provider 而不是在控制器内部直接 new：
///   方便测试时 Mock 替换，且保证全局单例。
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

/// 闪电战控制器的 Provider
/// 使用 NotifierProvider 让 Riverpod 管理控制器的生命周期。
final blitzControllerProvider =
    NotifierProvider<BlitzController, BlitzState>(BlitzController.new);

// ============================================
// 闪电战控制器
// ============================================

/// 闪电战 (Blitz Mode) 核心引擎控制器
///
/// 设计原则：
///   - 所有状态变更通过 state = state.copyWith(...) 触发 UI 重建
///   - 数据库操作通过依赖注入的 AppDatabase 完成（可测试性）
///   - 照片加载采用"先去重再截取"策略，保证每次展示的都是未处理过的
class BlitzController extends Notifier<BlitzState> {
  /// 每次加载的照片批次大小
  /// 为什么是 200 而不是 50：
  ///   从相册取 200 张，去重后预期剩余约 50 张。
  ///   如果直接取 50 张，去重后可能只剩几张，用户体验差。
  static const int _fetchBatchSize = 200;

  /// 目标保留的未处理照片数量
  static const int _targetPhotoCount = 50;

  /// 私有防重入标志，避免与 state.isLoading 初始值冲突
  bool _loadingInProgress = false;

  @override
  BlitzState build() {
    // 初始状态：标记为加载中，由 UI 层 (BlitzPage) 的 initState 触发 loadPhotos()
    return const BlitzState(isLoading: true);
  }

  /// 获取注入的数据库实例
  AppDatabase get _db => ref.read(appDatabaseProvider);

  // ====================================================
  // 核心逻辑 1：初始化与相册读取
  // ====================================================

  /// 从系统相册加载照片，并去除已处理过的照片
  ///
  /// 流程：
  /// 1. 请求相册权限
  /// 2. 获取"最近"相册的照片（按时间倒序）
  /// 3. 查询 Drift 数据库中已有的 PhotoAction 记录
  /// 4. 过滤掉已处理的照片，保留 [_targetPhotoCount] 张
  /// 5. 更新 state
  Future<void> loadPhotos() async {
    // 防止重复加载
    // 防止重复加载（使用独立标志而非 state.isLoading，避免与 build() 初始值冲突）
    if (_loadingInProgress) return;
    _loadingInProgress = true;

    state = state.copyWith(
      isLoading: true,
      errorMessage: () => null,
    );

    try {
      // ---- 1. 检查并请求相册权限 ----
      print('[BlitzController] Step 1: 请求相册权限...');
      final permission = await PhotoManager.requestPermissionExtend();
      print('[BlitzController] 权限结果: ${permission.isAuth}, 状态: $permission');
      if (!permission.isAuth) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: () => '需要相册访问权限才能整理照片，请在设置中开启',
        );
        return;
      }

      // ---- 2. 获取"最近"相册中的照片 ----
      print('[BlitzController] Step 2: 获取相册列表...');
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        filterOption: FilterOptionGroup(
          orders: [
            const OrderOption(
              type: OrderOptionType.createDate,
              asc: false,
            ),
          ],
        ),
      );
      print('[BlitzController] 找到 ${albums.length} 个相册');

      if (albums.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: () => '相册中没有找到照片',
        );
        return;
      }

      // 取第一个相册（通常是"所有照片"/"最近项目"）
      final recentAlbum = albums.first;

      // ---- 3 & 4. 游标翻页抓取与去重过滤 ----
      print('[BlitzController] Step 3&4: 智能翻页抓取未处理照片...');
      final processedIds = await _getProcessedPhotoIds();
      print('[BlitzController] 数据库中已记录 ${processedIds.length} 张已处理照片');

      List<AssetEntity> availablePhotos = [];
      int currentPage = 0;

      // 只要还没凑够目标数量，就不断往相册深处翻页
      while (availablePhotos.length < _targetPhotoCount) {
        final batch = await recentAlbum.getAssetListPaged(
          page: currentPage,
          size: _fetchBatchSize,
        );

        if (batch.isEmpty) {
          print('[BlitzController] 相册已见底，停止抓取');
          break; // 没有更多照片了
        }

        // 筛选出尚未处理过的照片（Keep + Delete 均排除）
        final unhandled = batch.where((p) => !processedIds.contains(p.id));
        availablePhotos.addAll(unhandled);
        currentPage++;
      }

      // 防御性截取：仅在超出目标数量时截取，避免 RangeError
      if (availablePhotos.length > _targetPhotoCount) {
        availablePhotos = availablePhotos.sublist(0, _targetPhotoCount);
      }
      print(
          '[BlitzController] 最终捞取到 ${availablePhotos.length} 张可展示照片 (翻了 $currentPage 页)');

      // ---- 5. 批量预加载所有缩略图到内存缓存 ----
      // 这是消灭闪烁的终极方案！在此阶段一次性读取全部缩略图的 Uint8List，
      // 之后 PhotoCard 直接同步渲染，不再使用任何 FutureBuilder！
      // 50 张 800x800 缩略图约 5-10MB，完全在安全范围内。
      print('[BlitzController] Step 5: 预加载全部缩略图...');
      final Map<String, Uint8List> cache = {};
      await Future.wait(
        availablePhotos.map((photo) async {
          final data = await photo.thumbnailDataWithSize(
            const ThumbnailSize(800, 800),
          );
          if (data != null) {
            cache[photo.id] = data;
          }
        }),
      );
      print('[BlitzController] ✅ 已预载 ${cache.length} 张缩略图到内存');

      // ---- 5.5 读取真实体力值与会员状态 ----
      final query = _db.select(_db.localUserStats)
        ..where((t) => t.uid.equals('default_user'));
      final userStat = await query.getSingleOrNull();

      // Pro 会员 → 无限体力 (double.infinity)
      // 普通用户 → 读取数据库中的真实剩余体力
      final bool isPro = userStat?.isPro ?? false;
      final double initialEnergy =
          isPro ? double.infinity : (userStat?.dailyEnergyRemaining ?? 50.0);

      // ---- 6. 更新状态 ----
      state = state.copyWith(
        photos: availablePhotos,
        currentIndex: 0,
        currentEnergy: initialEnergy,
        isLoading: false,
        errorMessage: () => null,
        sessionDeletedPhotos: const [], // 初始化时清空本轮的暂存记录
        thumbnailCache: cache,
        sessionKeeps: const {}, // 清空内存草稿
        sessionDeletes: const {}, // 清空内存草稿
      );
      print('[BlitzController] ✅ 加载完成!');
    } catch (e, stackTrace) {
      print('[BlitzController] ❌ 加载失败: $e\n$stackTrace');
      state = state.copyWith(
        isLoading: false,
        errorMessage: () => '加载照片失败: $e',
      );
    } finally {
      _loadingInProgress = false;
    }
  }

  /// 查询所有已处理过（包括保留和删除）的照片 ID，避免重复进入整理队列
  ///
  /// 核心修复：旧代码只过滤 Delete，导致 Keep 照片每次重复出现（"右滑幽灵"Bug）。
  /// 现在查询全表，Keep + Delete 一律排除。
  Future<Set<String>> _getProcessedPhotoIds() async {
    final rows = await _db.select(_db.photoActions).get();
    return rows.map((row) => row.id).toSet();
  }

  // ====================================================
  // 核心逻辑 2：交互（纯内存草稿，不碰数据库）
  // ====================================================

  /// 左滑操作 — 标记删除照片（仅写入内存草稿）
  ///
  /// 返回值：
  ///   - `true`  → 操作成功，已记录到草稿
  ///   - `false` → 体力不足，操作被拦截（UI 层据此弹回卡片）
  ///
  /// 业务规则：
  ///   1. 非 Pro 用户且体力 ≤ 0 → 返回 false，不更新任何状态
  ///   2. 将 photo.id 写入 state.sessionDeletes（内存 Set）
  ///   3. 将 AssetEntity 追加到 sessionDeletedPhotos（结算页动画用）
  ///   4. 扣除 1 点体力并实时持久化到 DB（防止刷体力漏洞）
  Future<bool> swipeLeft(AssetEntity photo) async {
    final bool isPro = state.currentEnergy == double.infinity;

    // 体力拦截：非 Pro 且无体力 → 立即返回 false
    if (!isPro && state.currentEnergy < 1.0) {
      state = state.copyWith(
        errorMessage: () => '体力不足，请休息一下或观看广告恢复体力',
      );
      return false;
    }

    // 1. 同步更新内存草稿 + 状态
    // 极其重要：务必在 await 之前更新 state，否则快速连滑会丢失进度
    state = state.copyWith(
      currentEnergy: isPro ? state.currentEnergy : state.currentEnergy - 1.0,
      currentIndex: state.currentIndex + 1,
      sessionDeletes: {...state.sessionDeletes, photo.id},
      sessionDeletedPhotos: [...state.sessionDeletedPhotos, photo],
      lastSwipedPhoto: () => photo,
      lastSwipeWasDelete: () => true,
      errorMessage: () => null,
    );

    // 2. 异步扣除体力到 DB（Pro 会员在 consumeEnergy 内部跳过）
    try {
      await ref.read(userStatsControllerProvider).consumeEnergy(1.0);
    } catch (e) {
      print('[BlitzController] 体力扣除失败: $e');
    }

    return true;
  }

  /// 右滑操作 — 标记保留照片（仅写入内存草稿）
  ///
  /// 返回值与 swipeLeft 对称：
  ///   - `true`  → 操作成功
  ///   - `false` → 体力不足，被拦截
  Future<bool> swipeRight(AssetEntity photo) async {
    final bool isPro = state.currentEnergy == double.infinity;

    // 体力拦截
    if (!isPro && state.currentEnergy < 1.0) {
      state = state.copyWith(
        errorMessage: () => '体力不足，请休息一下或观看广告恢复体力',
      );
      return false;
    }

    // 1. 同步更新内存草稿 + 状态
    state = state.copyWith(
      currentEnergy: isPro ? state.currentEnergy : state.currentEnergy - 1.0,
      currentIndex: state.currentIndex + 1,
      sessionKeeps: {...state.sessionKeeps, photo.id},
      lastSwipedPhoto: () => photo,
      lastSwipeWasDelete: () => false,
      errorMessage: () => null,
    );

    // 2. 异步扣除体力到 DB
    try {
      await ref.read(userStatsControllerProvider).consumeEnergy(1.0);
    } catch (e) {
      print('[BlitzController] 体力扣除失败: $e');
    }

    return true;
  }

  // ====================================================
  // 核心逻辑 3：草稿回滚
  // ====================================================

  /// 清空本轮内存草稿（用户中途退出时调用）
  ///
  /// 由于滑动阶段不写库，调用此方法后数据库中不会残留任何
  /// "幽灵废片"记录，本次操作等于从未发生过。
  ///
  /// 注意：体力已实时扣除到 DB，这是有意为之的——
  /// 防止用户反复进入退出来刷体力。
  void clearSessionDraft() {
    state = state.copyWith(
      sessionKeeps: const {},
      sessionDeletes: const {},
      sessionDeletedPhotos: const [],
      lastSwipedPhoto: () => null,
      lastSwipeWasDelete: () => null,
    );
  }

  // ====================================================
  // 核心逻辑 3.5：单步撤销
  // ====================================================

  /// 撤销上一次滑动操作（仅限最后一张）
  ///
  /// 返回值：
  ///   - `true`  → 撤销成功，状态已回滚
  ///   - `false` → 无可撤销操作（UI 层据此弹 Toast）
  ///
  /// 安全机制：执行完毕后将 lastSwipedPhoto 置为 null，
  /// 强制锁死连续撤销。
  bool undoLastSwipe() {
    final photo = state.lastSwipedPhoto;
    if (photo == null) return false;

    final wasDelete = state.lastSwipeWasDelete ?? false;
    final isPro = state.currentEnergy == double.infinity;

    // 1. 从对应的内存草稿中移除
    final newDeletes = Set<String>.from(state.sessionDeletes);
    final newKeeps = Set<String>.from(state.sessionKeeps);
    List<AssetEntity> newDeletedPhotos = List.from(state.sessionDeletedPhotos);

    if (wasDelete) {
      newDeletes.remove(photo.id);
      newDeletedPhotos.removeWhere((p) => p.id == photo.id);
    } else {
      newKeeps.remove(photo.id);
    }

    // 2. 回滚状态：体力 +1，索引 -1，哨兵置 null
    state = state.copyWith(
      currentEnergy: isPro ? state.currentEnergy : state.currentEnergy + 1.0,
      currentIndex: state.currentIndex - 1,
      sessionDeletes: newDeletes,
      sessionKeeps: newKeeps,
      sessionDeletedPhotos: newDeletedPhotos,
      lastSwipedPhoto: () => null,
      lastSwipeWasDelete: () => null,
      errorMessage: () => null,
    );

    // 3. 异步退还体力到 DB（Pro 会员在 consumeEnergy 内部跳过）
    try {
      ref.read(userStatsControllerProvider).consumeEnergy(-1.0);
    } catch (e) {
      print('[BlitzController] 体力退还失败: $e');
    }

    return true;
  }

  // ====================================================
  // 核心逻辑 4：滑动窗口内存控制
  // ====================================================

  /// 判定某张卡片是否应当触发实际加载 (防 OOM 策略)
  ///
  /// 规则：
  /// 保留前 1 张 (备用撤销)，以及当前显示的卡片，和紧接着的后续 3 张卡片。
  /// 其他处于更深处的卡片只渲染空骨架屏 (Skeleton)。
  bool shouldCacheImage(int index) {
    if (state.photos.isEmpty) return false;

    final lower = state.currentIndex - 1;
    final upper = state.currentIndex + 3;

    return index >= lower && index <= upper;
  }
}
