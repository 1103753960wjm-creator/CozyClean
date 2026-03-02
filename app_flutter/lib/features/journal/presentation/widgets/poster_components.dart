import 'dart:ui';
import 'package:flutter/material.dart';

/// 纯属外观修饰的常量配置
class ScrapbookColors {
  static const Color cream = Color(0xFFF5F0E8);
  static const Color brown = Color(0xFF5D4037);
  static const Color inkBlack = Color(0xFF2C2C2C);
  static const Color paperWhite = Color(0xFFFAF9F6);
  static const Color redAccent = Color(0xFFC75D56);
  static const Color greenAccent = Color(0xFF8BA888);
}

class ScrapbookActionButtons extends StatelessWidget {
  final VoidCallback onHome;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final VoidCallback? onEdit; // 置空时为不可交互

  const ScrapbookActionButtons({
    super.key,
    required this.onHome,
    required this.onShare,
    required this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: ScrapbookColors.cream
            .withValues(alpha: 0.95), // bg-scrapbook-cream/95
        border: Border(
          top: BorderSide(
            color: ScrapbookColors.brown.withOpacity(0.05), // border-t
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 第一排：编辑、主页、删除
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.edit_rounded,
                    label: '编辑',
                    onPressed: onEdit,
                  ),
                ),
                const SizedBox(width: 12), // gap-3
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.home_rounded,
                    label: '返回首页',
                    onPressed: onHome,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.delete_outline_rounded,
                    label: '删除',
                    onPressed: onDelete,
                    textColor: ScrapbookColors.redAccent,
                    borderColor: const Color(0xFFFFCDD2), // red-100
                  ),
                ),
              ],
            ),
          ),

          // 第二排：分享至社交媒体
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onShare,
                borderRadius: BorderRadius.circular(16), // rounded-2xl
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: ScrapbookColors.brown,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: ScrapbookColors.brown
                            .withOpacity(0.2), // shadow-scrapbook-brown/20
                        blurRadius: 15, // shadow-lg approx
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.ios_share_rounded,
                          size: 16, color: ScrapbookColors.cream),
                      SizedBox(width: 8),
                      Text(
                        '分享至社交媒体',
                        style: TextStyle(
                          color: ScrapbookColors.cream,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    VoidCallback? onPressed,
    Color textColor = ScrapbookColors.brown,
    Color? borderColor,
  }) {
    final isDisabled = onPressed == null;
    final bColor = borderColor ?? ScrapbookColors.brown.withOpacity(0.1);
    final finalTextColor = isDisabled ? Colors.grey : textColor;

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), // rounded-2xl
        side: BorderSide(color: bColor, width: 1),
      ),
      elevation: 0.5, // shadow-sm
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 40,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: finalTextColor, size: 18),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: finalTextColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 纸胶带贴纸组件
class WashiTape extends StatelessWidget {
  final Color color;
  final double width;
  final double height;
  final double angle; // 弧度

  const WashiTape({
    super.key,
    required this.color,
    this.width = 60,
    this.height = 20,
    this.angle = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Opacity(
        opacity: 0.85,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: color,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 2,
                offset: const Offset(1, 1),
              ),
            ],
            // 细微的撕裂边缘效果 (简单模拟)
            border: Border.symmetric(
              vertical: BorderSide(
                color: Colors.white.withOpacity(0.5),
                width: 1.5,
                style: BorderStyle.solid,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 拍立得照片卡片 (白底+阴影)
class PolaroidCard extends StatelessWidget {
  final Widget child;
  final double rotation;
  final double? width;
  final double? height;

  const PolaroidCard({
    super.key,
    required this.child,
    this.rotation = 0,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation,
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(2, 6),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: child, // 图片所在位置
        ),
      ),
    );
  }
}

/// 光晕修饰背景组件
class DecorativeBlur extends StatelessWidget {
  final Color color;
  final double size;

  const DecorativeBlur({
    super.key,
    required this.color,
    this.size = 200,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.3),
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(color: Colors.transparent),
        ),
      ),
    );
  }
}
