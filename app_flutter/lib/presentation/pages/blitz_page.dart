import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appinio_swiper/appinio_swiper.dart';
import '../controllers/blitz_controller.dart';
import '../widgets/photo_card.dart';

/// 闪电战核心展示主页
class BlitzPage extends ConsumerStatefulWidget {
  const BlitzPage({Key? key}) : super(key: key);

  @override
  ConsumerState<BlitzPage> createState() => _BlitzPageState();
}

class _BlitzPageState extends ConsumerState<BlitzPage> {
  final AppinioSwiperController _swiperController = AppinioSwiperController();

  @override
  void dispose() {
    _swiperController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 监听 Blitz 模式的核心状态
    final state = ref.watch(blitzControllerProvider);
    final notifier = ref.read(blitzControllerProvider.notifier);

    // 等待初始化或无数据状态展示
    if (state.isLoading) {
      return _buildScaffold(
          context,
          const Center(
              child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Color(0xFF8BA888)))));
    }
    if (state.photos.isEmpty) {
      return _buildScaffold(context, _buildEmptyState());
    }

    return _buildScaffold(
      context,
      Column(
        children: [
          // 顶部状态栏: 进度展示与剩余精力
          _buildTopBar(context, state.currentIndex, state.photos.length,
              state.currentEnergy),

          // 中间滑动主区
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: AppinioSwiper(
                controller: _swiperController,
                cardCount: state.photos.length,
                onSwipeEnd: (int previousIndex, int targetIndex,
                    SwiperActivity activity) {
                  // 滑动结束时触发业务流
                  _handleSwipeEnd(
                      activity, notifier, state.photos[previousIndex]);
                },
                // 卡片生成器
                cardBuilder: (BuildContext context, int index) {
                  final photo = state.photos[index];
                  // 是否缓存高质量图片由 Controller 确定以防 OOM
                  final shouldLoad = notifier.shouldCacheImage(index);

                  return PhotoCard(
                    photo: photo,
                    shouldLoadImage: shouldLoad,
                  );
                },
              ),
            ),
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

  /// 顶部数据大盘 (AppBar 替代)
  Widget _buildTopBar(
      BuildContext context, int currentIndex, int total, double energy) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 进度指示
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('整理进度',
                  style: TextStyle(color: Colors.black54, fontSize: 12)),
              Text(
                '${currentIndex + 1} / $total',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Color(0xFF5D5D5D)),
              ),
            ],
          ),
          // 剩余体能块
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0E6), // 淡绿底色
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded,
                    color: Color(0xFF8BA888), size: 20), // 苔藓绿闪电
                const SizedBox(width: 4),
                Text(
                  energy.toStringAsFixed(1),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: Color(0xFF4A6B48)),
                )
              ],
            ),
          )
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

  /// 屏幕底部的大型控制按钮组 (左侧删除 ❌，右侧保留 ❤️)
  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 30, top: 10, left: 40, right: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 抛弃 / 删除按钮
          _ActionButton(
            icon: Icons.close_rounded,
            color: const Color(0xFFE57373), // 柔和红
            onTap: () {
              // 触发手动左滑动画
              _swiperController.swipeLeft();
            },
          ),
          // 喜欢 / 保留按钮
          _ActionButton(
            icon: Icons.favorite_rounded,
            color: const Color(0xFF8BA888), // 苔藓绿
            onTap: () {
              // 触发手动右滑动画
              _swiperController.swipeRight();
            },
          ),
        ],
      ),
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
}

/// 底部圆形操作悬浮按钮的 UI 封装
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      // Splash 回馈
      splashColor: color.withOpacity(0.2),
      child: Container(
        height: 70,
        width: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 36),
      ),
    );
  }
}
