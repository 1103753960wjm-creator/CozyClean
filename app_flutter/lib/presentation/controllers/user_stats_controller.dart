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
import 'package:cozy_clean/presentation/controllers/blitz_controller.dart';

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
}
