/// CozyClean — 闪电战引擎状态模型
///
/// 纯 Dart 不可变状态类（不使用 Freezed，减少依赖冲突）。
/// 通过 copyWith 模式实现 Riverpod 状态更新，保持状态不可变性。
library;

import 'package:photo_manager/photo_manager.dart';

/// 闪电战 (Blitz Mode) 的引擎状态
///
/// 状态流转示意：
/// ```
/// isLoading=true → 加载相册 → photos 填充 → isLoading=false
///                                          → 用户滑动 → currentIndex++ & energy--
///                                          → energy==0 → 提示体力耗尽
/// ```
class BlitzState {
  /// 当前加载的未处理照片列表
  /// 为什么用 AssetEntity 而不是 File：
  ///   AssetEntity 是轻量级引用，不会立即加载原图到内存，
  ///   配合滑动窗口的 shouldCacheImage 才真正读取文件。
  final List<AssetEntity> photos;

  /// 当前滑动到的照片索引（从 0 开始）
  final int currentIndex;

  /// 当前剩余体力值
  /// 为什么用 double 不用 int：
  ///   预留未来"半体力消耗"等精细化策略（如 Pro 用户减半扣除）。
  final double currentEnergy;

  /// 是否正在从相册加载照片
  final bool isLoading;

  /// 错误信息（null 表示无错误）
  final String? errorMessage;

  /// 已左滑删除的照片计数
  final int deletedCount;

  const BlitzState({
    this.photos = const [],
    this.currentIndex = 0,
    this.currentEnergy = 50.0,
    this.isLoading = false,
    this.errorMessage,
    this.deletedCount = 0,
  });

  /// 便捷 getter：是否还有下一张照片可处理
  bool get hasNextPhoto => currentIndex < photos.length;

  /// 便捷 getter：体力是否充足（至少 1 点）
  bool get hasEnergy => currentEnergy >= 1.0;

  /// 便捷 getter：当前正在展示的照片（越界安全）
  AssetEntity? get currentPhoto => hasNextPhoto ? photos[currentIndex] : null;

  /// 不可变状态更新（copyWith 模式）
  /// 为什么手写而不用 Freezed：
  ///   减少 build_runner 代码生成依赖，在 photo_manager 等重型包共存时
  ///   避免版本冲突，同时保持代码简洁可控。
  BlitzState copyWith({
    List<AssetEntity>? photos,
    int? currentIndex,
    double? currentEnergy,
    bool? isLoading,
    String? Function()? errorMessage,
    int? deletedCount,
  }) {
    return BlitzState(
      photos: photos ?? this.photos,
      currentIndex: currentIndex ?? this.currentIndex,
      currentEnergy: currentEnergy ?? this.currentEnergy,
      isLoading: isLoading ?? this.isLoading,
      // 使用 Function 包装 nullable 字段，区分"不更新"和"设为 null"
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      deletedCount: deletedCount ?? this.deletedCount,
    );
  }

  @override
  String toString() =>
      'BlitzState(photos: ${photos.length}, index: $currentIndex, '
      'energy: $currentEnergy, loading: $isLoading, error: $errorMessage)';
}
