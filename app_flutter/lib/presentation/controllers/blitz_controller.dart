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
      print('[BlitzController] Step 3: 从相册 "${recentAlbum.name}" 加载照片...');
      final List<AssetEntity> rawPhotos = await recentAlbum.getAssetListPaged(
        page: 0,
        size: _fetchBatchSize,
      );
      print('[BlitzController] 加载到 ${rawPhotos.length} 张原始照片');

      // ---- 3. 查询已删除的照片 ID 集合 ----
      print('[BlitzController] Step 4: 查询已删除照片...');
      final deletedIds = await _getDeletedPhotoIds();
      print('[BlitzController] 已删除 ${deletedIds.length} 张');

      // ---- 4. 过滤：仅排除已标记删除的照片，保留的照片继续显示 ----
      final availablePhotos = rawPhotos
          .where((photo) => !deletedIds.contains(photo.id))
          .take(_targetPhotoCount)
          .toList();
      print('[BlitzController] 可显示 ${availablePhotos.length} 张照片');

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

  /// 从 Drift 数据库读取所有已标记为"删除"的照片 Asset ID
  /// 只排除 actionType=1 (Delete) 的照片，保留 actionType=0 (Keep) 的照片仍然可查看
  Future<Set<String>> _getDeletedPhotoIds() async {
    final rows = await (_db.select(_db.photoActions)
          ..where((t) => t.actionType.equals(1)))
        .get();
    return rows.map((row) => row.id).toSet();
  }

  // ====================================================
  // 核心逻辑 2：交互与落库
  // ====================================================

  /// 左滑操作 — 标记删除照片
  ///
  /// 业务规则：
  ///   1. 体力不足 1 点时，阻止操作（Pro 会员跳过此检查）
  ///   2. 将操作写入 Drift 数据库，标记 actionType = 1 (Delete)
  ///   3. 扣除 1 点体力，推进到下一张（Pro 会员不扣除）
  Future<void> swipeLeft(AssetEntity photo) async {
    if (!state.hasEnergy) {
      state = state.copyWith(
        errorMessage: () => '体力不足，请休息一下或观看广告恢复体力',
      );
      return;
    }

    // Pro 会员体力为 infinity，不需要扣减
    final bool isPro = state.currentEnergy == double.infinity;

    try {
      // 1. 同步进行乐观状态更新：体力 -1，索引 +1，记录并暂存删除照片
      // 极其重要：务必在 awaits _db 操作之前更新 state，否则快速连滑会导致旧 state 被缓存从而丢失滑动进度。
      state = state.copyWith(
        currentEnergy: isPro ? state.currentEnergy : state.currentEnergy - 1.0,
        currentIndex: state.currentIndex + 1,
        sessionDeletedPhotos: [
          ...state.sessionDeletedPhotos,
          photo
        ], // 暂存到本轮待处决列表
        errorMessage: () => null,
      );

      // 2. 异步写入 Drift 数据库：actionType = 1 代表 Delete
      await _db.into(_db.photoActions).insertOnConflictUpdate(
            PhotoActionsCompanion.insert(
              id: photo.id,
              actionType: 1, // Delete
            ),
          );

      // 3. 消费体力（Pro 会员在 consumeEnergy 内部会跳过）
      await ref.read(userStatsControllerProvider).consumeEnergy(1.0);
    } catch (e) {
      print('数据库写入报错：$e');
    }
  }

  /// 右滑操作 — 标记保留照片
  ///
  /// 业务规则与 swipeLeft 对称，actionType = 0 (Keep)
  /// Pro 会员不扣除体力
  Future<void> swipeRight(AssetEntity photo) async {
    if (!state.hasEnergy) {
      state = state.copyWith(
        errorMessage: () => '体力不足，请休息一下或观看广告恢复体力',
      );
      return;
    }

    // Pro 会员体力为 infinity，不需要扣减
    final bool isPro = state.currentEnergy == double.infinity;

    try {
      // 1. 同步进行乐观状态更新
      state = state.copyWith(
        currentEnergy: isPro ? state.currentEnergy : state.currentEnergy - 1.0,
        currentIndex: state.currentIndex + 1,
        errorMessage: () => null,
      );

      // 2. 异步写入 Drift 数据库：actionType = 0 代表 Keep
      await _db.into(_db.photoActions).insertOnConflictUpdate(
            PhotoActionsCompanion.insert(
              id: photo.id,
              actionType: 0, // Keep
            ),
          );

      // 3. 消费体力（Pro 会员在 consumeEnergy 内部会跳过）
      await ref.read(userStatsControllerProvider).consumeEnergy(1.0);
    } catch (e) {
      print('数据库写入报错：$e');
    }
  }

  // ====================================================
  // 核心逻辑 3：滑动窗口内存控制
  // ====================================================

  /// 判断指定索引的照片是否应该被缓存（加载原图到内存）
  ///
  /// 滑动窗口策略说明：
  /// ```
  /// 照片序列:  ... [i-2] [i-1] [i] [i+1] [i+2] [i+3] ...
  /// 缓存窗口:         ✅    ✅   ✅   ✅
  ///                  prev  curr  next next+1
  /// ```
  ///
  /// 窗口范围 = [currentIndex - 1, currentIndex + 2]
  ///
  /// 为什么保留前 1 张：
  ///   用户可能需要"撤销"操作，回看上一张。缓存前 1 张可以实现无延迟回退。
  ///
  /// 为什么预加载后 2 张：
  ///   用户快速滑动时，至少有 2 张照片已经在内存中，
  /// 判定某张卡片是否应当触发实际加载 (防 OOM 策略)
  ///
  /// 规则：
  /// 保留前 1 张 (备用撤销)，以及当前显示的卡片，和紧接着的后续 3 张卡片。
  /// 其他处于更深处的卡片只渲染空骨架屏 (Skeleton)。
  bool shouldCacheImage(int index) {
    if (state.photos.isEmpty) return false;

    final lower = state.currentIndex - 1;
    final upper = state.currentIndex + 3; // 深度延伸至后 3 张

    return index >= lower && index <= upper;
  }
}
