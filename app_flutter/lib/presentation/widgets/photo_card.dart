import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

/// 闪电战专用的照片卡片组件
class PhotoCard extends StatelessWidget {
  /// 原生照片资源实体
  final AssetEntity photo;

  /// 是否应实际加载渲染高质量原图 (防 OOM 机制开关)
  final bool shouldLoadImage;

  const PhotoCard({
    Key? key,
    required this.photo,
    required this.shouldLoadImage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5DC), // 奶白色底层，"温暖手账风"
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias, // 切割圆角
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 判断是否需要加载实图
          if (shouldLoadImage)
            FutureBuilder<File?>(
              future: photo.file,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildSkeleton(); // 骨架加载屏
                }
                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    snapshot.data == null) {
                  return _buildErrorPlaceholder();
                }

                return Image.file(
                  snapshot.data!,
                  fit: BoxFit.cover,
                  // 可选：启用特定的内存占用优化，根据实际内存测试结果定夺
                  // cacheWidth: (MediaQuery.of(context).size.width * MediaQuery.of(context).devicePixelRatio).toInt(),
                );
              },
            )
          else
            _buildSkeleton(), // 不该加载图片的顺位 (预加载和缓存范围外的卡片) 显示骨架

          // (可选) 卡片底部半透明蒙版，用于显示日期信息等
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Text(
                _formatDate(photo.createDateTime),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  /// 构建骨架屏（占位）防止内存泄露的同时提高美观度
  Widget _buildSkeleton() {
    return Container(
      color: const Color(0xFFE8E8D8), // 稍暗于卡片底色的暖灰色
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

  /// 简单的日期格式化辅助
  String _formatDate(DateTime date) {
    return '${date.year}年${date.month.toString().padLeft(2, '0')}月${date.day.toString().padLeft(2, '0')}日';
  }
}
