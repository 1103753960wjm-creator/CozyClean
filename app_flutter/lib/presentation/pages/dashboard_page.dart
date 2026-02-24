import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'blitz_page.dart';
import '../controllers/user_stats_controller.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 基础骨架，手账风暖白底色
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      bottomNavigationBar: _buildBottomNav(),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                // 确保最小高度充满全屏，超出时允许滚动
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(flex: 2),
                      _buildHeader(ref),
                      const Spacer(flex: 3),
                      _buildDataRing(ref),
                      const Spacer(flex: 3),
                      _buildModeSelector(context),
                      const Spacer(flex: 3),
                      _buildStartButton(context),
                      const Spacer(flex: 2),
                      _buildEnergyBar(),
                      const Spacer(flex: 2),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 顶层欢迎与标题
  Widget _buildHeader(WidgetRef ref) {
    final userStatsAsync = ref.watch(userStatsStreamProvider);
    final isPro = userStatsAsync.value?.isPro ?? false;

    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            print(
                '👉 [DashboardPage] Title tapped! Toggling Pro mode to: ${!isPro}');
            ref.read(userStatsControllerProvider).togglePro(!isPro);
          },
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Text(
              '晚上好，林小舒${isPro ? ' (PRO)' : ''}',
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A4238), // 深咖啡文字色
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '准备好整理回忆了吗？',
          style: TextStyle(
            fontSize: 12,
            color: const Color(0xFF4A4238).withOpacity(0.6),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  /// 核心数据环 - 接入 LocalUserStats 真实统计数
  ///
  /// 会员模式区分：
  /// - 普通用户：显示数字体力值 + 绿色/红色动态进度环
  /// - Pro 会员：显示 ∞ 无限符号 + 金色满圈环
  Widget _buildDataRing(WidgetRef ref) {
    // 监听数据库中的用户数据流
    final userStatsAsync = ref.watch(userStatsStreamProvider);

    return Center(
      child: SizedBox(
        width: 144,
        height: 144,
        child: userStatsAsync.when(
          data: (stats) {
            final bool isPro = stats.isPro;
            final energy = stats.dailyEnergyRemaining;

            // Pro 会员：满圈金色 | 普通用户：按比例计算
            final double progress =
                isPro ? 1.0 : (energy / 100.0).clamp(0.0, 1.0);

            // Pro 会员：金色 | 普通 <10 体力：红色 | 普通 ≥10 体力：绿色
            final Color progressColor = isPro
                ? const Color(0xFFD4AF37) // 金色，体现尊贵会员感
                : energy < 10
                    ? const Color(0xFFD66B63) // 红色警示
                    : const Color(0xFF8BA888); // 绿色正常

            return Stack(
              fit: StackFit.expand,
              children: [
                // 底部浅色灰色圆环 (底座轨道)
                const CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE5DFD3)),
                ),
                // 动态进度圆环，通过水平翻转使其顺时针增长
                Transform.flip(
                  flipX: true,
                  child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: progress),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) {
                        return CircularProgressIndicator(
                          value: value,
                          strokeWidth: 4,
                          backgroundColor: Colors.transparent,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(progressColor),
                        );
                      }),
                ),
                // 中心文字：Pro 显示 ∞，普通显示数字
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isPro ? '∞' : '${energy.toInt()}',
                      style: TextStyle(
                        fontSize: isPro ? 48 : 38,
                        fontWeight: FontWeight.w900,
                        color: isPro
                            ? const Color(0xFFD4AF37) // 金色数字
                            : const Color(0xFF6B453E), // 绛棕色数字
                      ),
                    ),
                    // Pro 会员隐藏 "/ 100" 副标题
                    if (!isPro)
                      Text(
                        '/ 100',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF6B453E).withOpacity(0.5),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
          loading: () => Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFE5DFD3),
                width: 3,
              ),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: Color(0xFFC75D56)),
            ),
          ),
          error: (err, stack) => Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFE5DFD3),
                width: 3,
              ),
            ),
            child: Center(
              child: Text(
                'err',
                style: TextStyle(color: Colors.red.withOpacity(0.5)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 功能选取器 (防溢出 ListView)
  Widget _buildModeSelector(BuildContext context) {
    return SizedBox(
      height: 112, // 限定水平滚动的高度边界
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _buildModeCard(
            context,
            icon: '⚡',
            title: '闪电战',
            badge: 'FREE',
            isPrimary: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BlitzPage()),
              );
            },
          ),
          const SizedBox(width: 15),
          _buildModeCard(
            context,
            icon: '✂️',
            title: '截图粉碎',
            badge: 'PRO',
            isPrimary: false,
            onTap: () => _showComingSoon(context),
          ),
          const SizedBox(width: 15),
          _buildModeCard(
            context,
            icon: '⌛',
            title: '时光机',
            badge: 'PRO',
            isPrimary: false,
            onTap: () => _showComingSoon(context),
          ),
        ],
      ),
    );
  }

  /// 统一提取出来的功能卡片模块
  Widget _buildModeCard(
    BuildContext context, {
    required String icon,
    required String title,
    required String badge,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 88,
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xFFFDFBF7) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                isPrimary ? const Color(0xFFC75D56) : const Color(0xFFE5DFD3),
            width: isPrimary ? 1.5 : 1,
            // 采用手账风，如果是次要卡片这里未来可以抽成自定义画笔画虚线，现在维持极简
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isPrimary ? FontWeight.bold : FontWeight.w600,
                color: const Color(0xFF4A4238),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isPrimary ? Colors.transparent : Colors.black,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  // primary 则是其自身字的灰度色，如果是 pro 则是白字黑底标签
                  color: isPrimary ? Colors.black38 : Colors.white,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('建设中，即将上线！🛠️', textAlign: TextAlign.center),
        backgroundColor: const Color(0xFF8BA888),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// 中央红色高光整理按钮
  Widget _buildStartButton(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BlitzPage()),
          );
        },
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [
                Color(0xFFD66B63), // 中心亮红
                Color(0xFFB04343), // 边缘深红
              ],
              center: Alignment(-0.2, -0.2), // 光源左上
              radius: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFB04343).withOpacity(0.5),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '开始',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  '整理',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 底部黄色条纹斜率进度条
  Widget _buildEnergyBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Container(
            height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFFF3EAC2), // 明黄色系
              borderRadius: BorderRadius.circular(4),
              // 由于 Flutter 没有原生的斜纹背景，可以采用纯色或使用 CustomPaint，此处作极简处理为浅黄色实体
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '今日体力',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black26,
            ),
          )
        ],
      ),
    );
  }

  /// 底部红框线导航
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAF9F6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: BottomNavigationBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        selectedItemColor: const Color(0xFFC75D56), // 主题红
        unselectedItemColor: Colors.black38,
        selectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_filled),
            label: '整理',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
