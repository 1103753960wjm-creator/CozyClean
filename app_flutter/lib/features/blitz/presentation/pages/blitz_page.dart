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

  /// 引导蒙版页
  Widget _buildOnboardingOverlay(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () {
          ref.read(blitzControllerProvider.notifier).dismissOnboarding();
        },
        child: Container(
          color: Colors.black.withValues(alpha: 0.65), // 半透明遮罩
          child: SafeArea(
            child: Stack(
              children: [
                // 上方指示
                const Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: 140),
                    child: Text(
                      '↑ 上滑高光',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                // 下方指示
                const Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 240),
                    child: Text(
                      '↓ 下滑待定',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                // 左侧指示
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: 24, bottom: 40),
                    child: Text(
                      '← 左滑删除',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                // 右侧指示
                const Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.only(right: 24, bottom: 40),
                    child: Text(
                      '右滑珍藏 →',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                // 底部边界提示：轻触任意位置继续
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 120),
                    child: Text(
                      '— 轻触任意位置继续 —',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
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
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '$currentIndex',
                      style: const TextStyle(
                        color: Color(0xFF4A4238),
                        fontSize: 26,
                        fontFamily: 'Georgia', // 衬线体
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    TextSpan(
                      text: ' / $total',
                      style: const TextStyle(
                        color: Color(0xFF8C867E),
                        fontSize: 16,
                        fontFamily: 'Georgia',
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              RichText(
                text: TextSpan(
                  children: [
                    const WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Icon(Icons.star_rounded,
                          color: Color(0xFFF7D154), size: 14),
                    ),
                    TextSpan(
                      text:
                          ' ${favoritesCount == 0 ? "0" : favoritesCount}/${BlitzState.maxFavorites}',
                      style: const TextStyle(
                        color: Color(0xFFF7D154),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
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
    return Padding(
      padding: const EdgeInsets.only(
          bottom: 12, left: 24, right: 24), // 缩小底边距，因为外设 Spacer
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
          // 2. 删除
          _buildCircleButton(
            icon: Icons.delete_outline_rounded, // 更细的删除标
            label: '删除',
            onTap: () {
              if (blitzState.isReviewingPending) {
                ref.read(blitzControllerProvider.notifier).reviewPendingLeft();
              } else {
                _swiperController.swipeLeft();
              }
            },
            color: const Color(0xFF8C7A76),
            size: 50,
          ),
          // 3. 稍后 (大粉圈)
          _buildCircleButton(
            icon: Icons.arrow_downward_rounded, // 箭头向下代替表盘
            label: '稍后',
            onTap: blitzState.isReviewingPending
                ? null
                : () => _swiperController.swipeDown(),
            color: const Color(0xFFC79E9A), // 粉偏棕色
            size: 70,
            isOutlined: true,
          ),
          // 4. 高光
          _buildCircleButton(
            icon: Icons.star_border_rounded, // 细心的星星
            label: '高光',
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
            color: const Color(0xFF8C7A76),
            size: 50,
          ),
          // 5. 珍藏
          _buildCircleButton(
            icon: Icons.favorite_border_rounded, // 留空的爱心
            label: '珍藏',
            onTap: () {
              if (blitzState.isReviewingPending) {
                ref.read(blitzControllerProvider.notifier).reviewPendingRight();
              } else {
                _swiperController.swipeRight();
              }
            },
            color: const Color(0xFF8C7A76),
            size: 50,
          ),
        ],
      ),
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

  /// 待定区计数器 — 按操作按钮下方显示
  ///
  /// 仅当 `pendingCount > 0` 且不在回放阶段时显示。
  /// 使用 `AnimatedSwitcher` 实现数字跳动效果，
  /// 以及 `AnimatedScale` 实现飞入时的弹跳反馈。
  Widget _buildPendingCounter(BlitzState blitzState) {
    final count = blitzState.pendingCount;
    // 回放阶段或无待定照片时不显示
    if (count == 0 || blitzState.isReviewingPending) {
      return const SizedBox(height: 20);
    }

    return AnimatedScale(
      scale: _showPendingFly ? 1.15 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      child: Padding(
        key: _pendingCounterKey,
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF6F0), // 浅暖白
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFE0D8CC), // 暖灰边框
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 14,
                color: Color(0xFFA89985),
              ),
              const SizedBox(width: 4),
              AnimatedSwitcher(
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
                    fontSize: 12,
                    color: Color(0xFF8A7D6D),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
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
              if (index < 0 || index >= pendingPhotos.length) {
                return const SizedBox.shrink();
              }
              final photo = pendingPhotos[index];
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
