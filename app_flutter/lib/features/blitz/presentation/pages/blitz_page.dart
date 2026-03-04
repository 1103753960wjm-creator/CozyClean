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
import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import 'package:cozy_clean/features/blitz/application/controllers/blitz_controller.dart';
import 'package:cozy_clean/features/blitz/application/state/blitz_state.dart';
import 'package:cozy_clean/features/blitz/domain/models/photo_group.dart';
import 'package:cozy_clean/features/profile/application/controllers/user_stats_controller.dart';
import 'package:cozy_clean/features/blitz/presentation/pages/summary_page.dart';

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

  /// 下滑飞入待定区动画状态
  bool _showPendingFly = false;

  /// 待定区计数器的 GlobalKey（用于定位飞入终点）
  final GlobalKey _pendingCounterKey = GlobalKey();

  // ============================================================
  // 生命周期
  // ============================================================

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(blitzControllerProvider.notifier).loadOnboardingStatus();
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

  void _requestUndo() {
    final blitzState = ref.read(blitzControllerProvider);
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

    if (blitzState.isReviewingPending) {
      _pendingSwiperController.unswipe();
    } else {
      _swiperController.unswipe();
    }
    HapticFeedback.mediumImpact();
  }

  void _navigateToSummary(BlitzState blitzState) {
    if (_isNavigating) return;
    _isNavigating = true;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => SummaryPage(
          deleteSet: blitzState.sessionDeleted,
          favoriteSet: blitzState.sessionFavorites,
          totalReviewedCount: blitzState.totalPhotoCount,
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
        // 触发待定区计数器弹跳动画
        _triggerPendingFlyAnimation();
        break;
    }
  }

  /// 收藏已满提示
  void _showFavoritesFullWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            const Text('收藏已满 6 张，先去生成手账海报吧 ✨', textAlign: TextAlign.center),
        backgroundColor: const Color(0xFFFFD54F),
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

    if (!blitzState.onboardingLoaded) {
      return const SizedBox.shrink();
    }

    // 监听全部处理完毕 → 检查是否需要进入待定区回放
    ref.listen(blitzControllerProvider, (previous, next) {
      if (!next.isLoading &&
          next.photoGroups.isNotEmpty &&
          !next.hasNextGroup &&
          !next.isReviewingPending) {
        if (next.hasPendingPhotos && !next.isPendingReviewFinished) {
          ref.read(blitzControllerProvider.notifier).enterPendingReview();
        } else if (!next.hasPendingPhotos) {
          _navigateToSummary(next);
        }
      }

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
                  _buildEdgeGradientsLayer(blitzState),
                  _buildPendingReviewSwiper(blitzState),
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
      Stack(
        children: [
          Column(
            children: [
              _buildTopBar(
                context,
                blitzState.currentPhotoNumber,
                blitzState.totalPhotoCount,
                blitzState.favoritesCount,
              ),
              Expanded(
                child: Stack(
                  children: [
                    _buildEdgeGradientsLayer(blitzState),
                    _buildSwiperContainer(blitzState),
                  ],
                ),
              ),
              _buildActionButtons(blitzState),
              _buildPendingCounter(blitzState),
              const SizedBox(height: 12),
            ],
          ),
          if (blitzState.showOnboarding) _buildOnboardingOverlay(context),
        ],
      ),
    );
  }

  // ============================================================
  // UI 组件构建
  // ============================================================

  Widget _buildOnboardingOverlay(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () {
          ref.read(blitzControllerProvider.notifier).dismissOnboarding();
        },
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            color: Colors.black.withOpacity(0.5), // Semi-transparent overlay
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Intructions
                  Padding(
                    padding: const EdgeInsets.only(top: 32),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5A7D55)
                                .withOpacity(0.2), // primary/20
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.2)),
                          ),
                          child: const Text('手势操作指南',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 14)),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '轻松整理您的回忆',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Central Interaction Guide
                  Center(
                    child: SizedBox(
                      width: 280,
                      height: 340,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          // Central Box
                          Container(
                            width: 180,
                            height: 240,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.4),
                                width: 2,
                                style: BorderStyle.solid,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: Icon(Icons.photo_library_outlined,
                                  size: 48, color: Colors.white54),
                            ),
                          ),
                          // Top Arrow (Highlight)
                          const Positioned(
                            top: -40,
                            child: Column(
                              children: [
                                Text('↑ 上滑高光',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          // Bottom Arrow (Skip)
                          const Positioned(
                            bottom: -40,
                            child: Column(
                              children: [
                                Text('↓ 下滑待定',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          // Left Arrow (Delete)
                          const Positioned(
                            left: -60,
                            child: Row(
                              children: [
                                Text('← 左滑删除',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          // Right Arrow (Keep)
                          const Positioned(
                            right: -60,
                            child: Row(
                              children: [
                                Text('右滑珍藏 →',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          // Mascot Icon
                          Positioned(
                            bottom: -20,
                            right: 0,
                            child: Transform.rotate(
                              angle: 0.2,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFDFBF7),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: const Color(0xFF5A7D55)
                                          .withOpacity(0.3),
                                      width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 8)
                                  ],
                                ),
                                child: const Icon(Icons.face_6_rounded,
                                    color: Color(0xFF5A7D55), size: 32),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Action
                  Padding(
                    padding:
                        const EdgeInsets.only(bottom: 40, left: 40, right: 40),
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.draw_rounded,
                                color: Colors.white70, size: 16),
                            SizedBox(width: 4),
                            Text('随心滑动，让相册保持整洁',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDFBF7),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0xFFD1D5DB),
                                  offset: Offset(0, 4))
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('开始体验',
                                  style: TextStyle(
                                      color: Color(0xFF1F2937),
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 4)),
                              SizedBox(width: 12),
                              Icon(Icons.touch_app_rounded,
                                  color: Color(0xFF5A7D55)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
      BuildContext context, int currentIndex, int total, int favoritesCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 左侧：圆形返回按键
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: Color(0xFF6B6560), size: 24),
              onPressed: () {
                final state = ref.read(blitzControllerProvider);
                if (state.sessionDeleted.isEmpty) {
                  Navigator.maybePop(context);
                } else {
                  _showExitConfirmationBottomSheet();
                }
              },
            ),
          ),
          // 右侧：进度和收藏
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Transform.rotate(
                angle: -0.017, // ~ -1 deg (rotate-slight-left)
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$currentIndex',
                      style: const TextStyle(
                        color: Color(0xFF4A4238),
                        fontSize: 32,
                        fontFamily: 'Georgia',
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      '/',
                      style: TextStyle(
                        color: Color(0xFF8C7A6B),
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$total',
                      style: TextStyle(
                        color: const Color(0xFF8C7A6B).withValues(alpha: 0.6),
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // 右侧：高光进度特效组件
              _HighlightCounter(
                  count: favoritesCount, maxCount: BlitzState.maxFavorites),
            ],
          ),
        ],
      ),
    );
  }

  /// 空状态
  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 相册大图插画
                  Image.asset(
                    'assets/images/empty_album_illustration.png',
                    width: 220,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 32),
                  // 主标题
                  const Text(
                    '相册干干净净',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF6F5643), // 深棕色
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 副标题
                  const Text(
                    '今天没有需要告别的废片了，\n留下的全都是宝贵的记忆。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9E9689), // 浅灰褐色
                      height: 1.8,
                    ),
                  ),
                  const SizedBox(height: 48),
                  // "去翻翻手账" 按钮
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8A6549), // 棕色实体背景
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    icon: const Icon(Icons.menu_book_rounded, size: 20),
                    label: const Text(
                      '去翻翻手账',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    onPressed: () {
                      // 暂退回主界面，后续可引入路由跳至手账 Tab
                      Navigator.maybePop(context);
                    },
                  ),
                  const SizedBox(height: 16),
                  // "再整理一次" 按钮
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF8A6549), // 字与图标颜色
                      side: const BorderSide(
                          color: Color(0xFFD4CBBB), width: 1.5), // 边框
                      backgroundColor: Colors.transparent,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: const Text(
                      '再整理一次',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    onPressed: () {
                      ref
                          .read(blitzControllerProvider.notifier)
                          .resetAllPhotoActions();
                    },
                  ),
                  const SizedBox(height: 32),
                  // "休息一下" 底部文字按钮
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: const Text(
                      '休息一下',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFFB5A995),
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 底部操作区 (5个圆形按钮)
  Widget _buildActionButtons(BlitzState blitzState) {
    final controller = blitzState.isReviewingPending
        ? _pendingSwiperController
        : _swiperController;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        double deleteProgress = 0.0;
        double keepProgress = 0.0;
        double highlightProgress = 0.0;
        double pendingProgress = 0.0;

        final progress = controller.swipeProgress;
        if (progress != null) {
          final dx = progress.dx;
          final dy = progress.dy;
          if (dx == 0 && dy == 0) {
            // unchanged
          } else if (dx.abs() >= dy.abs()) {
            if (dx < 0) {
              deleteProgress = (dx.abs() * 1.5).clamp(0.0, 1.0);
            } else {
              keepProgress = (dx.abs() * 1.5).clamp(0.0, 1.0);
            }
          } else {
            if (dy < 0) {
              highlightProgress = (dy.abs() * 1.5).clamp(0.0, 1.0);
            } else {
              pendingProgress = (dy.abs() * 1.5).clamp(0.0, 1.0);
            }
          }
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12, left: 24, right: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 1. 撤销
              _buildCircleButton(
                icon: Icons.replay_rounded,
                label: '撤销',
                onTap: _requestUndo,
                color: const Color(0xFF9E9E9E),
                size: 50,
              ),
              // 2. 删除 (红)
              _buildDynamicActionButton(
                outlineIcon: Icons.delete_outline_rounded,
                solidIcon: Icons.delete_rounded,
                label: '删除',
                baseSize: 50,
                activeColor: const Color(0xFFE57373),
                activeBorderColor: const Color(0xFFFFCDD2),
                progress: deleteProgress,
                onTap: () {
                  if (blitzState.isReviewingPending) {
                    _pendingSwiperController.swipeLeft();
                  } else {
                    _swiperController.swipeLeft();
                  }
                },
              ),
              // 3. 稍后/待定 (粉边圈转蓝)
              Visibility(
                visible: !blitzState.isReviewingPending,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: _buildDynamicActionButton(
                  outlineIcon: Icons.arrow_downward_rounded,
                  solidIcon: Icons.arrow_downward_rounded,
                  label: '稍后',
                  baseSize: 70,
                  baseBorderColor:
                      const Color(0xFFC79E9A).withValues(alpha: 0.5),
                  activeColor: const Color(0xFF64B5F6),
                  activeBorderColor: const Color(0xFFBBDEFB),
                  progress: pendingProgress,
                  onTap: blitzState.isReviewingPending
                      ? null
                      : () => _swiperController.swipeDown(),
                ),
              ),
              // 4. 高光 (金)
              _buildDynamicActionButton(
                outlineIcon: Icons.star_border_rounded,
                solidIcon: Icons.star_rounded,
                label: '高光',
                baseSize: 50,
                activeColor: const Color(0xFFFFD54F),
                activeBorderColor: const Color(0xFFFFE082),
                progress: highlightProgress,
                onTap: () {
                  if (blitzState.isReviewingPending) {
                    _pendingSwiperController.swipeUp();
                  } else {
                    _swiperController.swipeUp();
                  }
                },
              ),
              // 5. 珍藏 (绿)
              _buildDynamicActionButton(
                outlineIcon: Icons.favorite_border_rounded,
                solidIcon: Icons.favorite_rounded,
                label: '珍藏',
                baseSize: 50,
                activeColor: const Color(0xFF5A7D55),
                activeBorderColor: const Color(0xFFA5D6A7),
                progress: keepProgress,
                onTap: () {
                  if (blitzState.isReviewingPending) {
                    // [修复] 复审阶段按钮点击时也触发滑动动画，而非直接调用 controller
                    _pendingSwiperController.swipeRight();
                  } else {
                    _swiperController.swipeRight();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// 动态变化的反馈操作按钮
  Widget _buildDynamicActionButton({
    required IconData outlineIcon,
    required IconData solidIcon,
    required String label,
    required VoidCallback? onTap,
    required double progress,
    required double baseSize,
    required Color activeColor,
    required Color activeBorderColor,
    Color? baseBorderColor,
  }) {
    final size = baseSize + (14.0 * progress);
    final bgColor = Color.lerp(Colors.white, activeColor, progress)!;
    final iconColor =
        Color.lerp(const Color(0xFF8C7A76), Colors.white, progress)!;
    final borderColor = Color.lerp(baseBorderColor ?? const Color(0xFFE5DFD3),
        activeBorderColor, progress)!;
    final textColor =
        Color.lerp(const Color(0xFF8C867E), activeColor, progress)!;
    final glowOpacity = (progress * 0.5).clamp(0.0, 0.5);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 1 + progress),
              boxShadow: [
                if (progress == 0)
                  BoxShadow(
                    color: const Color(0xFF8C7A76).withValues(alpha: 0.08),
                    blurRadius: 10,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                if (progress > 0)
                  BoxShadow(
                    color: activeColor.withValues(alpha: glowOpacity),
                    blurRadius: 15,
                    spreadRadius: 4,
                  ),
              ],
            ),
            child: Icon(
              progress > 0.1 ? solidIcon : outlineIcon,
              color: iconColor,
              size: size * 0.45,
            ),
          ),
        ),
        SizedBox(height: 8 - (progress * 2)),
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: progress > 0 ? FontWeight.bold : FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required Color color,
    required double size,
    bool isOutlined = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white, // 统一白底
              shape: BoxShape.circle,
              border: Border.all(
                  color: isOutlined
                      ? color.withValues(alpha: 0.5)
                      : const Color(0xFFE5DFD3), // 普通色系给予极浅的描边
                  width: isOutlined ? 2 : 1),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.08),
                  blurRadius: 10,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: color,
              size: size * 0.45,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8C867E), // 字体统一灰褐
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  /// 四方向边缘渐变高亮预警
  Widget _buildEdgeGradientsLayer(BlitzState blitzState) {
    final controller = blitzState.isReviewingPending
        ? _pendingSwiperController
        : _swiperController;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final progress = controller.swipeProgress;
        if (progress == null) return const SizedBox.shrink();

        final dx = progress.dx;
        final dy = progress.dy;
        if (dx == 0 && dy == 0) return const SizedBox.shrink();

        final isHorizontal = dx.abs() >= dy.abs();
        final opacity =
            ((isHorizontal ? dx.abs() : dy.abs()) * 1.5).clamp(0.0, 1.0);

        List<Color> gradientColors;
        Alignment begin;
        Alignment end;
        double? left, right, top, bottom;
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;

        double width = screenWidth;
        double height = screenHeight;

        if (isHorizontal) {
          top = 0;
          bottom = 0;
          width = screenWidth / 3.5;
          if (dx < 0) {
            // Delete: Left, Red
            left = 0;
            begin = Alignment.centerLeft;
            end = Alignment.centerRight;
            gradientColors = [
              const Color(0xFFE57373).withValues(alpha: 0.25),
              Colors.transparent
            ];
          } else {
            // Keep: Right, Green
            right = 0;
            begin = Alignment.centerRight;
            end = Alignment.centerLeft;
            gradientColors = [
              const Color(0xFF5A7D55).withValues(alpha: 0.25),
              Colors.transparent
            ];
          }
        } else {
          left = 0;
          right = 0;
          height = screenHeight / 3.5;
          if (dy < 0) {
            // Highlight: Top, Gold
            top = 0;
            begin = Alignment.topCenter;
            end = Alignment.bottomCenter;
            gradientColors = [
              const Color(0xFFFFD54F).withValues(alpha: 0.25),
              Colors.transparent
            ];
          } else {
            // Pending: Bottom, Blue
            bottom = 0;
            begin = Alignment.bottomCenter;
            end = Alignment.topCenter;
            gradientColors = [
              const Color(0xFF64B5F6).withValues(alpha: 0.25),
              Colors.transparent
            ];
          }
        }

        return Positioned(
          left: left,
          right: right,
          top: top,
          bottom: bottom,
          width:
              (left != null || right != null) && (left == null || right == null)
                  ? width
                  : null,
          height:
              (top != null || bottom != null) && (top == null || bottom == null)
                  ? height
                  : null,
          child: Opacity(
            opacity: opacity,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: begin,
                  end: end,
                  colors: gradientColors,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 待定区计数器 — 按操作按钮下方显示 (参照原型：层叠白纸与浮动提示)
  ///
  /// 仅当 `pendingCount > 0` 且不在回放阶段时显示。
  Widget _buildPendingCounter(BlitzState blitzState) {
    final count = blitzState.pendingCount;
    // 回放阶段或无待定照片时不显示
    if (count == 0 || blitzState.isReviewingPending) {
      return const SizedBox(height: 60); // 占相同高度防止跳动
    }

    // “张待定” 文本
    final textWidget = AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.5),
            end: Offset.zero,
          ).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: Text(
        '$count张待定',
        key: ValueKey<int>(count),
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF4A3B32), // text-main
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );

    return AnimatedScale(
      scale: _showPendingFly ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      child: SizedBox(
        key: _pendingCounterKey,
        height: 60, // 为底部重叠留出固定高度
        child: Stack(
          clipBehavior: Clip.none, // 允许提示框和纸张浮出边界
          alignment: Alignment.bottomCenter,
          children: [
            // 底层纸张 1 (-6度)
            Positioned(
              bottom: -15,
              child: Transform.rotate(
                angle: -0.104, // ~ -6 deg
                child: Container(
                  width: 128, // w-32
                  height: 64, // h-16
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border:
                        Border.all(color: const Color(0xFFE5E7EB)), // stone-200
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 中层纸张 2 (3度)
            Positioned(
              bottom: -15,
              child: Transform.rotate(
                angle: 0.052, // ~ 3 deg
                child: Container(
                  width: 128,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 最上层纸张 3 (-1度 + 更深阴影)
            Positioned(
              bottom: -15,
              child: Transform.rotate(
                angle: -0.017, // ~ -1 deg
                child: Container(
                  width: 128,
                  height: 64,
                  padding: const EdgeInsets.only(top: 8),
                  alignment: Alignment.topCenter,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, -3), // shadow-polaroid
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 浮动带有倒三角的文字气泡
            Positioned(
              bottom: 25, // 向上浮动盖过半张纸
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDFBF7), // bg-paper
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFFD2B48C)), // border-[#D2B48C]
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: textWidget,
                  ),
                  // 手动绘制小倒三角
                  Transform.translate(
                    offset: const Offset(0, -1), // 往上微移避免缝隙
                    child: CustomPaint(
                      size: const Size(8, 6),
                      painter: _TooltipTrianglePainter(
                          color: const Color(0xFFD2B48C)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 触发待定区计数器的弹跳反馈动画
  ///
  /// 下滑跳过时调用，让计数器短暂放大再恢复，
  /// 配合触觉反馈提示用户照片已进入待定区。
  void _triggerPendingFlyAnimation() {
    if (!mounted) return;
    setState(() => _showPendingFly = true);
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _showPendingFly = false);
    });
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
                  backgroundColor: const Color(0xFFFFD54F),
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
              return _buildPhotoCard(
                group.bestPhoto,
                group,
                isForeground: index == blitzState.currentGroupIndex,
              );
            },
          ),
        ),
      ),
    );
  }

  /// 待定区回放 Swiper — 三方向（禁用下滑）
  ///
  /// cardCount 使用 sessionPending.length（固定值），
  /// 不随 pendingReviewIndex 变化，避免 Swiper 内部索引混乱。
  /// 单张时使用 _SwipeablePendingCard 替代 AppinioSwiper。
  Widget _buildPendingReviewSwiper(BlitzState blitzState) {
    final pendingPhotos = blitzState.sessionPending;
    final total = pendingPhotos.length;

    if (total <= 0) return const SizedBox.shrink();

    // 单张时直接展示卡片 + 手势滑动，不使用 AppinioSwiper
    if (total == 1) {
      final photo = pendingPhotos[0];
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
            // cardCount 固定为总数，Swiper 内部管理滑动进度
            cardCount: total,
            backgroundCardCount: total > 2 ? 2 : 1,
            backgroundCardScale: 0.92,
            backgroundCardOffset: const Offset(0, 15),
            // [修复] 启用全方向滑动，防止因方向限制导致的手势处理卡顿
            swipeOptions: const SwipeOptions.all(),
            onSwipeEnd:
                (int previousIndex, int targetIndex, SwiperActivity activity) {
              _handlePendingSwipeEnd(activity);
            },
            onEnd: () {
              // 回放完毕由 ref.listen 检测 isPendingReviewFinished 处理
            },
            cardBuilder: (BuildContext context, int index) {
              if (index < 0 || index >= pendingPhotos.length) {
                return const SizedBox.shrink();
              }
              final photo = pendingPhotos[index];
              // 回放复用拍立得卡片，传入回放专用 controller 以正确显示印章
              return _buildPhotoCard(
                photo,
                PhotoGroup(photos: [photo]),
                stampController: _pendingSwiperController,
                isForeground: index == blitzState.pendingReviewIndex,
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
          // [修复] 收藏满且在回放阶段时，也需要执行 unswipe 弹回卡片
          _pendingSwiperController.unswipe();
          _showFavoritesFullWarning();
        }
        break;

      case AxisDirection.down:
        // [修复] 回放阶段虽然启用下滑以保证手势流畅，但不执行实际逻辑，弹回卡片
        _pendingSwiperController.unswipe();
        break;
    }
  }

  /// 待定区回放阶段顶栏
  Widget _buildPendingReviewHeader(BlitzState blitzState) {
    final current = blitzState.pendingReviewIndex + 1;
    final total = blitzState.sessionPending.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 圆形返回按键 (保持与主流程一致)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              onPressed: _showExitConfirmationBottomSheet,
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFF6B6560),
                size: 24,
              ),
            ),
          ),

          // 回放状态标题
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '📋 待定区复审',
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

          // [修复] 增加高光进度组件，即使在回放阶段用户也需要看到收藏进度
          _HighlightCounter(
            count: blitzState.favoritesCount,
            maxCount: BlitzState.maxFavorites,
          ),
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
    bool isForeground = true,
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
                  // 四方向印章层 (仅在最前台卡片显示)
                  if (isForeground) _buildStampLayer(stampController),
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
        String subLabel;
        IconData iconData;
        Color stampColor;
        double angle;

        if (isHorizontal) {
          if (dx < 0) {
            label = 'DELETE';
            subLabel = '删除';
            iconData = Icons.delete_outline_rounded;
            stampColor = const Color(0xFFE57373);
            angle = -0.2;
          } else {
            label = 'KEEP';
            subLabel = '珍藏';
            iconData = Icons.favorite_rounded;
            stampColor = const Color(0xFF5A7D55);
            angle = 0.2;
          }
        } else {
          if (dy < 0) {
            label = 'FAVE';
            subLabel = '高光';
            iconData = Icons.star_rounded;
            stampColor = const Color(0xFFFFD54F);
            angle = -0.15;
          } else {
            label = 'SKIP';
            subLabel = '待定';
            iconData = Icons.arrow_downward_rounded;
            stampColor = const Color(0xFF64B5F6);
            angle = 0.15;
          }
        }

        return Positioned.fill(
          child: Opacity(
            opacity: opacity,
            child: Container(
              color: Colors.black.withOpacity(0.15), // 背景统一变灰暗
              child: Center(
                child: Transform.rotate(
                  angle: angle,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                      border: Border.all(color: stampColor, width: 6),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: stampColor.withOpacity(0.6), width: 2),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(iconData, color: stampColor, size: 48),
                            Text(
                              label,
                              style: TextStyle(
                                color: stampColor,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subLabel,
                              style: TextStyle(
                                color: stampColor,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 4,
                              ),
                            ),
                          ],
                        ),
                      ],
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
  late AnimationController _snapController;
  late Animation<Offset> _snapAnimation;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _snapAnimation = _snapController.drive(
      Tween<Offset>(begin: Offset.zero, end: Offset.zero),
    );
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

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
          // 触发后不需回弹动画，直接重置位移以便下一张（或已移除）
          setState(() => _dragOffset = Offset.zero);
        } else if (!isHorizontal && dy < -_threshold) {
          // 上滑超过阈值
          widget.onSwipeUp();
          setState(() => _dragOffset = Offset.zero);
        } else {
          // [修复] 未触发操作时，执行平滑回弹动画
          _snapAnimation = _snapController.drive(
            Tween<Offset>(begin: _dragOffset, end: Offset.zero),
          );
          _snapController.forward(from: 0.0).then((_) {
            if (mounted) setState(() => _dragOffset = Offset.zero);
          });
        }
      },
      child: AnimatedBuilder(
        animation: _snapController,
        builder: (context, child) {
          final offset = _isDragging ? _dragOffset : _snapAnimation.value;
          final double rotation = offset.dx * 0.001; // 轻微旋转
          return Transform.translate(
            offset: offset,
            child: Transform.rotate(
              angle: rotation,
              child: _buildCard(offset),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard(Offset currentOffset) {
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
                  if (_isDragging || _snapController.isAnimating)
                    _buildDragStamp(currentOffset),
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
  Widget _buildDragStamp(Offset offset) {
    final dx = offset.dx;
    final dy = offset.dy;
    if (dx == 0 && dy == 0) return const SizedBox.shrink();

    final bool isHorizontal = dx.abs() >= dy.abs();
    final double progress =
        ((isHorizontal ? dx.abs() : dy.abs()) / _threshold).clamp(0.0, 1.0);

    String label;
    String subLabel;
    IconData iconData;
    Color stampColor;
    double angle;

    if (isHorizontal) {
      if (dx < 0) {
        label = 'DELETE';
        subLabel = '删除';
        iconData = Icons.delete_outline_rounded;
        stampColor = const Color(0xFFE57373);
        angle = -0.2;
      } else {
        label = 'KEEP';
        subLabel = '珍藏';
        iconData = Icons.favorite_rounded;
        stampColor = const Color(0xFF5A7D55);
        angle = 0.2;
      }
    } else {
      if (dy < 0) {
        label = 'FAVE';
        subLabel = '高光';
        iconData = Icons.star_rounded;
        stampColor = const Color(0xFFFFD54F);
        angle = -0.15;
      } else {
        label = 'SKIP';
        subLabel = '待定';
        iconData = Icons.arrow_downward_rounded;
        stampColor = const Color(0xFF64B5F6);
        angle = 0.15;
      }
    }

    return Positioned.fill(
      child: Opacity(
        opacity: progress,
        child: Container(
          color: Colors.black.withOpacity(0.15),
          child: Center(
            child: Transform.rotate(
              angle: angle,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                  border: Border.all(color: stampColor, width: 6),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: stampColor.withOpacity(0.6), width: 2),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(iconData, color: stampColor, size: 48),
                        Text(
                          label,
                          style: TextStyle(
                            color: stampColor,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subLabel,
                          style: TextStyle(
                            color: stampColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tooltip 底部倒三角绘制器
class _TooltipTrianglePainter extends CustomPainter {
  final Color color;

  _TooltipTrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    var path = Path();
    path.moveTo(0, 0); // 左上
    path.lineTo(size.width, 0); // 右上
    path.lineTo(size.width / 2, size.height); // 底部顶点
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _TooltipTrianglePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

// ============================================================================
// 原型：上滑高光计件动画组件
// ============================================================================

class _HighlightCounter extends StatefulWidget {
  final int count;
  final int maxCount;

  const _HighlightCounter({required this.count, required this.maxCount});

  @override
  State<_HighlightCounter> createState() => _HighlightCounterState();
}

class _HighlightCounterState extends State<_HighlightCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    _scaleAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.95), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut)); // 替换 easeOutBack，防止 t 越界引发 TweenSequence 断言错误

    // 发光脉冲曲线：快速亮起，缓慢消失
    _glowAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 80),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(_HighlightCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count > oldWidget.count) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // 背景发光扩散层 (Pulse Glow) - 完全基于原型 shadow-glow 的动态增强
            if (_glowAnimation.value > 0.01)
              Transform.scale(
                scale: 1.0 + 0.8 * _glowAnimation.value,
                child: Container(
                  width: 50,
                  height: 18,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD54F)
                            .withValues(alpha: 0.3 * _glowAnimation.value),
                        blurRadius: 15 * _glowAnimation.value,
                        spreadRadius: 8 * _glowAnimation.value,
                      ),
                      BoxShadow(
                        color: const Color(0xFFFFD54F)
                            .withValues(alpha: 0.5 * _glowAnimation.value),
                        blurRadius: 5 * _glowAnimation.value,
                        spreadRadius: 2 * _glowAnimation.value,
                      ),
                    ],
                  ),
                ),
              ),

            // 前景药丸
            Transform.rotate(
              angle: 0.035, // 2 deg (rotate-slight-right)
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15), // 微弱背景手感
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFFD54F).withValues(
                        alpha: widget.count > 0 ? 0.3 : 0.1,
                      ),
                      width: 1,
                    ),
                    // 内部发光 (Inner Glow)
                    boxShadow: [
                      if (_glowAnimation.value > 0.01)
                        BoxShadow(
                          color: const Color(0xFFFFD54F)
                              .withValues(alpha: 0.6 * _glowAnimation.value),
                          blurRadius: 10 * _glowAnimation.value,
                          spreadRadius: 1 * _glowAnimation.value,
                        ),
                      // 静态发光阴影
                      BoxShadow(
                        color: const Color(0xFFFFD54F).withValues(alpha: 0.05),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFFFD54F),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.count}/${widget.maxCount}',
                        style: const TextStyle(
                          color: Color(0xFFFFD54F),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Georgia',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
