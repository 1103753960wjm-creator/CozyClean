/// CozyClean — 闪电战核心展示主页
///
/// UI 层职责说明：
///   本页面是分层架构中的 **纯展示层**，职责严格限定为：
///   1. 通过 ref.watch 监听 [BlitzState] 的变化并重建 UI
///   2. 通过 ref.read 调用 [BlitzController] 的方法响应用户交互
///   3. 管理页面级的动画状态（如撤销反馈动效）
///
///   本页面 **不负责** 以下逻辑：
///   - ❌ 访问数据库（AppDatabase）
///   - ❌ 访问相册（PhotoManager）
///   - ❌ 执行连拍分组（BurstGroupingService）
///   - ❌ 管理体力值计算
///   - ❌ 管理照片去重过滤
///
///   这样做的原因：
///   - build() 保持纯净，不包含任何 IO 或计算密集操作
///   - 业务逻辑变更时只需修改 Controller，UI 无需改动
///   - 便于独立测试 UI 组件（Mock Controller 即可）
///
/// 图片展示策略：
///   使用 photo_manager 的 [AssetEntityImage] 组件，
///   设置 isOriginal: false 确保只加载缩略图，
///   绝不在列表视图中加载原图（规范第 5、11 条）。
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

/// 闪电战核心展示主页
///
/// 纯展示组件，所有交互均委托给 [BlitzController]。
/// build() 方法中不包含任何 IO、数据库、相册访问或业务计算。
class BlitzPage extends ConsumerStatefulWidget {
  const BlitzPage({super.key});

  @override
  ConsumerState<BlitzPage> createState() => _BlitzPageState();
}

class _BlitzPageState extends ConsumerState<BlitzPage> {
  final AppinioSwiperController _swiperController = AppinioSwiperController();

  /// 导航保险锁，避免同时触发监听器和插件的回调
  bool _isNavigating = false;

  /// 撤销动效播放标志
  bool _isUndoAnimating = false;

  // ============================================================
  // 生命周期
  // ============================================================

