/// CozyClean — 闪电战数据层 Provider 定义
///
/// 将所有数据层的 Riverpod Provider 集中定义在此文件，
/// 确保 Controller 层不需要直接 import DataSource 或 Database。
///
/// 分层职责：
///   数据层负责 Provider 的构造和依赖注入连线，
///   Controller 层只需 import 本文件中的 Provider 即可获取 Repository，
///   无需关心 Repository 内部依赖了哪些 DataSource 或 Database。
///
/// 依赖关系：
/// ```
/// blitzRepositoryProvider
///   ├── photoDataSourceProvider → PhotoDataSource
///   └── appDatabaseProvider     → AppDatabase
/// ```
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cozy_clean/data/local/app_database.dart';
import 'package:cozy_clean/features/blitz/data/datasources/photo_datasource.dart';
import 'package:cozy_clean/features/blitz/data/repositories/blitz_repository.dart';

/// 向上层 re-export BlitzRepository 类型，
/// 使 Controller 层无需单独 import repository 文件。
export 'package:cozy_clean/features/blitz/data/repositories/blitz_repository.dart'
    show BlitzRepository;

// ============================================================
// 基础设施 Provider
// ============================================================

/// AppDatabase 的全局 Provider（单例）
///
/// 为什么用 Provider 而不是在各处直接 new：
///   1. 保证全局单例，避免多个 Database 实例竞争文件锁
///   2. 方便测试时通过 ProviderScope overrides 注入 Mock
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

/// PhotoDataSource Provider
///
/// 无状态数据源，const 构造保证零开销。
final photoDataSourceProvider = Provider<PhotoDataSource>((ref) {
  return const PhotoDataSource();
});

// ============================================================
// Repository Provider
// ============================================================

/// BlitzRepository Provider
///
/// 组合 [PhotoDataSource] 和 [AppDatabase]，
/// 向 Controller 层提供统一的数据访问接口。
///
/// Controller 只需 import 本文件并 ref.read(blitzRepositoryProvider)，
/// 无需知道 Repository 内部的 DataSource 或 Database 实现细节。
final blitzRepositoryProvider = Provider<BlitzRepository>((ref) {
  return BlitzRepository(
    dataSource: ref.watch(photoDataSourceProvider),
    db: ref.watch(appDatabaseProvider),
  );
});
