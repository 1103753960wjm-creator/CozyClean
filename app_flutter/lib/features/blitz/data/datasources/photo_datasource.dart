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

import 'dart:io' show Platform;

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

  Future<int> _safeAlbumCount(AssetPathEntity album) async {
    try {
      final dynamic count = await (album as dynamic).assetCountAsync;
      if (count is int) return count;
    } catch (_) {
      // 平台实现差异时返回 unknown。
    }
    return -1;
  }

  String _albumLabel(AssetPathEntity album) {
    try {
      final dynamic dynamicAlbum = album;
      final dynamic name = dynamicAlbum.name;
      final dynamic id = dynamicAlbum.id;
      final safeName = name is String && name.isNotEmpty ? name : 'unknown';
      final safeId = id is String && id.isNotEmpty ? id : 'unknown';
      return '$safeName($safeId)';
    } catch (_) {
      return 'unknown';
    }
  }

  Future<AssetPathEntity?> _selectPrimaryAlbum(
      List<AssetPathEntity> albums) async {
    if (albums.isEmpty) return null;

    AssetPathEntity selected = albums.first;
    int selectedCount = await _safeAlbumCount(selected);

    for (int i = 1; i < albums.length; i++) {
      final candidate = albums[i];
      final candidateCount = await _safeAlbumCount(candidate);
      if (candidateCount > selectedCount) {
        selected = candidate;
        selectedCount = candidateCount;
      }
    }

    final countLabel = selectedCount >= 0 ? '$selectedCount' : 'unknown';
    debugPrint('[PhotoDataSource] 选择主相册: ${_albumLabel(selected)}, '
        'assetCount=$countLabel');
    return selected;
  }

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
  ///   - ✅ 获取相册列表 → 选择主相册 → 游标翻页抓取照片
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

      debugPrint('[PhotoDataSource] 相册总数: ${albums.length}');

      // 2. 选择主相册（优先资产数最多）
      final primaryAlbum = await _selectPrimaryAlbum(albums);
      if (primaryAlbum == null) {
        debugPrint('[PhotoDataSource] 主相册选择失败');
        return const [];
      }

      final primaryCount = await _safeAlbumCount(primaryAlbum);
      final countLabel = primaryCount >= 0 ? '$primaryCount' : 'unknown';
      debugPrint('[PhotoDataSource] 主相册开始读取: ${_albumLabel(primaryAlbum)}, '
          'maxCount=$maxCount, albumCount=$countLabel');

      // 3. 游标翻页抓取，直到凑够 maxCount 或相册见底
      final List<AssetEntity> result = [];
      int currentPage = 0;
      // 每页抓取量，与 maxCount 取较小值以避免过度请求
      final int pageSize = maxCount.clamp(1, 200);

      while (result.length < maxCount) {
        final batch = await primaryAlbum.getAssetListPaged(
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
          '(翻了 $currentPage 页, 主相册=${_albumLabel(primaryAlbum)})');
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

  /// 按 ID 列表加载照片实体。
  Future<List<AssetEntity>> loadAssetsByIds(List<String> ids) async {
    if (ids.isEmpty) return const <AssetEntity>[];

    try {
      final entities = await Future.wait(
        ids.map(AssetEntity.fromId),
      );

      final result = entities.whereType<AssetEntity>().toList(growable: false);
      debugPrint('[PhotoDataSource] 按 ID 回填成功: ${result.length}/${ids.length}');
      return result;
    } on PlatformException catch (e) {
      debugPrint('[PhotoDataSource] 按 ID 回填平台异常: $e');
      return const <AssetEntity>[];
    } catch (e, stackTrace) {
      debugPrint('[PhotoDataSource] 按 ID 回填异常: $e\n$stackTrace');
      return const <AssetEntity>[];
    }
  }

  /// 将照片移入回收站或执行删除。
  Future<List<String>> trashAssets(List<String> ids) async {
    if (ids.isEmpty) return const <String>[];

    try {
      await PhotoManager.clearFileCache();
      await Future.delayed(const Duration(milliseconds: 300));

      if (Platform.isAndroid) {
        try {
          final entities = await loadAssetsByIds(ids);
          if (entities.isEmpty) {
            return const <String>[];
          }
          return await PhotoManager.editor.android.moveToTrash(entities);
        } catch (e) {
          debugPrint(
              '[PhotoDataSource] Android moveToTrash 失败，降级 deleteWithIds: $e');
          return await PhotoManager.editor.deleteWithIds(ids);
        }
      }

      return await PhotoManager.editor.deleteWithIds(ids);
    } on PlatformException catch (e) {
      debugPrint('[PhotoDataSource] 删除平台异常: $e');
      return const <String>[];
    } catch (e, stackTrace) {
      debugPrint('[PhotoDataSource] 删除异常: $e\n$stackTrace');
      return const <String>[];
    }
  }
}
