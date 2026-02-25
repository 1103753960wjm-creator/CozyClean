import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:photo_manager/photo_manager.dart';

import '../controllers/blitz_controller.dart';
import '../widgets/photo_card.dart';
import 'summary_page.dart';

/// 闪电战核心展示主页
class BlitzPage extends ConsumerStatefulWidget {
  const BlitzPage({super.key});

  @override
  ConsumerState<BlitzPage> createState() => _BlitzPageState();
}

class _BlitzPageState extends ConsumerState<BlitzPage> {
  final AppinioSwiperController _swiperController = AppinioSwiperController();

  // 导航保险锁，避免同时触发监听器和插件的回调
  bool _isNavigating = false;

  void _navigateToSummary(List<AssetEntity> deleteSet) {
    if (_isNavigating) return;
    _isNavigating = true;

    // 读取本次会话审阅的照片总数，用于全员珍藏流展示
    final totalReviewed = ref.read(blitzControllerProvider).photos.length;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => SummaryPage(
          deleteSet: deleteSet,
          totalReviewedCount: totalReviewed,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // 在首帧渲染后触发照片加载，避免在 widget 构建期间修改 Provider 状态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(blitzControllerProvider.notifier).loadPhotos();
    });
  }

  @override
  void dispose() {
    _swiperController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ---- 核心修复思路：组件解耦与精细化监听 ----
    // 之前全量 watch 导致滑动改变 currentIndex 和 energy 时，整颗 Widget 树甚至包含 AppinioSwiper 都被撕毁重建。
    // 这破坏了内部极度脆弱的位移动画连续性与图层复用！

    // 我们在此只精细化监听是否处于大的加载与错误状态。
    final isLoading =
        ref.watch(blitzControllerProvider.select((s) => s.isLoading));
    final errorMessage =
        ref.watch(blitzControllerProvider.select((s) => s.errorMessage));

    // 注意：这里的 photos 本身是一个指针，只要不增删元素它就不会变，所以这里也阻断。
    final photos = ref.watch(blitzControllerProvider.select((s) => s.photos));

    // 预加载好的缩略图缓存，同样只在加载时更新一次
    final thumbnailCache =
        ref.watch(blitzControllerProvider.select((s) => s.thumbnailCache));

    final notifier = ref.read(blitzControllerProvider.notifier);

    // 路由拦截：由于 AppinioSwiper 的动画延迟，我们在这里监听状态，并在确实滑完了所有卡片时跳转。
    // ref.listen 只是监听流而不引发 build 重建！非常安全！
    ref.listen(blitzControllerProvider, (previous, next) {
      if (!next.isLoading && next.photos.isNotEmpty && !next.hasNextPhoto) {
        _navigateToSummary(next.sessionDeletedPhotos);
      }
    });

    // 等待初始化或无数据状态展示
    if (isLoading) {
      return _buildScaffold(
          context,
          const Center(
              child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Color(0xFF8BA888)))));
    }
    // +++++++ 新增：如果有错误信息（比如权限被拒），把它显示在屏幕上 +++++++
    if (errorMessage != null) {
      return _buildScaffold(
        context,
        Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontSize: 16),
            ),
          ),
        ),
      );
    }
    if (photos.isEmpty) {
      return _buildScaffold(context, _buildEmptyState());
    }

    return _buildScaffold(
      context,
      Column(
        children: [
          // 顶部状态栏: 进度展示与剩余精力（这部分交由内部拆分的独立 Consumer 订阅）
          Consumer(builder: (context, ref, child) {
            final currentIndex = ref
                .watch(blitzControllerProvider.select((s) => s.currentIndex));
            final currentEnergy = ref
                .watch(blitzControllerProvider.select((s) => s.currentEnergy));

            return _buildTopBar(
              context,
              currentIndex < photos.length ? currentIndex : photos.length - 1,
              photos.length,
              currentEnergy,
            );
          }),

          // 中间滑动主区 (只要 photos 和 thumbnailCache 指针不变，这块绝对不重建！)
          Expanded(
            child: _buildSwiperContainer(photos, thumbnailCache, notifier),
          ),

          // 底部操作按钮群
          _buildActionButtons(),
        ],
      ),
    );
  }

  void _showExitConfirmationBottomSheet() {
    final sessionDeletes = ref.read(blitzControllerProvider).sessionDeletes;
    final deletedPhotos =
        ref.read(blitzControllerProvider).sessionDeletedPhotos;

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
                '你有 ${sessionDeletes.length} 张废片待清理，要现在归档吗？',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
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
                        _navigateToSummary(deletedPhotos);
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

  /// 构建底层脚手架，注入奶白/米黄色背景
  Widget _buildScaffold(BuildContext context, Widget child) {
    return PopScope(
      canPop: ref.watch(blitzControllerProvider).sessionDeletes.isEmpty,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _showExitConfirmationBottomSheet();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF9F6), // "温暖手账风" 纸张白底
        body: SafeArea(child: child),
      ),
    );
  }

  /// 顶部数据大盘 (AppBar 替代) - 根据设计图重构为极简风格
  Widget _buildTopBar(
      BuildContext context, int currentIndex, int total, double energy) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 左侧返回按钮
          GestureDetector(
            onTap: () async {
              final sessionDeletes =
                  ref.read(blitzControllerProvider).sessionDeletes;
              if (sessionDeletes.isEmpty) {
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
          // 右侧标题
          const Text(
            '闪电战模式',
            style: TextStyle(
                color: Colors.black45,
                fontSize: 16,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  /// 无照片处理时的展示语
  Widget _buildEmptyState() {
    return const Center(
      child: Text(
        '暂无需要清理的照片\n今天也是清爽的一天',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.black45, fontSize: 16),
      ),
    );
  }

  /// 屏幕底部的极简文本操作按钮与左下方的撕纸撤销贴片
  Widget _buildActionButtons() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 极简文本滑动手柄 (底部居中靠下)
        Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 10), // 控制整体文本离底部的距离
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  _swiperController.swipeLeft();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
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
                onTap: () {
                  _swiperController.swipeRight();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
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
        ),

        // 撕纸贴片风的悬浮撤销按钮 (左侧靠下悬浮，抬高防重叠)
        Positioned(
          left: 20,
          bottom: 80, // 从 10 大幅抬升，彻底脱开下方文本的安全距离
          child: GestureDetector(
            onTap: () {
              // 触发控制器防呆撤销，如果不能撤销则无反应
              _swiperController.unswipe();
              // 在 controller 层级我们可以添加自己的弹回逻辑或音效
              HapticFeedback.lightImpact();
            },
            child: Transform.rotate(
              angle: -0.05, // 微微倾斜更加随意
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8), // 缩小内边距
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EBE2), // 泛黄的裁纸色
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(2, 2),
                    ),
                  ],
                  // 使用一点非对称圆角模拟胶带撕下的痕迹
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
                    Icon(
                      Icons.replay_rounded,
                      color: Colors.black45,
                      size: 14, // 缩小图标
                    ),
                    SizedBox(width: 4),
                    Text(
                      '撤销',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 14, // 缩小字号
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
      ],
    );
  }

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
                '今日体力已耗尽，解锁 PRO 获取无限体力',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: const Color(0xFFD4AF37), // 金色
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
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

  /// 封装 Swiper 卡片滑动后的通用回调事件分析
  void _handleSwipeEnd(
      SwiperActivity activity, dynamic notifier, dynamic photo) async {
    if (activity is Swipe) {
      if (activity.direction == AxisDirection.left) {
        // 左滑 (删除 - 较重力反馈)
        HapticFeedback.mediumImpact();
        final success = await notifier.swipeLeft(photo);
        if (!success) {
          _swiperController.unswipe();
          _showNoEnergyWarning();
        }
      } else if (activity.direction == AxisDirection.right) {
        // 右滑 (保留 - 轻量反馈)
        HapticFeedback.lightImpact();
        final success = await notifier.swipeRight(photo);
        if (!success) {
          _swiperController.unswipe();
          _showNoEnergyWarning();
        }
      }
    }
  }

  /// 剥离构建滑动核心区域
  Widget _buildSwiperContainer(List<AssetEntity> photos,
      Map<String, Uint8List> thumbnailCache, BlitzController notifier) {
    return Center(
      // 关键修复：加入 AspectRatio 防止被 Expanded 拉扯变形
      // 强制 0.8 比例，恢复竖版拍立得真实的稍微“胖宽”感
      child: AspectRatio(
        aspectRatio: 0.80,
        child: Padding(
          padding: const EdgeInsets.only(left: 30, right: 30, bottom: 110),
          child: AppinioSwiper(
            controller: _swiperController,
            cardCount: photos.length,
            backgroundCardCount: 2,
            backgroundCardScale: 0.92,
            backgroundCardOffset: const Offset(0, 15),
            onSwipeEnd:
                (int previousIndex, int targetIndex, SwiperActivity activity) {
              if (previousIndex < 0 || previousIndex >= photos.length) {
                return;
              }
              _handleSwipeEnd(activity, notifier, photos[previousIndex]);
            },
            onEnd: () {
              final currentState = ref.read(blitzControllerProvider);
              _navigateToSummary(currentState.sessionDeletedPhotos);
            },
            cardBuilder: (BuildContext context, int index) {
              if (index < 0 || index >= photos.length) {
                return const SizedBox.shrink();
              }
              final photo = photos[index];

              return PhotoCard(
                key: ValueKey(photo.id),
                imageData: thumbnailCache[photo.id], // 纯同步传入，零闪烁
                swiperController: _swiperController,
                index: index,
              );
            },
          ),
        ),
      ),
    );
  }
}
