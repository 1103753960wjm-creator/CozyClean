/// CozyClean — 闪电战核心控制器
///
/// 使用 Riverpod 的 Notifier 模式管理 BlitzState。
/// 职责：
///   1. 从系统相册加载照片并去重（排除已处理过的）
///   2. 处理用户的左滑 (Delete) / 右滑 (Keep) 操作
///   3. 提供滑动窗口缓存策略函数
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import 'package:cozy_clean/data/local/app_database.dart';
import 'package:cozy_clean/presentation/controllers/blitz_state.dart';

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

  @override
  BlitzState build() {
    // 初始状态：空列表、未加载
    return const BlitzState();
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
    if (state.isLoading) return;

    state = state.copyWith(
      isLoading: true,
      errorMessage: () => null,
    );

    try {
      // ---- 1. 检查并请求相册权限 ----
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.isAuth) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: () => '需要相册访问权限才能整理照片，请在设置中开启',
        );
        return;
      }

      // ---- 2. 获取"最近"相册中的照片 ----
      // 为什么只取图片类型：闪电战模式专注于照片整理，视频在后续模式中处理
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        filterOption: FilterOptionGroup(
          orders: [
            const OrderOption(
              type: OrderOptionType.createDate,
              asc: false, // 最新的照片排在前面
            ),
          ],
        ),
      );

      if (albums.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: () => '相册中没有找到照片',
        );
        return;
      }

      // 取第一个相册（通常是"所有照片"/"最近项目"）
      final recentAlbum = albums.first;
      final List<AssetEntity> rawPhotos = await recentAlbum.getAssetListPaged(
        page: 0,
        size: _fetchBatchSize,
      );

      // ---- 3. 查询已处理过的照片 ID 集合 ----
      // 为什么从数据库读取 Set 而不是逐条查询：
      //   批量读取一次，O(1) 查找，比逐条 SELECT 高效得多。
      final processedIds = await _getProcessedPhotoIds();

      // ---- 4. 过滤去重：排除已经 Keep/Delete 过的照片 ----
      final unprocessedPhotos = rawPhotos
          .where((photo) => !processedIds.contains(photo.id))
          .take(_targetPhotoCount)
          .toList();

      // ---- 5. 更新状态 ----
      state = state.copyWith(
        photos: unprocessedPhotos,
        currentIndex: 0,
        isLoading: false,
        errorMessage: () => null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: () => '加载照片失败: $e',
      );
    }
  }

  /// 从 Drift 数据库读取所有已处理过的照片 Asset ID
  Future<Set<String>> _getProcessedPhotoIds() async {
    final query = _db.select(_db.photoActions)
      ..addColumns([_db.photoActions.id]);
    final rows = await query.get();
    return rows.map((row) => row.id).toSet();
  }

  // ====================================================
  // 核心逻辑 2：交互与落库
  // ====================================================

  /// 左滑操作 — 标记删除照片
  ///
  /// 业务规则：
  ///   1. 体力不足 1 点时，阻止操作
  ///   2. 将操作写入 Drift 数据库，标记 actionType = 1 (Delete)
  ///   3. 扣除 1 点体力，推进到下一张
  Future<void> swipeLeft(AssetEntity photo) async {
    if (!state.hasEnergy) {
      state = state.copyWith(
        errorMessage: () => '体力不足，请休息一下或观看广告恢复体力',
      );
      return;
    }

    try {
      // 写入 Drift 数据库：actionType = 1 代表 Delete
      await _db.into(_db.photoActions).insertOnConflictUpdate(
            PhotoActionsCompanion.insert(
              id: photo.id,
              actionType: 1, // Delete
            ),
          );

      // 更新状态：体力 -1，索引 +1
      state = state.copyWith(
        currentEnergy: state.currentEnergy - 1.0,
        currentIndex: state.currentIndex + 1,
        errorMessage: () => null,
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage: () => '操作失败: $e',
      );
    }
  }

  /// 右滑操作 — 标记保留照片
  ///
  /// 业务规则与 swipeLeft 对称，actionType = 0 (Keep)
  Future<void> swipeRight(AssetEntity photo) async {
    if (!state.hasEnergy) {
      state = state.copyWith(
        errorMessage: () => '体力不足，请休息一下或观看广告恢复体力',
      );
      return;
    }

    try {
      // 写入 Drift 数据库：actionType = 0 代表 Keep
      await _db.into(_db.photoActions).insertOnConflictUpdate(
            PhotoActionsCompanion.insert(
              id: photo.id,
              actionType: 0, // Keep
            ),
          );

      // 更新状态：体力 -1，索引 +1
      state = state.copyWith(
        currentEnergy: state.currentEnergy - 1.0,
        currentIndex: state.currentIndex + 1,
        errorMessage: () => null,
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage: () => '操作失败: $e',
      );
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
  ///   避免滑动到下一张时出现白屏/loading 闪烁。
  ///
  /// 为什么不缓存更多：
  ///   手机内存有限，原图可能每张 3-10MB，缓存 4 张约 12-40MB。
  ///   超过这个范围性价比急剧下降，还会触发系统内存警告。
  bool shouldCacheImage(int index) {
    final lower = state.currentIndex - 1;
    final upper = state.currentIndex + 2;
    return index >= lower && index <= upper;
  }
}
