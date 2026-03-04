/// CozyClean — 用户状态控制器
///
/// 管理用户体力值 (Energy)、Pro 会员状态等核心用户数据。
/// 通过 Drift 数据库的 LocalUserStats 表持久化。
///
/// 会员体系设计：
/// - 普通用户：每日 50 点体力，每次操作消耗 1 点
/// - Pro 会员：无限体力，不扣除
///
/// ======================================
/// TODO: 对接真实支付服务
/// ======================================
/// 当接入 Apple IAP / 微信支付 / 支付宝等支付 SDK 后：
/// 1. 在支付回调成功处调用 togglePro(true)
/// 2. 在订阅过期 / 退款回调中调用 togglePro(false)
/// 3. 可选：在 App 启动时校验订阅状态，自动同步 isPro
/// ======================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:cozy_clean/data/local/app_database.dart';
import 'package:cozy_clean/features/blitz/data/providers/blitz_data_providers.dart';

/// 默认用户 ID（单设备单用户场景）
/// TODO: 接入登录系统后改为真实 UID
const String _defaultUserId = "default_user";

// ============================================
// Providers
// ============================================

/// 用户状态数据流 Provider
///
/// 监听数据库中的用户数据变化，任何对 LocalUserStats 的更新都会
/// 自动触发 UI 重建（如主页体力环、Pro 标识等）。
final userStatsStreamProvider = StreamProvider<LocalUserStat>((ref) {
  final db = ref.watch(appDatabaseProvider);

  // 确保默认用户记录存在
  _ensureDefaultUserExists(db);

  return (db.select(db.localUserStats)
        ..where((t) => t.uid.equals(_defaultUserId)))
      .watchSingle();
});

/// 用户状态控制器 Provider
final userStatsControllerProvider = Provider<UserStatsController>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return UserStatsController(db);
});

// ============================================
// 初始化辅助
// ============================================

/// 确保默认用户记录存在于数据库中
///
/// 首次启动 App 时自动插入一条默认记录，
/// 所有字段使用 Drift 表定义中的默认值（isPro=false, energy=50.0 等）。
Future<void> _ensureDefaultUserExists(AppDatabase db) async {
  final countExp = db.localUserStats.uid.count();
  final query = db.selectOnly(db.localUserStats)
    ..addColumns([countExp])
    ..where(db.localUserStats.uid.equals(_defaultUserId));
  final count = await query.map((row) => row.read(countExp)).getSingle();

  if (count == 0) {
    await db.into(db.localUserStats).insert(
          LocalUserStatsCompanion.insert(
            uid: _defaultUserId,
          ),
        );
  }
}

// ============================================
// 用户状态控制器
// ============================================

/// 用户状态控制器
///
/// 负责对用户数据进行写操作（体力消耗、会员切换等）。
/// 读操作通过 [userStatsStreamProvider] 的响应式流完成。
class UserStatsController {
  final AppDatabase _db;

  UserStatsController(this._db);

  /// 消耗体力
  ///
  /// 业务规则：
  /// - 若用户是 Pro 会员（isPro == true），直接跳过，不扣除任何体力
  /// - 若用户是普通用户，扣除 [amount] 点体力并写入数据库
  ///
  /// [amount] 通常为 1.0，预留 double 类型以支持未来精细化策略
  Future<void> consumeEnergy(double amount) async {
    final query = _db.select(_db.localUserStats)
      ..where((t) => t.uid.equals(_defaultUserId));
    final stat = await query.getSingleOrNull();

    if (stat == null) return;

    // Pro 会员无限体力，跳过扣除
    if (stat.isPro) return;

    final newEnergy = (stat.dailyEnergyRemaining - amount).clamp(0.0, 100.0);
    await _db.update(_db.localUserStats).replace(
          stat.copyWith(dailyEnergyRemaining: newEnergy),
        );
  }

  /// 切换 Pro 会员状态
  ///
  /// 这是未来支付系统的核心对接点。
  ///
  /// 使用场景：
  /// - 支付成功回调 → togglePro(true)
  /// - 订阅过期 / 退款 → togglePro(false)
  /// - 调试测试 → 手动调用
  ///
  /// TODO: 接入支付 SDK 后，在支付回调中调用此方法
  Future<void> togglePro(bool value) async {
    print('👉 [UserStatsController] togglePro called with: $value');
    try {
      final query = _db.select(_db.localUserStats)
        ..where((t) => t.uid.equals(_defaultUserId));
      final stat = await query.getSingleOrNull();

      if (stat == null) {
        print(
            '❌ [UserStatsController] Default user not found, aborting togglePro.');
        return;
      }

      await _db.update(_db.localUserStats).replace(
            stat.copyWith(isPro: value),
          );
      print('✅ [UserStatsController] Successfully updated isPro to: $value');
    } catch (e, stack) {
      print('❌ [UserStatsController] togglePro error: $e\n$stack');
    }
  }

