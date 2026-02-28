/// CozyClean — 闪电战核心展示主页
///
/// UI 层职责：
///   1. ref.watch [BlitzState] 并重建 UI
///   2. ref.read [BlitzController] 响应用户交互
///   3. 管理页面级动画
///
/// 四方向操作：
///   ← 左滑 = 删除 (DISCARD)
///   → 右滑 = 保留 (KEEP)
///   ↑ 上滑 = 收藏 (FAVE, 最多 6 张)
///   ↓ 下滑 = 待定 (SKIP, 飞入底部待定区)
///
/// 禁止：
///   - ❌ 访问数据库 / 相册 / 执行业务逻辑
///   - ❌ 在 build() 中执行 IO 或重计算
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import 'package:cozy_clean/features/blitz/application/controllers/blitz_controller.dart';
import 'package:cozy_clean/features/blitz/application/state/blitz_state.dart';
import 'package:cozy_clean/features/blitz/domain/models/photo_group.dart';
import 'package:cozy_clean/presentation/controllers/user_stats_controller.dart';
import 'package:cozy_clean/presentation/pages/summary_page.dart';

/// 闪电战核心展示主页 — 四方向滑动整理照片
class BlitzPage extends ConsumerStatefulWidget {
  const BlitzPage({super.key});

  @override
  ConsumerState<BlitzPage> createState() => _BlitzPageState();
}

class _BlitzPageState extends ConsumerState<BlitzPage> {
  final AppinioSwiperController _swiperController = AppinioSwiperController();
  final AppinioSwiperController _pendingSwiperController =
      AppinioSwiperController();
  bool _isNavigating = false;
  bool _isUndoAnimating = false;