  @override
  void initState() {
    super.initState();
    // 委托 Controller 加载照片（所有 IO 在 Controller 内完成）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(blitzControllerProvider.notifier).loadPhotos();
    });
  }

  @override
  void dispose() {
    _swiperController.dispose();
    super.dispose();
  }

  // ============================================================
  // 页面级交互方法（仅调用 Controller，不含业务逻辑）
  // ============================================================

  /// 触发撤销反馈动效（纯 UI 行为）
  void _triggerUndoAnimation() {
    if (!mounted) return;
    setState(() => _isUndoAnimating = true);
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      setState(() => _isUndoAnimating = false);
    });
  }

  /// 请求撤销上一次滑动 — 调用 Controller 并播放 UI 反馈
  void _requestUndo() {
    final success = ref.read(blitzControllerProvider.notifier).undoLastSwipe();
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              const Text('只能撤回刚刚滑走的那一张照片哦 😅', textAlign: TextAlign.center),
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

  /// 导航到结算页 — 纯路由操作
  void _navigateToSummary(List<AssetEntity> skippedPhotos) {
    if (_isNavigating) return;
    _isNavigating = true;

    final state = ref.read(blitzControllerProvider);
    final totalReviewed = state.photoGroups.length;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => SummaryPage(
          deleteSet: skippedPhotos,
          totalReviewedCount: totalReviewed,
        ),
      ),
    );
  }

  /// 处理滑动结束事件 — 调用 Controller 方法
  Future<void> _handleSwipeEnd(
    SwiperActivity activity,
    AssetEntity photo,
  ) async {
    final notifier = ref.read(blitzControllerProvider.notifier);

    if (activity is Swipe) {
      if (activity.direction == AxisDirection.left) {
        HapticFeedback.mediumImpact();
        final success = await notifier.swipeLeft(photo);
        if (!success) {
          _swiperController.unswipe();
          _showNoEnergyWarning();
        }
      } else if (activity.direction == AxisDirection.right) {
        HapticFeedback.lightImpact();
        final success = await notifier.swipeRight(photo);
        if (!success) {
          _swiperController.unswipe();
          _showNoEnergyWarning();
        }
      }
    }
  }

  // ============================================================
  // build — 纯展示，无 IO / 无计算
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final blitzState = ref.watch(blitzControllerProvider);

    // 监听全部处理完毕 → 自动跳转结算页
    ref.listen(blitzControllerProvider, (previous, next) {
      if (!next.isLoading &&
          next.photoGroups.isNotEmpty &&
          !next.hasNextGroup) {
        _navigateToSummary(next.skipped);
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
            child: _buildSwiperContainer(blitzState),
          ),
          _buildActionButtons(),
        ],
      ),
    );
  }

  // ============================================================
  // UI 组件构建方法
  // ============================================================

  /// 退出确认底部弹窗
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
                '你有 ${state.skippedCount} 张废片待清理，要现在归档吗？',
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
                        // 清空内存草稿，放弃本次操作
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
                        _navigateToSummary(state.skipped);
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
      canPop: ref.watch(blitzControllerProvider).skipped.isEmpty,
      onPopInvoked: (didPop) {
        if (didPop) {
          // 无废片时直接退出，但如有收藏需提交
          final state = ref.read(blitzControllerProvider);
          if (state.favorites.isNotEmpty) {
            ref.read(userStatsControllerProvider).commitBlitzSession(
                  keeps: state.favorites.map((p) => p.id).toSet(),
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
              if (state.skipped.isEmpty) {
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

  /// 全部整理完毕的空状态展示
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
                color: const Color(0xFF8BA888).withOpacity(0.15),
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
                shadowColor: const Color(0xFF8BA888).withOpacity(0.4),
              ),
              onPressed: () {
                // 委托 Controller 处理（不直接访问数据库）
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

  /// 底部操作按钮（丢弃 / 保留 / 撤销）
  Widget _buildActionButtons() {
    return SizedBox(
      height: 100,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _swiperController.swipeLeft(),
                child: Container(
                  color: Colors.transparent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                  child: Text(
                    '丢弃',
                    style: TextStyle(
                      color: Colors.red[300]!.withOpacity(0.8),
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 40),
              GestureDetector(
                onTap: () => _swiperController.swipeRight(),
                child: Container(
                  color: Colors.transparent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                  child: Text(
                    '保留',
                    style: TextStyle(
                      color: const Color(0xFF8BA888).withOpacity(0.8),
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // 撤销按钮
          Positioned(
            left: 20,
            bottom: 70,
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
                        color: Colors.black.withOpacity(0.05),
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
            bottom: 138,
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
                    color: Colors.white.withOpacity(0.95),
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

  /// 体力耗尽警告弹窗
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

  /// Swiper 卡片容器
  ///
  /// 使用 [AssetEntityImage] 展示缩略图（isOriginal: false），
  /// 绝不在列表中加载原图（规范第 5 条）。
  Widget _buildSwiperContainer(BlitzState blitzState) {
    final groups = blitzState.photoGroups;

    return Center(
      child: AspectRatio(
        aspectRatio: 0.80,
        child: Padding(
          padding: const EdgeInsets.only(left: 30, right: 30, bottom: 20),
          child: AppinioSwiper(
            controller: _swiperController,
            cardCount: groups.length,
            backgroundCardCount: 2,
            backgroundCardScale: 0.92,
            backgroundCardOffset: const Offset(0, 15),
            onSwipeEnd:
                (int previousIndex, int targetIndex, SwiperActivity activity) {
              if (previousIndex < 0 || previousIndex >= groups.length) return;
              final photo = groups[previousIndex].bestPhoto;
              _handleSwipeEnd(activity, photo);
            },
            onEnd: () {
              final currentState = ref.read(blitzControllerProvider);
              _navigateToSummary(currentState.skipped);
            },
            cardBuilder: (BuildContext context, int index) {
              if (index < 0 || index >= groups.length) {
                return const SizedBox.shrink();
              }
              final group = groups[index];
              final photo = group.bestPhoto;

              return _buildPhotoCard(photo, group);
            },
          ),
        ),
      ),
    );
  }

  /// 拍立得风格照片卡片
  ///
  /// 使用 [AssetEntityImage] 直接渲染缩略图，
  /// isOriginal: false 确保内存安全（规范第 5、11 条）。
  Widget _buildPhotoCard(AssetEntity photo, PhotoGroup group) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
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
                  // 照片层 — 使用 AssetEntityImage 缩略图
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Colors.black.withOpacity(0.05), width: 1),
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
                          color: Colors.black.withOpacity(0.6),
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
                  // 印章层
                  if (_swiperController.cardIndex != null)
                    _buildStampLayer(photo),
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

  /// 随滑动幅度渐显的印章层
  Widget _buildStampLayer(AssetEntity photo) {
    return ListenableBuilder(
      listenable: _swiperController,
      builder: (context, child) {
        if (_swiperController.swipeProgress == null) {
          return const SizedBox.shrink();
        }

        final double dx = _swiperController.swipeProgress!.dx;
        if (dx == 0) return const SizedBox.shrink();

        final double opacity = (dx.abs() * 1.5).clamp(0.0, 1.0);
        final bool isDiscard = dx < 0;

        final Color stampColor =
            isDiscard ? const Color(0xFFB71C1C) : const Color(0xFF5A7D55);

        return Positioned(
          top: 20,
          left: isDiscard ? null : 20,
          right: isDiscard ? 20 : null,
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: isDiscard ? 0.2 : -0.2,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: stampColor, width: 3.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isDiscard ? 'DISCARD' : 'KEEP',
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
        );
      },
    );
  }
}
