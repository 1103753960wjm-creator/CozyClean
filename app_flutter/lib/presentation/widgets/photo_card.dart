import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:appinio_swiper/appinio_swiper.dart';

/// 闪电战专用的拍立得风格照片卡片组件
class PhotoCard extends StatefulWidget {
  /// 原生照片资源实体
  final AssetEntity photo;

  /// 是否应实际加载渲染高质量原图 (防 OOM 机制开关)
  final bool shouldLoadImage;

  /// 用于提供实时偏移量的 Swiper 控制器
  final AppinioSwiperController? swiperController;

  /// 该卡片在数据流中的绝对索引
  final int index;

  const PhotoCard({
    super.key,
    required this.photo,
    required this.shouldLoadImage,
    this.swiperController,
    required this.index,
  });

  @override
  State<PhotoCard> createState() => _PhotoCardState();
}

class _PhotoCardState extends State<PhotoCard> {
  /// 缓存图片字节流的 Future，防止组件由于父级重建导致 FutureBuilder 多次触发
  Future<Uint8List?>? _imageDataFuture;

  @override
  void initState() {
    super.initState();
    if (widget.shouldLoadImage) {
      // 不再使用耗时高且需要磁盘 File 锁的 .file 获取原图，而是直接向原生端索要内存中的高清缩略图数据！
      // 尺寸可以依据卡片自身大小 (例如 800 * 800) 来平衡画质和光速加载的需求
      _imageDataFuture =
          widget.photo.thumbnailDataWithSize(const ThumbnailSize(800, 800));
    }
  }

  @override
  void didUpdateWidget(covariant PhotoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 重用机制：
    // 1. 照片发生了根本的更换（id 改变），且应当加载； 或者
    // 2. 照片实例因为挂载了 ValueKey 未被销毁重建，由于滑近使得 shouldLoadImage 从 false 变为了 true
    if ((oldWidget.photo.id != widget.photo.id && widget.shouldLoadImage) ||
        (!oldWidget.shouldLoadImage && widget.shouldLoadImage)) {
      _imageDataFuture =
          widget.photo.thumbnailDataWithSize(const ThumbnailSize(800, 800));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, // 纯白色底板，模拟相片纸
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          // 第一层：短距离实心黑影，用于压住背后的卡牌或底色产生“厚度切割”
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
          // 第二层：大范围柔和的背景散射透光轮，产生强烈的“悬浮立体感”
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
          // 上半部分：照片本身 (拉大白底 padding，让相纸白框有更明显的"护城河"承载感)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                  left: 14, right: 14, top: 14, bottom: 2),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildImageLayer(),
                  // 印章层
                  if (widget.swiperController != null) _buildStampLayer(),
                ],
              ),
            ),
          ),
          // 下半部分：留白区域及手写风配文 (缩小留白高度，从90减到60)
          Container(
            height: 60,
            alignment: Alignment.center,
            child: Text(
              '宝宝的第一步', // 暂时写死，后续可根据日期或主题生成
              style: TextStyle(
                fontFamily: 'Caveat', // 也可以用系统自带斜体
                fontStyle: FontStyle.italic,
                fontSize: 18,
                color: Colors.black87.withOpacity(0.7),
                letterSpacing: 2.0,
              ),
            ),
          )
        ],
      ),
    );
  }

  /// 构建主要的图片渲染层
  Widget _buildImageLayer() {
    if (!widget.shouldLoadImage || _imageDataFuture == null) {
      return _buildSkeleton();
    }

    return FutureBuilder<Uint8List?>(
      future: _imageDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSkeleton(); // 骨架加载屏
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return _buildErrorPlaceholder();
        }

        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black.withOpacity(0.05), width: 1),
          ),
          child: Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
            // 绝杀闪烁选项：重用缓冲或无缝过渡接合，在 Flutter 层级直接截断任何渲染白帧
            gaplessPlayback: true,
          ),
        );
      },
    );
  }

  /// 构建随滑动幅度渐显的印章层
  Widget _buildStampLayer() {
    return ListenableBuilder(
      listenable: widget.swiperController!,
      builder: (context, child) {
        if (widget.swiperController!.cardIndex != widget.index ||
            widget.swiperController!.swipeProgress == null) {
          return const SizedBox.shrink();
        }

        final double dx = widget.swiperController!.swipeProgress!.dx;
        if (dx == 0) return const SizedBox.shrink();

        // 经实测，AppinioSwiper 底层返回的 dx 本身已经是归一化参数 / 小比例数！
        // 故之前除以(屏幕一半)反而导致透明度无限趋近于 0 看不见！直接乘以倍率即可！
        final double opacity = (dx.abs() * 1.5).clamp(0.0, 1.0);
        final bool isDiscard = dx < 0;

        // 印章缩小一圈并分别挂在左上角与右上角
        return Positioned(
          top: 20,
          left: isDiscard ? null : 20, // Keep在左侧
          right: isDiscard ? 20 : null, // Discard在右侧
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: isDiscard ? 0.2 : -0.2, // 根据新位置调整偏转角
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isDiscard
                        ? Colors.redAccent.withOpacity(0.8)
                        : const Color(0xFF8BA888).withOpacity(0.8),
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isDiscard ? 'DISCARD' : 'KEEP',
                  style: TextStyle(
                    color: isDiscard
                        ? Colors.redAccent.withOpacity(0.8)
                        : const Color(0xFF8BA888).withOpacity(0.8),
                    fontSize: 26, // 从 42 减小到 26
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

  /// 构建骨架屏（占位）防止内存泄露的同时提高美观度
  Widget _buildSkeleton() {
    return Container(
      color: const Color(0xFFF2EAE0), // 稍暗于卡片底色的暖灰色
      alignment: Alignment.center,
      child: const CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8BA888)), // 苔藓绿
        strokeWidth: 3,
      ),
    );
  }

  /// 构建出错时的占位符
  Widget _buildErrorPlaceholder() {
    return Container(
      color: const Color(0xFFF0EBE2),
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image_rounded,
          size: 48, color: Colors.black26),
    );
  }
}
