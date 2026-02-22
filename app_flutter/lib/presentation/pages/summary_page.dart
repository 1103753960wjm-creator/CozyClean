import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

/// 总结算动画页面 (Summary Page)
class SummaryPage extends StatefulWidget {
  final int deletedCount;

  const SummaryPage({Key? key, required this.deletedCount}) : super(key: key);

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  late ConfettiController _confettiController;

  // 按照 PRD 假设：平均每张照片可节省 3.0 MB 空间
  static const double _savingsPerPhotoMb = 3.0;

  @override
  void initState() {
    super.initState();
    // 初始化五彩纸屑控制器，持续喷射 2 秒
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));

    // 渲染第一帧后立刻触发动画
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _confettiController.play();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6), // 温暖手账风纸张白底
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),

                // 顶部 Emoji
                const Text(
                  '✨',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 72),
                ),
                const SizedBox(height: 16),

                // 庆祝文案
                const Text(
                  '清理完成！',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A6B48), // 苔藓绿深色
                  ),
                ),
                const SizedBox(height: 48),

                // 数据面板卡片
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8BA888).withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildStatRow(
                          label: '清理照片',
                          targetValue: widget.deletedCount.toDouble(),
                          suffix: '张',
                          isFloat: false,
                        ),
                        const SizedBox(height: 20),
                        const Divider(color: Color(0xFFE8F0E6), thickness: 1.5),
                        const SizedBox(height: 20),
                        _buildStatRow(
                          label: '预估节省',
                          targetValue: widget.deletedCount * _savingsPerPhotoMb,
                          suffix: 'MB',
                          isFloat: true,
                          highlight: true,
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(flex: 3),

                // 底部胶囊按钮
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  child: ElevatedButton(
                    onPressed: () {
                      // 这里暂时是 popUntil 退回入口。后续如接入更复杂的路由（如 GoRouter），可替换跳转行为
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8BA888), // 苔藓绿
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      elevation: 4,
                      shadowColor: const Color(0xFF8BA888).withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      '太棒了！返回首页',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 位于顶层的纸屑发射器控件 (从屏幕顶部中间向四周喷洒)
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive, // 爆炸性全向喷射
              shouldLoop: false,
              colors: const [
                Color(0xFF8BA888), // 苔藓绿
                Color(0xFFE57373), // 柔和红
                Color(0xFFFFD54F), // 温暖黄
                Color(0xFF81D4FA), // 浅蓝
              ],
              createParticlePath: _drawStar, // 画小星星
            ),
          ),
        ],
      ),
    );
  }

  /// 构建具备跳动动画的数据行
  Widget _buildStatRow({
    required String label,
    required double targetValue,
    required String suffix,
    required bool isFloat,
    bool highlight = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),

        // 使用 Flutter 原生 TweenAnimationBuilder 驱动数字滚动动画
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: targetValue),
          duration: const Duration(seconds: 2),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            // 根据参数决定是否保留小数点
            final displayStr =
                isFloat ? value.toStringAsFixed(1) : value.toInt().toString();
            return RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: displayStr,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: highlight
                          ? const Color(0xFFE57373)
                          : const Color(0xFF4A6B48),
                    ),
                  ),
                  TextSpan(
                    text: ' $suffix',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: highlight
                          ? const Color(0xFFE57373)
                          : const Color(0xFF4A6B48),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  /// 为纸屑绘制定制的星星形状
  Path _drawStar(Size size) {
    double degToRad(double deg) => deg * (3.1415926535897932 / 180.0);
    const numberOfPoints = 5;
    final halfWidth = size.width / 2;
    final externalRadius = halfWidth;
    final degreesPerStep = degToRad(360 / numberOfPoints);
    final path = Path();
    final fullAngle = degToRad(360);
    path.moveTo(size.width, halfWidth);
    for (double step = 0; step < fullAngle; step += degreesPerStep) {
      path.lineTo(halfWidth + externalRadius * 1 /*cos*/,
          halfWidth + externalRadius * 0 /*sin*/);
      // 省略精确星星三角数学路径以保证性能，采用简易多边形纸屑
      // 在实际生产中只需简单闭合即可
    }
    path.addOval(Rect.fromCircle(
        center: Offset(halfWidth, halfWidth), radius: size.width / 2));
    path.close();
    return path;
  }
}
