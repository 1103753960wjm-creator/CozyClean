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
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => SummaryPage(deleteSet: deleteSet),
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

          // 中间滑动主区 (只要 photos 指针不变，这块最沉重的骨肉绝对不重建！)
          Expanded(
            child: _buildSwiperContainer(photos, notifier),
          ),

          // 底部操作按钮群
          _buildActionButtons(),
        ],
      ),
    );
  }

  /// 构建底层脚手架，注入奶白/米黄色背景
  Widget _buildScaffold(BuildContext context, Widget child) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6), // "温暖手账风" 纸张白底
      body: SafeArea(child: child),
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
            onTap: () => Navigator.maybePop(context),
            child: const Text('← 返回',
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

  /// 封装 Swiper 卡片滑动后的通用回调事件分析
  void _handleSwipeEnd(
      SwiperActivity activity, dynamic notifier, dynamic photo) {
    if (activity is Swipe) {
      if (activity.direction == AxisDirection.left) {
        // 左滑 (删除 - 较重力反馈)
        HapticFeedback.mediumImpact();
        notifier.swipeLeft(photo);
      } else if (activity.direction == AxisDirection.right) {
        // 右滑 (保留 - 轻量反馈)
        HapticFeedback.lightImpact();
        notifier.swipeRight(photo);
      }
    }
  }

  /// 剥离构建滑动核心区域
  Widget _buildSwiperContainer(
      List<AssetEntity> photos, BlitzController notifier) {
    return Center(
      // 关键修复：加入 AspectRatio 防止被 Expanded 拉扯变形
      // 强制 0.8 比例，恢复竖版拍立得真实的稍微“胖宽”感
      child: AspectRatio(
        aspectRatio: 0.80,
        child: Padding(
          // 极大地拉升下部屏障距离（bottom: 110），强行顶起缩小卡片避免任何元素盖住
          padding: const EdgeInsets.only(left: 30, right: 30, bottom: 110),
          child: AppinioSwiper(
            controller: _swiperController,
            cardCount: photos.length,
            // 【关键重设】增强底部卡片层次错落感
            backgroundCardCount: 2, // 渲染底部露出来的两张卡片（不含顶层，合计看到 3 层厚度）
            backgroundCardScale: 0.92, // 底下卡片的缩放比例，差异越大越有梯度感
            backgroundCardOffset: const Offset(0, 15), // 强制让底下的图层向下偏移，模仿相册厚度
            onSwipeEnd:
                (int previousIndex, int targetIndex, SwiperActivity activity) {
              if (previousIndex < 0 || previousIndex >= photos.length) {
                return;
              }
              _handleSwipeEnd(activity, notifier, photos[previousIndex]);
            },
            onEnd: () {
              // 从最新的全局 state 中获取删除名单并进行跳转，规范使用 ref.read 获取
              final currentState = ref.read(blitzControllerProvider);
              _navigateToSummary(currentState.sessionDeletedPhotos);
            },
            cardBuilder: (BuildContext context, int index) {
              if (index < 0 || index >= photos.length) {
                return const SizedBox.shrink();
              }
              final photo = photos[index];
              final shouldLoad = notifier.shouldCacheImage(index);

              return PhotoCard(
                key: ValueKey(photo
                    .id), // 注入 Key 保护底层 State，防止因数组移动导致 ImageFileFuture 被重新触发而闪烁
                photo: photo,
                shouldLoadImage: shouldLoad,
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
