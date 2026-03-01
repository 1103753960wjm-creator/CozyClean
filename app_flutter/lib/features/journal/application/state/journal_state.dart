/// CozyClean — 手账列表页状态
///
/// 不可变状态类，管理手账列表页的数据和加载状态。
/// Controller 通过 copyWith 更新状态，UI 层仅读取。
///
/// 架构位置：features/journal/application/state/
///   遵循 Riverpod 不可变状态原则，所有 List 使用 List.unmodifiable。
library;

import 'package:cozy_clean/data/local/app_database.dart';

/// 手账列表页状态
///
/// [journals] 全部手账记录（按 createdAt 倒序）
/// [isLoading] 是否正在加载数据
/// [errorMessage] 加载失败时的错误信息
class JournalState {
  final List<Journal> journals;
  final bool isLoading;
  final String? errorMessage;

  const JournalState({
    this.journals = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  /// 是否为空状态（非加载中且无数据）
  bool get isEmpty => !isLoading && journals.isEmpty;

  /// 按年月分组的手账数据
  ///
  /// 返回 Map<String, List<Journal>>，key 格式为 "2025年3月"。
  /// 利用 journals 已按 createdAt 倒序排列的特性，
  /// 单次遍历 O(n) 完成分组。
  Map<String, List<Journal>> get groupedByMonth {
    final Map<String, List<Journal>> groups = {};
    for (final journal in journals) {
      final key = '${journal.createdAt.year}年${journal.createdAt.month}月';
      groups.putIfAbsent(key, () => []).add(journal);
    }
    return groups;
  }

  /// 不可变 copyWith
  JournalState copyWith({
    List<Journal>? journals,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return JournalState(
      journals: journals != null ? List.unmodifiable(journals) : this.journals,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
