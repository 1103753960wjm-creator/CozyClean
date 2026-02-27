/// CozyClean — 连拍照片分组领域模型
///
/// 闪电战模式的核心领域概念之一：将时间上相邻的照片聚合为"连拍组"。
///
/// 设计目的：
///   在手机相册中，用户经常连续按下快门拍摄同一场景，
///   产生大量高度相似的照片。[PhotoGroup] 将这些照片聚合为一组，
///   便于用户一次性审阅和批量处理，而非逐张滑动。
///
/// 不可变性保证：
///   - 所有字段均为 final
///   - [photos] 列表在构造时通过 [List.unmodifiable] 冻结，
///     外部代码无法通过引用执行 add / remove / clear 等修改操作
///   - 符合 Riverpod 状态管理规范：状态中的集合必须不可变
///
/// 内存安全：
///   - [photos] 中存储的是 [AssetEntity] 轻量级引用，
///     不会加载原图到内存（原图仅在详情页/生成海报时按需加载）
///   - 整个分组结构的内存开销 ≈ N 个 AssetEntity 指针 + 2 个 int/bool
///   - 即使 1000 组也不会造成内存压力
library;

import 'package:photo_manager/photo_manager.dart';

/// 连拍照片分组
///
/// 每个实例代表一组在时间上相邻的照片（连拍组）或一张独立照片。
/// 由 [BurstGroupingService.groupBurstPhotos] 生成。
///
/// 使用示例：
/// ```dart
/// final group = PhotoGroup(
///   photos: [photo1, photo2, photo3],
///   bestIndex: 1, // photo2 为最佳照片
/// );
///
/// print(group.isBurst);        // true（多于 1 张）
/// print(group.bestPhoto);      // photo2
/// print(group.photos.length);  // 3
///
/// // 以下操作会在运行时抛出 UnsupportedError：
/// // group.photos.add(newPhoto); ← 禁止！列表不可变
/// ```
class PhotoGroup {
  /// 该组中的照片列表（按创建时间排序，不可变）
  ///
  /// 通过 [List.unmodifiable] 冻结，任何尝试修改此列表的操作
  /// 都会抛出 [UnsupportedError]，从源头杜绝状态突变。
  final List<AssetEntity> photos;

  /// 最佳照片在 [photos] 中的索引
  ///
  /// 初始值默认为 0（取第一张）。
  /// 未来可通过图像质量评估算法（锐度、曝光、构图等）
  /// 自动选出最佳候选，或由用户手动指定。
  final int bestIndex;

  /// 是否为连拍组
  ///
  /// 当 [photos] 中包含多于 1 张照片时为 true。
  /// UI 层可据此决定是否展示"连拍标记"或"批量操作"入口。
  final bool isBurst;

  /// 创建一个不可变的照片分组
  ///
  /// [photos] 会被 [List.unmodifiable] 包装，即使传入可变列表，
  /// 实例内部持有的也是冻结后的不可变视图。
  ///
  /// [bestIndex] 默认为 0，必须在 [0, photos.length) 范围内。
  ///
  /// [isBurst] 当未显式传入时，根据 photos.length > 1 自动推断。
  PhotoGroup({
    required List<AssetEntity> photos,
    this.bestIndex = 0,
    bool? isBurst,
  })  : photos = List<AssetEntity>.unmodifiable(photos),
        isBurst = isBurst ?? photos.length > 1,
        assert(photos.isNotEmpty, 'PhotoGroup 不能包含空照片列表'),
        assert(
          bestIndex >= 0 && bestIndex < photos.length,
          'bestIndex ($bestIndex) 越界，photos 长度为 ${photos.length}',
        );

  /// 获取最佳照片（由 [bestIndex] 指定）
  ///
  /// 这是 UI 层展示该分组时应优先使用的代表照片。
  AssetEntity get bestPhoto => photos[bestIndex];

  /// 该组的照片数量
  int get count => photos.length;

  @override
  String toString() =>
      'PhotoGroup(count: $count, isBurst: $isBurst, bestIndex: $bestIndex)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoGroup &&
          runtimeType == other.runtimeType &&
          photos.length == other.photos.length &&
          bestIndex == other.bestIndex &&
          isBurst == other.isBurst;

  @override
  int get hashCode => Object.hash(photos.length, bestIndex, isBurst);
}
