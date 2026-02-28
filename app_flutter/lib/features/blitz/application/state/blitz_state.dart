/// CozyClean — 闪电战引擎状态模型
///
/// 纯 Dart 不可变状态类（不使用 Freezed，减少依赖冲突）。
///
/// 四方向滑动操作语义：
///   - ← 左滑 (swipeLeft)  → 删除照片，加入 [sessionDeleted]
///   - → 右滑 (swipeRight) → 保留照片，加入 [sessionKept]
///   - ↑ 上滑 (swipeUp)    → 收藏照片，加入 [sessionFavorites]（最多 6 张）
///   - ↓ 下滑 (swipeDown)  → 待定跳过，加入 [sessionPending]，整理完后复审
///
/// 不可变性保证：
///   所有集合字段在 [copyWith] 中通过
///   `List.unmodifiable` / `Map.unmodifiable` 包装，
///   任何尝试修改的操作都会在运行时抛出 [UnsupportedError]。
///
/// 状态流转示意：
/// ```
/// isLoading=true → 加载相册 → photoGroups 填充 → isLoading=false
///           → 用户左滑 → sessionDeleted 追加 & currentGroupIndex++
///           → 用户右滑 → sessionKept 追加 & currentGroupIndex++
///           → 用户上滑 → sessionFavorites 追加（≤6）& currentGroupIndex++
///           → 用户下滑 → sessionPending 追加 & currentGroupIndex++
///           → 全部处理完毕 → 如有 pending 则展示复审，否则跳转结算页
/// ```
library;

import 'dart:typed_data';
import 'package:photo_manager/photo_manager.dart';

import 'package:cozy_clean/features/blitz/domain/models/photo_group.dart';

/// 闪电战 (Blitz Mode) 的引擎状态
///
/// 所有字段均为 final，状态更新必须通过 [copyWith] 创建新实例。
/// 集合类型在 copyWith 中通过 `List.unmodifiable` 冻结。
class BlitzState {
  // ============================================================
  // 照片与进度
  // ============================================================

  /// 连拍分组后的照片组列表
  ///
  /// 由 BurstGroupingService 在 Controller 初始化时生成。
  /// 每个 [PhotoGroup] 可能包含 1 张独立照片或多张连拍照片。
  final List<PhotoGroup> photoGroups;

  /// 当前正在展示的分组索引（从 0 开始）
  ///
  /// 每次用户完成一个分组的处理（四方向之一），索引 +1。
  /// 当 currentGroupIndex >= photoGroups.length 时表示全部处理完毕。
  final int currentGroupIndex;

  // ============================================================
  // 四方向操作结果集
  // ============================================================

  /// ← 左滑删除：标记为待删除的照片
  ///
  /// 结算页中统一执行系统级批量删除。
  final List<AssetEntity> sessionDeleted;

  /// → 右滑保留：标记为保留的照片
  ///
  /// 写入 PhotoActions 数据库以避免下次重复出现。
  final List<AssetEntity> sessionKept;

  /// ↑ 上滑收藏：收藏的照片（最多 6 张）
  ///
  /// 用于结算页堆叠展示和生成手账海报。
  /// 上限 6 张由 Controller 层的 swipeUp() 校验。
  final List<AssetEntity> sessionFavorites;

  /// ↓ 下滑待定：跳过到待定区的照片
  ///
  /// 整理完所有照片后统一展示，让用户再次决策。
  /// UI 底部显示待定区计数 Badge。
  final List<AssetEntity> sessionPending;

  /// 收藏照片上限
  static const int maxFavorites = 6;

  // ============================================================
  // 体力与状态
  // ============================================================

  /// 当前剩余体力值
  ///
  /// Pro 会员时值为 double.infinity。
  final double currentEnergy;

  /// 是否正在从相册加载照片
  final bool isLoading;

  /// 错误信息（null 表示无错误）
  final String? errorMessage;

  /// 预加载好的缩略图字节流缓存 (photo.id -> Uint8List)
  final Map<String, Uint8List> thumbnailCache;

  // ============================================================
  // 撤销哨兵
  // ============================================================

  /// 上一次被处理的照片（null = 不可撤销）
  final AssetEntity? lastSwipedPhoto;

  /// 上一次操作的方向类型（用于精确撤销）
  ///
  /// 0 = left(delete), 1 = right(keep), 2 = up(favorite), 3 = down(pending)
  /// null = 不可撤销
  final int? lastSwipeDirection;

  // ============================================================
  // 待定区回放
  // ============================================================

  /// 是否处于待定区回放阶段
  ///
  /// 当主照片全部处理完毕且 sessionPending 不为空时，
  /// Controller 调用 enterPendingReview() 将此字段设为 true。
  final bool isReviewingPending;

  /// 当前回放到的待定照片索引（从 0 开始）
  ///
  /// 每处理一张待定照片，索引 +1。
  /// 当 pendingReviewIndex >= sessionPending.length 时表示回放完毕。
  final int pendingReviewIndex;

  /// 是否显示新手引导蒙版
  ///
  /// 初始值为 false，待加载本地状态后再决定是否展示。
  final bool showOnboarding;

  /// 新手引导状态是否已从持久化存储加载完成
  final bool onboardingLoaded;

