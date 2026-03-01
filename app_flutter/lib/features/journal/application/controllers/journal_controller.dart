/// CozyClean — 手账列表控制器
///
/// 管理手账列表的业务逻辑，通过 JournalRepository 访问数据库。
/// UI 层仅调用 Controller 方法，不直接访问数据库。
///
/// 架构位置：features/journal/application/controllers/
///   Controller → Repository → Database
///   UI 层通过 Riverpod Provider 订阅状态变化。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cozy_clean/features/blitz/data/providers/blitz_data_providers.dart';
import 'package:cozy_clean/features/journal/application/state/journal_state.dart';
import 'package:cozy_clean/features/journal/data/repositories/journal_repository.dart';

/// Riverpod Provider — 手账列表控制器
///
/// 使用 StateNotifierProvider 管理 JournalState，
/// UI 层通过 ref.watch(journalControllerProvider) 订阅状态。
final journalControllerProvider =
    StateNotifierProvider<JournalController, JournalState>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return JournalController(JournalRepository(db));
});

/// 手账列表控制器
///
/// 职责：
///   - 从 Repository 加载手账列表
///   - 删除手账记录
///   - 管理加载状态和错误状态
///
/// 遵循规则：
///   - 不可变状态更新（copyWith）
///   - 通过 Repository 访问数据库
///   - 安全的错误处理（try/catch）
class JournalController extends StateNotifier<JournalState> {
  final JournalRepository _repository;

  JournalController(this._repository) : super(const JournalState());

  /// 加载全部手账列表
  ///
  /// 从 Repository 获取按 createdAt 倒序排列的全部手账。
  /// 设置 isLoading 状态，加载完成后更新 journals。
  /// 失败时设置 errorMessage 而不是抛异常。
  Future<void> loadJournals() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final journals = await _repository.getAllJournals();
      state = state.copyWith(
        journals: journals,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('[JournalController] 加载手账失败: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: '加载手账失败，请稍后重试',
      );
    }
  }

  /// 删除一条手账记录
  ///
  /// 从数据库删除指定 ID 的手账，成功后重新加载列表。
  /// 失败时设置 errorMessage。
  Future<bool> deleteJournal(int id) async {
    try {
      await _repository.deleteJournal(id);
      // 删除成功后从本地状态中移除，避免重新查询
      final updated = state.journals.where((j) => j.id != id).toList();
      state = state.copyWith(journals: updated);
      return true;
    } catch (e) {
      debugPrint('[JournalController] 删除手账失败: $e');
      state = state.copyWith(errorMessage: '删除失败，请稍后重试');
      return false;
    }
  }
}
