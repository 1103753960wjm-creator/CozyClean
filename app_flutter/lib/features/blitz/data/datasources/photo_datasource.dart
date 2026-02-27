/// CozyClean — 相册数据源
///
/// 数据源层（DataSource），仅负责与系统相册 API（PhotoManager）交互。
///
/// 职责分离说明：
///   本类是分层架构中最底层的数据获取组件，职责边界严格限定为：
///   1. 请求相册访问权限
///   2. 从 PhotoManager 获取原始照片列表
///
///   本类 **不负责** 以下逻辑（由上层组件处理）：
///   - 连拍分组 → BurstGroupingService（domain/services 层）
///   - 去重过滤 → BlitzRepository（data/repositories 层）
///   - 缩略图预加载 → BlitzRepository（data/repositories 层）
///   - 状态管理 → BlitzController（application/controllers 层）
///
///   这样做的原因：
///   - 单一职责原则：每层只做一件事，便于独立测试和替换
///   - 可测试性：Mock PhotoManager 时只需替换本类，不牵连业务逻辑
///   - 平台隔离：所有平台相关的 try/catch 容错集中在此处
///
/// 平台安全：
///   所有 PhotoManager 调用均包裹 try/catch，
///   防止平台通道异常导致 App 崩溃（规范第 10、15 条）。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

/// 相册数据源 — 与 PhotoManager 交互的唯一入口
///
/// 设计为无状态类，所有方法均为独立操作，不持有缓存或会话信息。
///
/// 架构位置：
/// ```
/// UI (pages/widgets)
///   ↓ 调用
/// Controller (application/controllers)
///   ↓ 调用
/// Repository (data/repositories)
///   ↓ 调用
/// DataSource (data/datasources) ← 你在这里
///   ↓ 调用
/// PhotoManager (系统相册 SDK)
/// ```
class PhotoDataSource {
  const PhotoDataSource();

  /// 请求并检查相册访问权限
  ///
  /// 返回值：
  ///   - `true`  → 用户已授予相册访问权限
  ///   - `false` → 权限被拒绝或请求过程中发生异常
  ///
  /// 平台差异：
  ///   - iOS：首次调用弹出系统权限弹窗，用户选择后缓存结果
  ///   - Android：根据版本可能需要 READ_EXTERNAL_STORAGE 或
  ///     READ_MEDIA_IMAGES 权限
  ///
  /// 异常处理：
  ///   PlatformException 等运行时异常会被捕获并返回 false，
  ///   不会向上层抛出，保证 App 不崩溃。
  Future<bool> requestPermission() async {
    try {
      final permission = await PhotoManager.requestPermissionExtend();
      debugPrint('[PhotoDataSource] 权限结果: ${permission.isAuth}');
      return permission.isAuth;
    } on PlatformException catch (e) {
      debugPrint('[PhotoDataSource] 权限请求平台异常: $e');
      return false;
    } catch (e) {
      debugPrint('[PhotoDataSource] 权限请求未知异常: $e');
      return false;
    }
  }

  /// 从系统相册加载全部照片（按创建时间降序）
  ///
  /// **功能边界：**
  ///   - ✅ 获取相册列表 → 取第一个相册 → 游标翻页抓取照片
  ///   - ❌ 不做连拍分组（由 BurstGroupingService 负责）
  ///   - ❌ 不做去重过滤（由 Repository 负责）
  ///   - ❌ 不做缩略图加载（由 Repository 负责）
  ///
  /// **参数：**
  ///   [maxCount] — 最多获取的照片数量，防止一次性加载海量数据导致 OOM。
  ///   默认 200 张，Controller 层可根据策略调整。
  ///
  /// **返回值：**
  ///   按创建时间降序排列的 [AssetEntity] 列表。
  ///   AssetEntity 是轻量级引用，不会加载原图到内存。
  ///   出错时返回空列表。
  ///
  /// **异常处理：**
  ///   - PlatformException → 平台通道异常（如权限被收回）
  ///   - 其他异常 → 兜底捕获
  ///   所有异常均记录日志并返回空列表，不向上抛出。
  Future<List<AssetEntity>> loadAllPhotos({int maxCount = 200}) async {
    try {
      // 1. 获取相册列表
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

      if (albums.isEmpty) {
        debugPrint('[PhotoDataSource] 未找到任何相册');
        return const [];
      }

      // 2. 取第一个相册（通常是"所有照片" / "最近项目"）
      final recentAlbum = albums.first;

      // 3. 游标翻页抓取，直到凑够 maxCount 或相册见底
      final List<AssetEntity> result = [];
      int currentPage = 0;
      // 每页抓取量，与 maxCount 取较小值以避免过度请求
      final int pageSize = maxCount.clamp(1, 200);

      while (result.length < maxCount) {
        final batch = await recentAlbum.getAssetListPaged(
          page: currentPage,
          size: pageSize,
        );

        if (batch.isEmpty) {
          debugPrint('[PhotoDataSource] 相册已见底 (第 $currentPage 页)');
          break;
        }

        result.addAll(batch);
        currentPage++;
      }

      // 防御性截取：若超出目标数量则截取
      final photos =
          result.length > maxCount ? result.sublist(0, maxCount) : result;

      debugPrint('[PhotoDataSource] ✅ 加载 ${photos.length} 张照片 '
          '(翻了 $currentPage 页)');
      return photos;
    } on PlatformException catch (e) {
      debugPrint('[PhotoDataSource] 加载照片平台异常: $e');
      return const [];
    } catch (e, stackTrace) {
      debugPrint('[PhotoDataSource] 加载照片未知异常: $e\n$stackTrace');
      return const [];
    }
  }

  /// 为单张照片加载缩略图数据
  ///
  /// **功能边界：**
  ///   仅负责调用 PhotoManager 的缩略图 API，
  ///   批量预加载策略由 Repository 层编排。
  ///
  /// **内存安全：**
  ///   使用 ThumbnailSize 限制分辨率为 [width] x [height]，
  ///   绝不加载原图（规范第 5、11 条）。
  ///
  /// **返回值：**
  ///   成功返回 Uint8List 缩略图数据，失败返回 null。
  Future<Uint8List?> loadThumbnail(
    AssetEntity photo, {
    int width = 800,
    int height = 800,
  }) async {
    try {
      return await photo.thumbnailDataWithSize(
        ThumbnailSize(width, height),
      );
    } on PlatformException catch (e) {
      debugPrint('[PhotoDataSource] 缩略图加载平台异常 (${photo.id}): $e');
      return null;
    } catch (e) {
      debugPrint('[PhotoDataSource] 缩略图加载异常 (${photo.id}): $e');
      return null;
    }
  }
}
