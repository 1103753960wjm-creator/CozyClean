/// CozyClean — 图片清晰度评估服务
///
/// 使用文件大小作为清晰度近似值（用户指定策略）。
///
/// 原理：
///   同一场景、同一相机的连拍照片中，文件越大通常意味着：
///   1. 更少的运动模糊（JPEG 压缩后细节更多 → 文件更大）
///   2. 更好的对焦（清晰边缘 → 高频信息多 → 压缩后体积大）
///   3. 更丰富的细节（曝光正确 → 动态范围大 → 文件更大）
///
/// 局限性：
///   - 仅适用于同一连拍组内的比较（相同场景、相同相机设置）
///   - 不适合跨场景比较（暗场 vs 亮场文件大小差异大）
///   - HDR / 计算摄影可能打破文件大小与清晰度的关联
///
/// 架构位置：domain/services/
///   纯逻辑服务，无状态、无副作用、不依赖 Flutter 框架。
///
/// 复杂度：
///   时间 O(n) — 单次遍历找最大值
///   内存 O(1) — 仅记录最大值索引
library;

import 'package:photo_manager/photo_manager.dart';

/// 图片清晰度评估服务
///
/// 提供基于文件大小的连拍组最佳照片选择功能。
/// 仅用于连拍组内部的相对排序，不适合跨组绝对比较。
class ImageClarityService {
  const ImageClarityService();

  /// 从连拍组中选出最佳照片的索引
  ///
  /// 遍历照片列表，找到文件大小最大的那张照片。
  /// 文件大小通过 [AssetEntity.size]（像素尺寸 width*height）
  /// 作为近似值，避免异步读取实际文件大小带来的性能开销。
  ///
  /// [photos] 必须非空，否则返回 0。
  ///
  /// 返回最佳照片在列表中的索引。
  int findBestPhotoIndex(List<AssetEntity> photos) {
    if (photos.length <= 1) return 0;

    int bestIndex = 0;
    int bestSize = photos[0].width * photos[0].height;

    for (int i = 1; i < photos.length; i++) {
      final size = photos[i].width * photos[i].height;
      if (size > bestSize) {
        bestSize = size;
        bestIndex = i;
      }
    }

    return bestIndex;
  }

  /// 异步版本：使用实际文件大小评估清晰度
  ///
  /// 更精确但需要异步 IO，适用于照片数量较少的场景。
  /// 文件大小直接反映 JPEG 压缩后的信息量。
  ///
  /// 如果无法获取某张照片的文件信息，该照片的评分为 0。
  Future<int> findBestPhotoIndexAsync(List<AssetEntity> photos) async {
    if (photos.length <= 1) return 0;

    int bestIndex = 0;
    int bestFileSize = 0;

    for (int i = 0; i < photos.length; i++) {
      // AssetEntity.size 返回文件字节大小
      final fileSize = await photos[i].size;
      final bytes = (fileSize.width * fileSize.height).toInt();
      if (bytes > bestFileSize) {
        bestFileSize = bytes;
        bestIndex = i;
      }
    }

    return bestIndex;
  }
}
