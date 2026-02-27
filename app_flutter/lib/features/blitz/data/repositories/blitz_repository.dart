/// CozyClean — 闪电战数据仓库
///
/// Repository 模式说明：
///   Repository 是分层架构中 **数据层的核心抽象**，充当 Controller 与
///   底层数据源（DataSource、Database）之间的中间人。
///
///   Repository 的价值：
///   1. **解耦** — Controller 不需要知道数据来自 PhotoManager 还是数据库，
///      只调用 Repository 的高层接口即可
///   2. **组合** — 将多个 DataSource 的数据聚合（如相册照片 + 数据库记录），
///      提供统一的、已处理好的结果
///   3. **可测试性** — Mock Repository 即可隔离测试 Controller 逻辑，
///      无需真实相册或数据库
///   4. **缓存策略** — Repository 可选择性地缓存数据源结果，
///      减少重复 IO
///
/// 职责边界：
///   - ✅ 调用 PhotoDataSource 获取原始照片
///   - ✅ 查询/操作数据库中的照片处理记录
///   - ✅ 去重过滤（排除已处理过的照片）
///   - ✅ 批量预加载缩略图
///   - ❌ 不做连拍分组（由 domain/services 层负责）
///   - ❌ 不引用 UI 组件（pages/widgets）
///   - ❌ 不引用 domain/services 层
///
/// 返回值约定：
///   所有公开方法返回的是扁平的 `List<AssetEntity>`，
///   不包含任何分组结构。分组逻辑由调用方（Controller）
///   通过 BurstGroupingService 按需执行。
library;

import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

import 'package:cozy_clean/data/local/app_database.dart';
import 'package:cozy_clean/features/blitz/data/datasources/photo_datasource.dart';

/// 闪电战模式的数据仓库
///
/// 组合 [PhotoDataSource]（相册访问）和 [AppDatabase]（本地数据库），
/// 向 Controller 层提供已去重、可直接使用的照片列表。
///
/// 架构位置：
/// ```
/// Controller
///   ↓
/// Repository ← 你在这里
///   ↓          ↓
/// DataSource  Database
/// ```
class BlitzRepository {
  final PhotoDataSource _dataSource;
  final AppDatabase _db;

  BlitzRepository({
    required PhotoDataSource dataSource,
    required AppDatabase db,
  })  : _dataSource = dataSource,
        _db = db;

  // ============================================================
  // 相册权限
  // ============================================================

  /// 委托 DataSource 请求相册权限
  ///
  /// Repository 层本身不处理权限逻辑，仅做转发。
  /// 平台异常已在 DataSource 内部捕获。
  Future<bool> requestPermission() {
    return _dataSource.requestPermission();
  }

  // ============================================================
  // 照片获取与去重
  // ============================================================

  /// 获取未处理的照片列表（扁平结构，不分组）
  ///
  /// 流程：
  ///   1. 通过 DataSource 从相册加载原始照片
  ///   2. 查询数据库中已处理的照片 ID
  ///   3. 过滤掉已处理的照片
  ///   4. 截取至目标数量
  ///
  /// 返回值：
  ///   扁平的 `List<AssetEntity>`，按创建时间降序排列。
  ///   不包含任何分组信息 — 分组由 Controller 调用 Service 层完成。
  ///
  /// [targetCount] — 目标照片数量，默认 50
  /// [fetchCount] — 从相册抓取的照片数量（去重前），默认 200
  ///   fetchCount > targetCount 是为了留出去重余量。
  Future<List<AssetEntity>> fetchUnprocessedPhotos({
    int targetCount = 50,
    int fetchCount = 200,
  }) async {
    try {
      // 1. 从 DataSource 获取原始照片
      final rawPhotos = await _dataSource.loadAllPhotos(maxCount: fetchCount);
      if (rawPhotos.isEmpty) return const [];

      // 2. 查询已处理的照片 ID 集合
      final processedIds = await getProcessedPhotoIds();
      debugPrint('[BlitzRepository] 已处理照片数: ${processedIds.length}');

      // 3. 过滤掉已处理的照片
      final unprocessed =
          rawPhotos.where((p) => !processedIds.contains(p.id)).toList();

      // 4. 截取至目标数量
      final result = unprocessed.length > targetCount
          ? unprocessed.sublist(0, targetCount)
          : unprocessed;

      debugPrint('[BlitzRepository] ✅ 获取 ${result.length} 张未处理照片');
      return result;
    } catch (e) {
      debugPrint('[BlitzRepository] 获取未处理照片失败: $e');
      return const [];
    }
  }

  // ============================================================
  // 缩略图预加载
  // ============================================================

  /// 批量预加载照片缩略图到内存
  ///
  /// 编排策略：并发调用 DataSource 的 loadThumbnail，
  /// 将结果收集为 Map<photoId, Uint8List>。
  ///
  /// 内存安全：
  ///   使用 800x800 缩略图，50 张约 5-10MB，安全可控。
  ///   绝不加载原图（规范第 5、11 条）。
  Future<Map<String, Uint8List>> preloadThumbnails(
      List<AssetEntity> photos) async {
    final Map<String, Uint8List> cache = {};

    await Future.wait(
      photos.map((photo) async {
        final data = await _dataSource.loadThumbnail(photo);
        if (data != null) {
          cache[photo.id] = data;
        }
      }),
    );

    debugPrint('[BlitzRepository] ✅ 已预载 ${cache.length} 张缩略图');
    return cache;
  }

  // ============================================================
  // 数据库操作：照片处理记录
  // ============================================================

  /// 查询所有已处理过的照片 ID（包括 Keep 和 Delete）
  ///
  /// 查询全表，Keep + Delete 一律排除，
  /// 避免右滑保留的照片每次重复出现（"右滑幽灵" Bug）。
  Future<Set<String>> getProcessedPhotoIds() async {
    try {
      final rows = await _db.select(_db.photoActions).get();
      return rows.map((row) => row.id).toSet();
    } catch (e) {
      debugPrint('[BlitzRepository] 查询已处理照片失败: $e');
      return const {};
    }
  }

  /// 清空所有照片处理记录
  ///
  /// 场景：用户点击"重新整理一次"时，释放全部照片。
  /// 使用 Drift 类型安全 API，禁止原始 SQL 拼接（规范第 4 条）。
  Future<void> deleteAllPhotoActions() async {
    try {
      await _db.delete(_db.photoActions).go();
      debugPrint('[BlitzRepository] ✅ 已清空所有照片处理记录');
    } catch (e) {
      debugPrint('[BlitzRepository] 清空照片记录失败: $e');
    }
  }

  // ============================================================
  // 数据库操作：用户状态
  // ============================================================

  /// 读取用户的 Pro 会员状态和当前体力值
  ///
  /// 返回 Record 类型 (isPro, energy)。
  /// Pro 会员返回 (true, double.infinity)。
  Future<({bool isPro, double energy})> getUserEnergyStatus() async {
    try {
      final query = _db.select(_db.localUserStats)
        ..where((t) => t.uid.equals('default_user'));
      final stat = await query.getSingleOrNull();

      final bool isPro = stat?.isPro ?? false;
      final double energy =
          isPro ? double.infinity : (stat?.dailyEnergyRemaining ?? 50.0);

      return (isPro: isPro, energy: energy);
    } catch (e) {
      debugPrint('[BlitzRepository] 读取用户状态失败: $e');
      return (isPro: false, energy: 50.0);
    }
  }
}
