import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:appinio_swiper/appinio_swiper.dart';

/// 闪电战专用的拍立得风格照片卡片组件
///
/// 核心设计：**纯同步渲染，零闪烁**。
/// 所有缩略图数据在 BlitzController.loadPhotos() 阶段已预加载到内存，
/// 本组件直接通过 [imageData] 接收 Uint8List 并使用 Image.memory 渲染。
/// 没有 FutureBuilder，没有异步等待，没有骨架屏闪烁。
class PhotoCard extends StatelessWidget {
  /// 预加载好的缩略图字节流（可为 null，此时显示占位符）
  final Uint8List? imageData;

  /// 用于提供实时偏移量的 Swiper 控制器
  final AppinioSwiperController? swiperController;

  /// 该卡片在数据流中的绝对索引
  final int index;

  const PhotoCard({
    super.key,
    required this.imageData,
    this.swiperController,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, // 纯白色底板，模拟相片纸
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          // 第一层：短距离实心黑影，用于压住背后的卡牌或底色产生"厚度切割"
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
          // 第二层：大范围柔和的背景散射透光轮，产生强烈的"悬浮立体感"
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
                  if (swiperController != null) _buildStampLayer(),
                ],
              ),
            ),
          ),
          // 下半部分：留白区域及手写风配文
          Container(
            height: 60,
            alignment: Alignment.center,
            child: Text(
              '', // 暂时清空，后续可根据日期或主题生成
              style: TextStyle(
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

  /// 构建主要的图片渲染层 — 纯同步，零闪烁
  Widget _buildImageLayer() {
    if (imageData == null) {
      return _buildErrorPlaceholder();
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black.withOpacity(0.05), width: 1),
      ),
      child: Image.memory(
        imageData!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      ),
    );
  }

  /// 构建随滑动幅度渐显的印章层
  Widget _buildStampLayer() {
    return ListenableBuilder(
      listenable: swiperController!,
      builder: (context, child) {
        if (swiperController!.cardIndex != index ||
            swiperController!.swipeProgress == null) {
          return const SizedBox.shrink();
        }

        final double dx = swiperController!.swipeProgress!.dx;
        if (dx == 0) return const SizedBox.shrink();

        // AppinioSwiper 底层返回的 dx 是小比例归一化数
        final double opacity = (dx.abs() * 1.5).clamp(0.0, 1.0);
        final bool isDiscard = dx < 0;

        // 印章颜色：加深 30% 以提升清晰度
        // DISCARD → Material Red 900 深红 | KEEP → 加深墨绿
        final Color stampColor = isDiscard
            ? const Color(0xFFB71C1C) // 深红色 (Material Red 900)
            : const Color(0xFF5A7D55); // 墨绿色 (原色加深 30%)

        // 印章缩小一圈并分别挂在左上角与右上角
        return Positioned(
          top: 20,
          left: isDiscard ? null : 20, // Keep在左侧
          right: isDiscard ? 20 : null, // Discard在右侧
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: isDiscard ? 0.2 : -0.2,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: stampColor,
                    width: 3.5,
                  ),
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
