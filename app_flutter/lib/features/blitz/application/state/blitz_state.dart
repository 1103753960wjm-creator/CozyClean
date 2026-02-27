/// CozyClean — 闪电战引擎状态模型
///
/// 纯 Dart 不可变状态类（不使用 Freezed，减少依赖冲突）。
///
/// 不可变性的好处：
///   1. **线程安全** — 不可变对象天然是线程安全的，多个 Widget 同时读取
///      同一份 state 不会出现竞态条件或数据撕裂
///   2. **变更检测** — Riverpod 通过 identical() 比较新旧 state 引用，
///      不可变状态保证"修改 = 新实例"，UI 重建判定零成本
///   3. **时间旅行调试** — 每次 copyWith 产生独立快照，可轻松实现
///      undo/redo 和状态回放（Flutter DevTools 依赖此特性）
///   4. **防御性编程** — 外部代码拿到 state 后无法悄悄修改内部数据，
///      杜绝了 `state.favorites.add(photo)` 类的隐蔽 Bug
///   5. **可预测性** — 状态只能通过 Controller 的 copyWith 更新，
///      数据流单向流动，调试时只需追踪 copyWith 调用链
///
/// 集合不可变保证：
///   所有集合字段（List、Map、Set）在 [copyWith] 中通过
///   `List.unmodifiable` / `Map.unmodifiable` 包装，
///   任何尝试修改的操作都会在运行时抛出 [UnsupportedError]。
///
/// 状态流转示意：
/// ```
/// isLoading=true → 加载相册 → photoGroups 填充 → isLoading=false
///           → 用户右滑 → favorites 追加 & currentGroupIndex++
///           → 用户左滑 → skipped 追加 & currentGroupIndex++
///           → 全部处理完毕 → 跳转结算页
/// ```
library;

import 'dart:typed_data';
import 'package:photo_manager/photo_manager.dart';

import 'package:cozy_clean/features/blitz/domain/models/photo_group.dart';

/// 闪电战 (Blitz Mode) 的引擎状态
///
/// 所有字段均为 final，状态更新必须通过 [copyWith] 创建新实例。
/// 集合类型在 copyWith 中通过 `List.unmodifiable` 冻结，
/// 从根源杜绝 `state.photoGroups.add(group)` 类违规操作。
class BlitzState {
  /// 连拍分组后的照片组列表
  ///
  /// 由 BurstGroupingService 在 Controller 初始化时生成。
  /// 每个 [PhotoGroup] 可能包含 1 张独立照片或多张连拍照片。
  /// 不可变：外部无法通过引用执行 add/remove 操作。
  final List<PhotoGroup> photoGroups;

  /// 当前正在展示的分组索引（从 0 开始）
  ///
  /// 每次用户完成一个分组的处理（右滑/左滑），索引 +1。
  /// 当 currentGroupIndex >= photoGroups.length 时表示全部处理完毕。
  final int currentGroupIndex;

  /// 本次会话中用户右滑保留（收藏）的照片列表
  ///
  /// 仅存储 AssetEntity 引用（轻量级，不加载原图）。
  /// 用于结算页展示和批量写入数据库。
  /// 不可变：通过 List.unmodifiable 冻结。
  final List<AssetEntity> favorites;

  /// 本次会话中用户左滑跳过（丢弃）的照片列表
  ///
  /// 用于结算页统计和批量删除确认。
  /// 不可变：通过 List.unmodifiable 冻结。
  final List<AssetEntity> skipped;

  /// 当前剩余体力值
  ///
  /// 为什么用 double 不用 int：
  ///   预留未来"半体力消耗"等精细化策略。
  ///   Pro 会员时值为 double.infinity。
  final double currentEnergy;

  /// 是否正在从相册加载照片
  final bool isLoading;

  /// 错误信息（null 表示无错误）
  final String? errorMessage;

  /// 预加载好的缩略图字节流缓存 (photo.id -> Uint8List)
  ///
  /// 在初始化阶段一次性填充，PhotoCard 同步读取。
  /// 不可变：通过 Map.unmodifiable 冻结。
  final Map<String, Uint8List> thumbnailCache;

  /// 单步撤销哨兵：上一次被处理的照片（null = 不可撤销）
  final AssetEntity? lastSwipedPhoto;

  /// 单步撤销哨兵：上一次操作是否为跳过（null = 不可撤销）
  final bool? lastSwipeWasSkip;

  const BlitzState({
    this.photoGroups = const [],
    this.currentGroupIndex = 0,
    this.favorites = const [],
    this.skipped = const [],
    this.currentEnergy = 50.0,
    this.isLoading = false,
    this.errorMessage,
    this.thumbnailCache = const {},
    this.lastSwipedPhoto,
    this.lastSwipeWasSkip,
  });

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

  /// 收藏照片计数
  int get favoritesCount => favorites.length;

  /// 跳过照片计数
  int get skippedCount => skipped.length;

  // ============================================================
  // copyWith — 不可变状态更新
  // ============================================================

  /// 不可变状态更新
  ///
  /// 核心安全机制：
  ///   所有集合类型参数通过 `List.unmodifiable` / `Map.unmodifiable` 包装，
  ///   确保返回的新实例中的集合不可被外部修改。
  ///
  /// nullable 字段处理：
  ///   使用 `Function()` 包装（如 `String? Function()?`）来区分
  ///   "不更新此字段" 和 "将此字段设为 null"。
  BlitzState copyWith({
    List<PhotoGroup>? photoGroups,
    int? currentGroupIndex,
    List<AssetEntity>? favorites,
    List<AssetEntity>? skipped,
    double? currentEnergy,
    bool? isLoading,
    String? Function()? errorMessage,
    Map<String, Uint8List>? thumbnailCache,
    AssetEntity? Function()? lastSwipedPhoto,
    bool? Function()? lastSwipeWasSkip,
  }) {
    return BlitzState(
      photoGroups: photoGroups != null
          ? List<PhotoGroup>.unmodifiable(photoGroups)
          : this.photoGroups,
      currentGroupIndex: currentGroupIndex ?? this.currentGroupIndex,
      favorites: favorites != null
          ? List<AssetEntity>.unmodifiable(favorites)
          : this.favorites,
      skipped: skipped != null
          ? List<AssetEntity>.unmodifiable(skipped)
          : this.skipped,
      currentEnergy: currentEnergy ?? this.currentEnergy,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      thumbnailCache: thumbnailCache != null
          ? Map<String, Uint8List>.unmodifiable(thumbnailCache)
          : this.thumbnailCache,
      lastSwipedPhoto:
          lastSwipedPhoto != null ? lastSwipedPhoto() : this.lastSwipedPhoto,
      lastSwipeWasSkip:
          lastSwipeWasSkip != null ? lastSwipeWasSkip() : this.lastSwipeWasSkip,
    );
  }

  @override
  String toString() =>
      'BlitzState(groups: ${photoGroups.length}, index: $currentGroupIndex, '
      'energy: $currentEnergy, loading: $isLoading, '
      'favorites: $favoritesCount, skipped: $skippedCount, '
      'canUndo: ${lastSwipedPhoto != null})';
}