  /// 记录一次清理会话并累加用户统计数据
  ///
  /// 在 Drift 事务中执行两步操作，保证原子性：
  ///   1. INSERT → SessionLogs 表（新增一条清理记录）
  ///   2. UPDATE → LocalUserStats 表（累加 totalSavedBytes）
  ///
  /// 约束 #3：totalSavedBytes 的 += 采用"先查旧值再覆盖"模式，
  /// 避免 Drift CustomExpression 语法问题导致的 SQL 报错。
  ///
  /// [mode] 清理模式（0=闪电战, 1=截图粉碎, 2=时光机）
  /// [deletedCount] 本次实际删除的照片数
  /// [savedBytes] 本次预估节省的空间（字节）
  Future<void> recordCleaningSession({
    required int mode,
    required int deletedCount,
    required int savedBytes,
  }) async {
    print('📊 [UserStatsController] recordCleaningSession: '
        'mode=$mode, deleted=$deletedCount, saved=$savedBytes bytes');

    try {
      await _db.transaction(() async {
        // ---- Step 1: 插入会话日志 ----
        final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
        await _db.into(_db.sessionLogs).insert(
              SessionLogsCompanion.insert(
                sessionId: sessionId,
                mode: mode,
                deletedCount: Value(deletedCount),
                savedBytes: Value(savedBytes),
                startTime: DateTime.now(),
                // isSynced 默认为 false，等待后台同步
              ),
            );

        // ---- Step 2: 累加用户统计（先查旧值再覆盖） ----
        // 为什么不用 CustomExpression('total_saved_bytes + $savedBytes')：
        //   Drift 对 CustomExpression 的支持在不同版本间有差异，
        //   "先查后写"虽多一次 IO，但语义清晰、跨版本稳定。
        final query = _db.select(_db.localUserStats)
          ..where((t) => t.uid.equals(_defaultUserId));
        final stat = await query.getSingleOrNull();

        if (stat != null) {
          final newTotal = stat.totalSavedBytes + savedBytes;
          await _db.update(_db.localUserStats).replace(
                stat.copyWith(totalSavedBytes: newTotal),
              );
        }
      });

      print('✅ [UserStatsController] Session recorded & stats updated.');
    } catch (e, stack) {
      print('❌ [UserStatsController] recordCleaningSession error: $e\n$stack');
    }
  }

  /// 批量提交闪电战内存草稿到数据库（一次性事务）
  ///
  /// 这是"内存草稿模式"的核心落库方法。
  /// 接收 BlitzController 中暂存的 keeps/deletes Set，在单次 Drift batch 中
  /// 批量写入 PhotoActions，同时更新 SessionLogs 和 totalSavedBytes。
  ///
  /// 约束 #2：使用 Drift 原生 batch API，避免 for 循环单条 insert 的性能问题。
  ///
  /// [keeps] 右滑保留的 photo ID 集合
  /// [deletes] 左滑删除的 photo ID 集合
  /// [savedBytes] 预估本次释放的空间（字节）
  Future<void> commitBlitzSession({
    required Set<String> keeps,
    required Set<String> deletes,
    required int savedBytes,
  }) async {
    final totalActions = keeps.length + deletes.length;
    print('📊 [UserStatsController] commitBlitzSession: '
        'keeps=${keeps.length}, deletes=${deletes.length}, '
        'saved=$savedBytes bytes, total=$totalActions actions');

    if (totalActions == 0) {
      print('⚠️ [UserStatsController] 空草稿，跳过提交');
      return;
    }

    try {
      // ---- Step 1: 批量插入 PhotoActions (Drift batch API) ----
      // 构造 keeps 和 deletes 的 Companion 列表
      final keepsEntities = keeps
          .map((id) => PhotoActionsCompanion.insert(id: id, actionType: 0))
          .toList();
      final deletesEntities = deletes
          .map((id) => PhotoActionsCompanion.insert(id: id, actionType: 1))
          .toList();

      await _db.batch((batch) {
        if (keepsEntities.isNotEmpty) {
          batch.insertAllOnConflictUpdate(_db.photoActions, keepsEntities);
        }
        if (deletesEntities.isNotEmpty) {
          batch.insertAllOnConflictUpdate(_db.photoActions, deletesEntities);
        }
      });

      // ---- Step 2: 插入 SessionLog + 累加 totalSavedBytes (事务) ----
      await _db.transaction(() async {
        final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
        await _db.into(_db.sessionLogs).insert(
              SessionLogsCompanion.insert(
                sessionId: sessionId,
                mode: 0, // 闪电战
                deletedCount: Value(deletes.length),
                savedBytes: Value(savedBytes),
                startTime: DateTime.now(),
              ),
            );

        // 先查旧值再覆盖（安全的 += 模式）
        final query = _db.select(_db.localUserStats)
          ..where((t) => t.uid.equals(_defaultUserId));
        final stat = await query.getSingleOrNull();

        if (stat != null) {
          final newTotal = stat.totalSavedBytes + savedBytes;
          await _db.update(_db.localUserStats).replace(
                stat.copyWith(totalSavedBytes: newTotal),
              );
        }
      });

      print('✅ [UserStatsController] Batch commit 完成: '
          '$totalActions 条 PhotoActions 已写入');
    } catch (e, stack) {
      print('❌ [UserStatsController] commitBlitzSession error: $e\n$stack');
    }
  }

  /// 一键升级为终身 Pro 会员
  ///
  /// 语义化封装，内部调用 togglePro(true)。
  /// 使用场景：
  ///   - 支付成功回调
  ///   - 调试/测试时快速切换
  Future<void> upgradeToPro() async {
    await togglePro(true);
  }
}