  const BlitzState({
    this.photoGroups = const [],
    this.currentGroupIndex = 0,
    this.sessionDeleted = const [],
    this.sessionKept = const [],
    this.sessionFavorites = const [],
    this.sessionPending = const [],
    this.currentEnergy = 50.0,
    this.isLoading = false,
    this.errorMessage,
    this.thumbnailCache = const {},
    this.lastSwipedPhoto,
    this.lastSwipeDirection,
    this.isReviewingPending = false,
    this.pendingReviewIndex = 0,
    this.showOnboarding = false,
    this.onboardingLoaded = false,
  });

  // ============================================================
  // 方向常量（用于 lastSwipeDirection）
  // ============================================================

  /// 左滑删除
  static const int directionLeft = 0;

  /// 右滑保留
  static const int directionRight = 1;

  /// 上滑收藏
  static const int directionUp = 2;

  /// 下滑待定
  static const int directionDown = 3;

  // ============================================================
  // 便捷 Getter
  // ============================================================

  /// 是否还有下一个分组可处理
  bool get hasNextGroup => currentGroupIndex < photoGroups.length;

  /// 体力是否充足（至少 1 点）
  bool get hasEnergy => currentEnergy >= 1.0;

  /// 当前正在展示的分组（越界安全）
  PhotoGroup? get currentGroup =>
      hasNextGroup ? photoGroups[currentGroupIndex] : null;

  /// 收藏是否已满
  bool get isFavoritesFull => sessionFavorites.length >= maxFavorites;

  /// 各操作计数
  int get deletedCount => sessionDeleted.length;
  int get keptCount => sessionKept.length;
  int get favoritesCount => sessionFavorites.length;
  int get pendingCount => sessionPending.length;

  /// 是否存在待定照片
  bool get hasPendingPhotos => sessionPending.isNotEmpty;

  /// 回放阶段是否还有下一张待定照片
  bool get hasNextPending => pendingReviewIndex < sessionPending.length;

  /// 回放阶段是否已全部处理完毕
  bool get isPendingReviewFinished =>
      pendingReviewIndex >= sessionPending.length;

  /// 回放阶段剩余待处理照片数
  int get pendingRemainingCount => sessionPending.length - pendingReviewIndex;

  /// 当前回放展示的待定照片（越界安全）
  AssetEntity? get currentPendingPhoto {
    if (!hasNextPending) return null;
    return sessionPending[pendingReviewIndex];
  }

  // ============================================================
  // copyWith — 不可变状态更新
  // ============================================================

  /// 不可变状态更新
  ///
  /// 核心安全机制：
  ///   所有集合参数通过 `List.unmodifiable` / `Map.unmodifiable` 包装，
  ///   确保返回的新实例中的集合不可被外部修改。
  ///
  /// nullable 字段处理：
  ///   使用 `Function()` 包装来区分 "不更新此字段" 和 "将此字段设为 null"。
  BlitzState copyWith({
    List<PhotoGroup>? photoGroups,
    int? currentGroupIndex,
    List<AssetEntity>? sessionDeleted,
    List<AssetEntity>? sessionKept,
    List<AssetEntity>? sessionFavorites,
    List<AssetEntity>? sessionPending,
    double? currentEnergy,
    bool? isLoading,
    String? Function()? errorMessage,
    Map<String, Uint8List>? thumbnailCache,
    AssetEntity? Function()? lastSwipedPhoto,
    int? Function()? lastSwipeDirection,
    bool? isReviewingPending,
    int? pendingReviewIndex,
    bool? showOnboarding,
    bool? onboardingLoaded,
  }) {
    return BlitzState(
      photoGroups: photoGroups != null
          ? List<PhotoGroup>.unmodifiable(photoGroups)
          : this.photoGroups,
      currentGroupIndex: currentGroupIndex ?? this.currentGroupIndex,
      sessionDeleted: sessionDeleted != null
          ? List<AssetEntity>.unmodifiable(sessionDeleted)
          : this.sessionDeleted,
      sessionKept: sessionKept != null
          ? List<AssetEntity>.unmodifiable(sessionKept)
          : this.sessionKept,
      sessionFavorites: sessionFavorites != null
          ? List<AssetEntity>.unmodifiable(sessionFavorites)
          : this.sessionFavorites,
      sessionPending: sessionPending != null
          ? List<AssetEntity>.unmodifiable(sessionPending)
          : this.sessionPending,
      currentEnergy: currentEnergy ?? this.currentEnergy,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      thumbnailCache: thumbnailCache != null
          ? Map<String, Uint8List>.unmodifiable(thumbnailCache)
          : this.thumbnailCache,
      lastSwipedPhoto:
          lastSwipedPhoto != null ? lastSwipedPhoto() : this.lastSwipedPhoto,
      lastSwipeDirection: lastSwipeDirection != null
          ? lastSwipeDirection()
          : this.lastSwipeDirection,
      isReviewingPending: isReviewingPending ?? this.isReviewingPending,
      pendingReviewIndex: pendingReviewIndex ?? this.pendingReviewIndex,
      showOnboarding: showOnboarding ?? this.showOnboarding,
      onboardingLoaded: onboardingLoaded ?? this.onboardingLoaded,
    );
  }

  @override
  String toString() =>
      'BlitzState(groups: ${photoGroups.length}, index: $currentGroupIndex, '
      'energy: $currentEnergy, loading: $isLoading, '
      'deleted: $deletedCount, kept: $keptCount, '
      'favorites: $favoritesCount, pending: $pendingCount, '
      'canUndo: ${lastSwipedPhoto != null})';
}