  // ============================================================
  // 生命周期
  // ============================================================

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(blitzControllerProvider.notifier).loadPhotos();
    });
  }

  @override
  void dispose() {
    _swiperController.dispose();
    _pendingSwiperController.dispose();
    super.dispose();
  }

  // ============================================================
  // 交互方法（仅调用 Controller）
  // ============================================================

  void _triggerUndoAnimation() {
    if (!mounted) return;
    setState(() => _isUndoAnimating = true);
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      setState(() => _isUndoAnimating = false);
    });
  }

  void _requestUndo() {
    final success = ref.read(blitzControllerProvider.notifier).undoLastSwipe();
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('只能撤回刚刚滑走的那一张哦 😅', textAlign: TextAlign.center),
          backgroundColor: const Color(0xFFC75D56),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    _swiperController.unswipe();
    HapticFeedback.mediumImpact();
    _triggerUndoAnimation();
  }

  void _navigateToSummary(BlitzState blitzState) {
    if (_isNavigating) return;
    _isNavigating = true;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => SummaryPage(
          deleteSet: blitzState.sessionDeleted,
          favoriteSet: blitzState.sessionFavorites,
          totalReviewedCount: blitzState.photoGroups.length,
        ),
      ),
    );
  }

  /// 四方向滑动结束事件处理
  Future<void> _handleSwipeEnd(
    SwiperActivity activity,
    AssetEntity photo,
  ) async {
    if (activity is! Swipe) return;
    final notifier = ref.read(blitzControllerProvider.notifier);

    switch (activity.direction) {
      case AxisDirection.left:
        HapticFeedback.mediumImpact();
        final success = await notifier.swipeLeft(photo);
        if (!success) {
          _swiperController.unswipe();
          _showNoEnergyWarning();
        }
        break;

      case AxisDirection.right:
        HapticFeedback.lightImpact();
        final success = await notifier.swipeRight(photo);
        if (!success) {
          _swiperController.unswipe();
          _showNoEnergyWarning();
        }
        break;

      case AxisDirection.up:
        HapticFeedback.lightImpact();
        final success = await notifier.swipeUp(photo);
        if (!success) {
          _swiperController.unswipe();
          _showFavoritesFullWarning();
        }
        break;

      case AxisDirection.down:
        HapticFeedback.selectionClick();
        notifier.swipeDown(photo);
        break;
    }
  }

  /// 收藏已满提示
  void _showFavoritesFullWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            const Text('收藏已满 6 张，先去生成手账海报吧 ✨', textAlign: TextAlign.center),
        backgroundColor: const Color(0xFFD4AF37),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ============================================================
  // build — 纯展示
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final blitzState = ref.watch(blitzControllerProvider);

    // 监听全部处理完毕 → 检查是否需要进入待定区回放
    ref.listen(blitzControllerProvider, (previous, next) {
      if (!next.isLoading &&
          next.photoGroups.isNotEmpty &&
          !next.hasNextGroup &&
          !next.isReviewingPending) {
        // 主照片全部处理完毕：
        // 1) 有待定且尚未回放完 -> 进入回放
        // 2) 无待定 -> 直接结算
        if (next.hasPendingPhotos && !next.isPendingReviewFinished) {
          ref.read(blitzControllerProvider.notifier).enterPendingReview();
        } else if (!next.hasPendingPhotos) {
          _navigateToSummary(next);
        }
      }

      // 回放阶段完毕检测
      if (next.isReviewingPending && next.isPendingReviewFinished) {
        ref.read(blitzControllerProvider.notifier).finishPendingReview();
        _navigateToSummary(next);
      }
    });

    if (blitzState.isLoading) {
      return _buildScaffold(
        context,
        const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Color(0xFF8BA888)),
          ),
        ),
      );
    }

    if (blitzState.errorMessage != null) {
      return _buildScaffold(
        context,
        Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              blitzState.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontSize: 16),
            ),
          ),
        ),
      );
    }

    if (blitzState.photoGroups.isEmpty) {
      return _buildScaffold(context, _buildEmptyState());
    }

    // 回放阶段 — 使用独立 UI
    if (blitzState.isReviewingPending) {
      return _buildScaffold(
        context,
        Column(
          children: [
            // 回放阶段专用顶部标题
            _buildPendingReviewHeader(blitzState),
            Expanded(
              child: Stack(
                children: [
                  _buildPendingReviewSwiper(blitzState),
                  // 收藏计数标记（右上角）
                  if (blitzState.favoritesCount > 0)
                    Positioned(
                      top: 8,
                      right: 30,
                      child: _buildCountBadge(
                        '❤️ ${blitzState.favoritesCount}/${BlitzState.maxFavorites}',
                        const Color(0xFFE91E63),
                      ),
                    ),
                ],
              ),
            ),
            _buildActionButtons(blitzState),
          ],
        ),
      );
    }

    return _buildScaffold(
      context,
      Column(
        children: [
          _buildTopBar(
            context,
            blitzState.currentGroupIndex < blitzState.photoGroups.length
                ? blitzState.currentGroupIndex
                : blitzState.photoGroups.length - 1,
            blitzState.photoGroups.length,
            blitzState.currentEnergy,
          ),
          Expanded(
            child: Stack(
              children: [
                _buildSwiperContainer(blitzState),
                // 收藏计数标记（右上角）
                if (blitzState.favoritesCount > 0)
                  Positioned(
                    top: 8,
                    right: 30,
                    child: _buildCountBadge(
                      '❤️ ${blitzState.favoritesCount}/${BlitzState.maxFavorites}',
                      const Color(0xFFE91E63),
                    ),
                  ),
              ],
            ),
          ),
          _buildActionButtons(blitzState),
          // 底部待定区
          if (blitzState.pendingCount > 0) _buildPendingBar(blitzState),
        ],
      ),
    );
  }

  // ============================================================
  // UI 组件构建
  // ============================================================

  /// 计数 Badge 组件
  Widget _buildCountBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// 底部待定区浮窗
  Widget _buildPendingBar(BlitzState blitzState) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8, left: 24, right: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE5DFD3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.schedule_rounded, color: Colors.black38, size: 16),
          const SizedBox(width: 6),
          Text(
            '待定区 · ${blitzState.pendingCount} 张',
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 退出确认
  void _showExitConfirmationBottomSheet() {
    final state = ref.read(blitzControllerProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFFFAF9F6),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '等等！',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4A4238),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '你有 ${state.deletedCount} 张废片待清理，要现在归档吗？',
                style: const TextStyle(fontSize: 16, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Color(0xFFC75D56)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        ref
                            .read(blitzControllerProvider.notifier)
                            .clearSessionDraft();
                        Navigator.of(ctx).pop();
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        '手滑放弃',
                        style: TextStyle(
                          color: Color(0xFFC75D56),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF8BA888),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _navigateToSummary(state);
                      },
                      child: const Text(
                        '这就去清',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  /// 页面脚手架（含返回拦截）
  Widget _buildScaffold(BuildContext context, Widget child) {
    return PopScope(
      canPop: ref.watch(blitzControllerProvider).sessionDeleted.isEmpty,
      onPopInvoked: (didPop) {
        if (didPop) {
          final state = ref.read(blitzControllerProvider);
          if (state.sessionKept.isNotEmpty ||
              state.sessionFavorites.isNotEmpty) {
            ref.read(userStatsControllerProvider).commitBlitzSession(
              keeps: {
                ...state.sessionKept.map((p) => p.id),
                ...state.sessionFavorites.map((p) => p.id),
              },
              deletes: const {},
              savedBytes: 0,
            );
            ref.read(blitzControllerProvider.notifier).clearSessionDraft();
          }
          return;
        }
        _showExitConfirmationBottomSheet();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF9F6),
        body: SafeArea(child: child),
      ),
    );
  }

  /// 顶部信息栏
  Widget _buildTopBar(
      BuildContext context, int currentIndex, int total, double energy) {
    final bool isPro = energy == double.infinity;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              final state = ref.read(blitzControllerProvider);
              if (state.sessionDeleted.isEmpty) {
                Navigator.maybePop(context);
              } else {
                _showExitConfirmationBottomSheet();
              }
            },
            child: const Text('返回',
                style: TextStyle(
                    color: Colors.black45,
                    fontSize: 16,
                    fontWeight: FontWeight.w500)),
          ),
          Text(
            '${currentIndex + 1} / $total',
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt_rounded,
                  color: Color(0xFFD4AF37), size: 20),
              const SizedBox(width: 4),
              Text(
                isPro ? '∞' : '${energy.toInt()}',
                style: const TextStyle(
                  color: Color(0xFF4A4238),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 空状态
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF8BA888).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.task_alt_rounded,
                size: 80,
                color: Color(0xFF8BA888),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              '太棒了！',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A4238),
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '相册里的废片已经全部清理完毕\n今天也是清爽的一天哦 ✨',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 50),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8BA888),
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                ref
                    .read(blitzControllerProvider.notifier)
                    .resetAllPhotoActions();
              },
              child: const Text(
                '重新整理一次',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 四方向操作按钮
  ///
  /// 布局：
  ///   上方中央 = 收藏 ❤️
  ///   左侧 = 删除，右侧 = 保留
  ///   下方中央 = 跳过
  ///   左下方 = 撤销
  Widget _buildActionButtons(BlitzState blitzState) {
    return SizedBox(
      height: 140,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 上方：收藏按钮
              GestureDetector(
                onTap: () {
                  if (blitzState.isReviewingPending) {
                    final success = ref
                        .read(blitzControllerProvider.notifier)
                        .reviewPendingUp();
                    if (!success) _showFavoritesFullWarning();
                  } else {
                    _swiperController.swipeUp();
                  }
                },
                child: Container(
                  color: Colors.transparent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite_rounded,
                          color: blitzState.isFavoritesFull
                              ? Colors.black26
                              : const Color(0xFFE91E63),
                          size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '收藏',
                        style: TextStyle(
                          color: blitzState.isFavoritesFull
                              ? Colors.black26
                              : const Color(0xFFE91E63).withValues(alpha: 0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // 中间行：删除 + 保留
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (blitzState.isReviewingPending) {
                        ref
                            .read(blitzControllerProvider.notifier)
                            .reviewPendingLeft();
                      } else {
                        _swiperController.swipeLeft();
                      }
                    },
                    child: Container(
                      color: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 14),
                      child: Text(
                        '删除',
                        style: TextStyle(
                          color: Colors.red[300]!.withValues(alpha: 0.8),
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                  GestureDetector(
                    onTap: () {
                      if (blitzState.isReviewingPending) {
                        ref
                            .read(blitzControllerProvider.notifier)
                            .reviewPendingRight();
                      } else {
                        _swiperController.swipeRight();
                      }
                    },
                    child: Container(
                      color: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 14),
                      child: Text(
                        '保留',
                        style: TextStyle(
                          color: const Color(0xFF8BA888).withValues(alpha: 0.8),
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // 下方：跳过按钮
              GestureDetector(
                onTap: blitzState.isReviewingPending
                    ? null // 回放阶段禁用跳过
                    : () => _swiperController.swipeDown(),
                child: Container(
                  color: Colors.transparent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule_rounded,
                          color: Colors.black38, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '跳过',
                        style: TextStyle(
                          color: Colors.black45.withValues(alpha: 0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // 撤销按钮
          Positioned(
            left: 20,
            bottom: 60,
            child: GestureDetector(
              onTap: _requestUndo,
              child: Transform.rotate(
                angle: -0.05,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0EBE2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(2, 2),
                      ),
                    ],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(2),
                      bottomLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                      bottomRight: Radius.circular(2),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.replay_rounded,
                          color: Colors.black45, size: 14),
                      SizedBox(width: 4),
                      Text(
                        '撤销',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 撤销动效标签
          Positioned(
            left: 16,
            bottom: 128,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 280),
              offset: _isUndoAnimating ? Offset.zero : const Offset(0.28, 0),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 240),
                opacity: _isUndoAnimating ? 1 : 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    '↩ 照片飞回中',
                    style: TextStyle(
                      color: Color(0xFF8BA888),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 体力耗尽警告
  void _showNoEnergyWarning() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFFFAF9F6),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '体力耗尽',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFC75D56),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '今日体力已耗尽，解锁PRO获取无限体力',
                style: TextStyle(fontSize: 16, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: const Color(0xFFD4AF37),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  '了解 PRO 权益',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  /// Swiper 卡片容器 — 四方向启用（正常整理阶段）
  Widget _buildSwiperContainer(BlitzState blitzState) {
    final groups = blitzState.photoGroups;

    return Center(
      child: AspectRatio(
        aspectRatio: 0.80,
        child: Padding(
          padding: const EdgeInsets.only(left: 30, right: 30, bottom: 10),
          child: AppinioSwiper(
            controller: _swiperController,
            cardCount: groups.length,
            backgroundCardCount: 2,
            backgroundCardScale: 0.92,
            backgroundCardOffset: const Offset(0, 15),
            // 正常阶段启用四方向滑动
            swipeOptions: const SwipeOptions.all(),
            onSwipeEnd:
                (int previousIndex, int targetIndex, SwiperActivity activity) {
              if (previousIndex < 0 || previousIndex >= groups.length) return;
              final photo = groups[previousIndex].bestPhoto;
              _handleSwipeEnd(activity, photo);
            },
            onEnd: () {
              // 此回调由 ref.listen 中的逻辑处理
              // （检查 pending → 进入回放 或 跳结算页）
            },
            cardBuilder: (BuildContext context, int index) {
              if (index < 0 || index >= groups.length) {
                return const SizedBox.shrink();
              }
              final group = groups[index];
              return _buildPhotoCard(group.bestPhoto, group);
            },
          ),
        ),
      ),
    );
  }

  /// 待定区回放 Swiper — 三方向（禁用下滑）
  Widget _buildPendingReviewSwiper(BlitzState blitzState) {
    final pendingPhotos = blitzState.sessionPending;
    final remaining = pendingPhotos.length - blitzState.pendingReviewIndex;

    if (remaining <= 0) return const SizedBox.shrink();

    // 单张时直接展示卡片 + 手势滑动，不使用 AppinioSwiper
    if (remaining == 1) {
      final photo = pendingPhotos[blitzState.pendingReviewIndex];
      return Center(
        child: AspectRatio(
          aspectRatio: 0.80,
          child: Padding(
            padding: const EdgeInsets.only(left: 30, right: 30, bottom: 10),
            child: _buildSwipeablePendingCard(photo),
          ),
        ),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: 0.80,
        child: Padding(
          padding: const EdgeInsets.only(left: 30, right: 30, bottom: 10),
          child: AppinioSwiper(
            controller: _pendingSwiperController,
            cardCount: remaining,
            backgroundCardCount: remaining > 2 ? 2 : 1,
            backgroundCardScale: 0.92,
            backgroundCardOffset: const Offset(0, 15),
            // 回放阶段禁用下滑（不能再跳过了）
            swipeOptions: const SwipeOptions.only(
              left: true,
              right: true,
              up: true,
              down: false,
            ),
            onSwipeEnd:
                (int previousIndex, int targetIndex, SwiperActivity activity) {
              _handlePendingSwipeEnd(activity);
            },
            onEnd: () {
              // 回放完毕由 ref.listen 检测 isPendingReviewFinished 处理
            },
            cardBuilder: (BuildContext context, int index) {
              final actualIndex = blitzState.pendingReviewIndex + index;
              if (actualIndex < 0 || actualIndex >= pendingPhotos.length) {
                return const SizedBox.shrink();
              }
              final photo = pendingPhotos[actualIndex];
              // 回放复用拍立得卡片，传入回放专用 controller 以正确显示印章
              return _buildPhotoCard(
                photo,
                PhotoGroup(photos: [photo]),
                stampController: _pendingSwiperController,
              );
            },
          ),
        ),
      ),
    );
  }

  /// 单张待定照片的可滑动卡片
  ///
  /// 用 GestureDetector 包裹，支持三方向拖拽手势：
  /// - 左 = 删除，右 = 保留，上 = 收藏，下 = 禁用
  Widget _buildSwipeablePendingCard(AssetEntity photo) {
    return _SwipeablePendingCard(
      photo: photo,
      onSwipeLeft: () {
        HapticFeedback.mediumImpact();
        ref.read(blitzControllerProvider.notifier).reviewPendingLeft();
      },
      onSwipeRight: () {
        HapticFeedback.lightImpact();
        ref.read(blitzControllerProvider.notifier).reviewPendingRight();
      },
      onSwipeUp: () {
        HapticFeedback.lightImpact();
        final success =
            ref.read(blitzControllerProvider.notifier).reviewPendingUp();
        if (!success) _showFavoritesFullWarning();
      },
    );
  }

  /// 回放阶段滑动结束处理
  void _handlePendingSwipeEnd(SwiperActivity activity) {
    if (activity is! Swipe) return;
    final notifier = ref.read(blitzControllerProvider.notifier);

    switch (activity.direction) {
      case AxisDirection.left:
        HapticFeedback.mediumImpact();
        notifier.reviewPendingLeft();
        break;

      case AxisDirection.right:
        HapticFeedback.lightImpact();
        notifier.reviewPendingRight();
        break;

      case AxisDirection.up:
        HapticFeedback.lightImpact();
        final success = notifier.reviewPendingUp();
        if (!success) {
          _showFavoritesFullWarning();
        }
        break;

      case AxisDirection.down:
        // 回放阶段禁用下滑，SwipeOptions 已阻止，此处为安全兜底
        break;
    }
  }

  /// 待定区回放阶段顶部标题
  Widget _buildPendingReviewHeader(BlitzState blitzState) {
    final current = blitzState.pendingReviewIndex + 1;
    final total = blitzState.sessionPending.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 返回按钮
          IconButton(
            onPressed: _showExitConfirmationBottomSheet,
            icon: const Icon(
              Icons.arrow_back_ios_rounded,
              color: Color(0xFF6B6560),
              size: 20,
            ),
          ),
          // 回放标题
          Column(
            children: [
              const Text(
                '📋 待定区回放',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4A4238),
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$current / $total',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          // 占位保持居中
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  /// 拍立得风格照片卡片
  ///
  /// [stampController] 可选，默认使用 _swiperController，
  /// 回放阶段传入 _pendingSwiperController。
  Widget _buildPhotoCard(
    AssetEntity photo,
    PhotoGroup group, {
    AppinioSwiperController? stampController,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 30,
            spreadRadius: 4,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                  left: 14, right: 14, top: 14, bottom: 2),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 照片层
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Colors.black.withValues(alpha: 0.05),
                          width: 1),
                    ),
                    child: AssetEntityImage(
                      photo,
                      isOriginal: false,
                      thumbnailSize: const ThumbnailSize(800, 800),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: const Color(0xFFF0EBE2),
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_rounded,
                              size: 48, color: Colors.black26),
                        );
                      },
                    ),
                  ),
                  // 连拍标记
                  if (group.isBurst)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${group.count} 张连拍',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  // 四方向印章层
                  _buildStampLayer(stampController),
                ],
              ),
            ),
          ),
          // 底部留白
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  /// 四方向印章层 — 随滑动方向显示不同标签
  ///
  /// [controller] 可选，默认使用 _swiperController。
  Widget _buildStampLayer([AppinioSwiperController? controller]) {
    final c = controller ?? _swiperController;
    return ListenableBuilder(
      listenable: c,
      builder: (context, child) {
        if (c.swipeProgress == null) {
          return const SizedBox.shrink();
        }

        final double dx = c.swipeProgress!.dx;
        final double dy = c.swipeProgress!.dy;
        if (dx == 0 && dy == 0) return const SizedBox.shrink();

        // 判断主方向
        final bool isHorizontal = dx.abs() >= dy.abs();
        final double opacity =
            ((isHorizontal ? dx.abs() : dy.abs()) * 1.5).clamp(0.0, 1.0);

        String label;
        Color stampColor;
        Alignment alignment;
        double angle;

        if (isHorizontal) {
          if (dx < 0) {
            label = 'DELETE';
            stampColor = const Color(0xFFB71C1C);
            alignment = Alignment.topRight;
            angle = 0.2;
          } else {
            label = 'KEEP';
            stampColor = const Color(0xFF5A7D55);
            alignment = Alignment.topLeft;
            angle = -0.2;
          }
        } else {
          if (dy < 0) {
            label = 'FAVE ❤️';
            stampColor = const Color(0xFFE91E63);
            alignment = Alignment.bottomCenter;
            angle = 0.0;
          } else {
            label = 'SKIP';
            stampColor = const Color(0xFF9E9E9E);
            alignment = Alignment.topCenter;
            angle = 0.0;
          }
        }

        return Positioned.fill(
          child: Align(
            alignment: alignment,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Opacity(
                opacity: opacity,
                child: Transform.rotate(
                  angle: angle,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: stampColor, width: 3.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: stampColor,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 单张待定照片的可滑动卡片组件
///
/// 使用 GestureDetector 实现三方向拖拽手势（左删除/右保留/上收藏），
/// 带位移追踪、旋转效果和飞出动画。
class _SwipeablePendingCard extends StatefulWidget {
  final AssetEntity photo;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;
  final VoidCallback onSwipeUp;

  const _SwipeablePendingCard({
    required this.photo,
    required this.onSwipeLeft,
    required this.onSwipeRight,
    required this.onSwipeUp,
  });

  @override
  State<_SwipeablePendingCard> createState() => _SwipeablePendingCardState();
}

class _SwipeablePendingCardState extends State<_SwipeablePendingCard>
    with SingleTickerProviderStateMixin {
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;

  /// 滑动阈值（超过此距离触发操作）
  static const double _threshold = 80.0;

  @override
  Widget build(BuildContext context) {
    final double rotation = _dragOffset.dx * 0.001; // 轻微旋转

    return GestureDetector(
      onPanStart: (_) {
        setState(() => _isDragging = true);
      },
      onPanUpdate: (details) {
        setState(() {
          _dragOffset += details.delta;
        });
      },
      onPanEnd: (_) {
        _isDragging = false;
        final dx = _dragOffset.dx;
        final dy = _dragOffset.dy;
        final isHorizontal = dx.abs() >= dy.abs();

        if (isHorizontal && dx.abs() > _threshold) {
          // 水平滑动超过阈值
          if (dx < 0) {
            widget.onSwipeLeft();
          } else {
            widget.onSwipeRight();
          }
        } else if (!isHorizontal && dy < -_threshold) {
          // 上滑超过阈值
          widget.onSwipeUp();
        }

        // 回弹（如果没有触发操作，回到原位）
        setState(() => _dragOffset = Offset.zero);
      },
      child: Transform.translate(
        offset: _dragOffset,
        child: Transform.rotate(
          angle: rotation,
          child: _buildCard(),
        ),
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 30,
            spreadRadius: 4,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                  left: 14, right: 14, top: 14, bottom: 2),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Colors.black.withValues(alpha: 0.05),
                          width: 1),
                    ),
                    child: AssetEntityImage(
                      widget.photo,
                      isOriginal: false,
                      thumbnailSize: const ThumbnailSize(800, 800),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: const Color(0xFFF0EBE2),
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_rounded,
                              size: 48, color: Colors.black26),
                        );
                      },
                    ),
                  ),
                  // 方向指示印章
                  if (_isDragging || _dragOffset != Offset.zero)
                    _buildDragStamp(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  /// 拖拽方向指示印章
  Widget _buildDragStamp() {
    final dx = _dragOffset.dx;
    final dy = _dragOffset.dy;
    if (dx == 0 && dy == 0) return const SizedBox.shrink();

    final bool isHorizontal = dx.abs() >= dy.abs();
    final double progress =
        ((isHorizontal ? dx.abs() : dy.abs()) / _threshold).clamp(0.0, 1.0);

    String label;
    Color stampColor;
    Alignment alignment;
    double angle;

    if (isHorizontal) {
      if (dx < 0) {
        label = 'DELETE';
        stampColor = const Color(0xFFB71C1C);
        alignment = Alignment.topRight;
        angle = 0.2;
      } else {
        label = 'KEEP';
        stampColor = const Color(0xFF5A7D55);
        alignment = Alignment.topLeft;
        angle = -0.2;
      }
    } else {
      if (dy < 0) {
        label = 'FAVE ❤️';
        stampColor = const Color(0xFFE91E63);
        alignment = Alignment.bottomCenter;
        angle = 0.0;
      } else {
        return const SizedBox.shrink(); // 下拖不显示印章
      }
    }

    return Positioned.fill(
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Opacity(
            opacity: progress,
            child: Transform.rotate(
              angle: angle,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: stampColor, width: 3.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: stampColor,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
