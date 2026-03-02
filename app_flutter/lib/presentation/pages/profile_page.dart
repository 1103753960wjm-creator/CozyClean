import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/user_stats_controller.dart';
import 'package:cozy_clean/features/journal/presentation/widgets/poster_components.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Scaffold 已经提供背景，这里只需使用 CustomScrollView
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildAppBar(),
        SliverToBoxAdapter(
          child: Column(
            children: [
              _buildAvatarSection(ref),
              _buildHonorsSection(),
              _buildStatsSection(ref),
              _buildSettingsList(),
              const SizedBox(height: 32),
              const Text(
                'CozyClean v2.0.4',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.black26,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 48), // 给 BottomNav 留出空间
            ],
          ),
        ),
      ],
    );
  }

  // 1. 顶部 Header
  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.transparent, // 会透过 Scaffold 背景
      surfaceTintColor: Colors.transparent,
      pinned: true,
      elevation: 0,
      centerTitle: true,
      title: const Text(
        '我的与数据中心',
        style: TextStyle(
          color: ScrapbookColors.inkBlack,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded),
          color: ScrapbookColors.inkBlack,
          onPressed: () {},
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildAvatarSection(WidgetRef ref) {
    final userStatsAsync = ref.watch(userStatsStreamProvider);
    final isPro = userStatsAsync.value?.isPro ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        children: [
          // 宝丽来相框
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: -0.05, // -3度左右
                child: Container(
                  width: 120,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(2, 6),
                      ),
                    ],
                  ),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      color: const Color(0xFFE5DFD3),
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.matrix([
                          1.2, 0, 0, 0, 10, // R
                          0, 1.1, 0, 0, 5, // G
                          0, 0, 0.9, 0, -10, // B
                          0, 0, 0, 1, 0, // A
                        ]),
                        child: Image.network(
                          'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?ixlib=rb-1.2.1&auto=format&fit=crop&w=300&q=80',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(Icons.person,
                                  size: 48, color: Colors.white),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // 顶部黄色胶带贴纸
              const Positioned(
                top: -12,
                child: WashiTape(
                  color: Color(0xCCFFF59D),
                  width: 64,
                  height: 24,
                  angle: 0.05,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '暖心妈妈',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: ScrapbookColors.inkBlack,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '用爱记录每一个瞬间',
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: const Color(0xFF73816A), // text-sub
            ),
          ),
          const SizedBox(height: 12),
          // 绿色的“高级会员”徽章
          GestureDetector(
            onTap: () =>
                ref.read(userStatsControllerProvider).togglePro(!isPro),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: ScrapbookColors.greenAccent.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: ScrapbookColors.greenAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isPro ? '高级会员' : '免费版用户',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: ScrapbookColors.greenAccent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHonorsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.black.withOpacity(0.03)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.workspace_premium_rounded,
                          color: Color(0xFFC6A664), size: 20),
                      SizedBox(width: 8),
                      Text(
                        '荣誉殿堂',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: ScrapbookColors.inkBlack,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        '查看全部',
                        style: TextStyle(
                          fontSize: 11,
                          color: ScrapbookColors.inkBlack.withOpacity(0.5),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 16,
                          color: ScrapbookColors.inkBlack.withOpacity(0.5)),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildHonorBadge(
                    icon: Icons.verified_user_rounded,
                    bgColor: const Color(0xFFE3F2FD),
                    iconColor: Colors.blue,
                    label: '记忆守护者',
                  ),
                  _buildHonorBadge(
                    icon: Icons.cleaning_services_rounded,
                    bgColor: const Color(0xFFFFF3E0),
                    iconColor: Colors.orange,
                    label: '空间拯救者',
                  ),
                  _buildHonorBadge(
                    icon: Icons.auto_stories_rounded,
                    bgColor: const Color(0xFFF3E5F5),
                    iconColor: Colors.purple,
                    label: '手账达人',
                  ),
                  _buildHonorBadge(
                    icon: Icons.lock_rounded,
                    bgColor: const Color(0xFFF5F5F5),
                    iconColor: Colors.grey,
                    label: '敬请期待',
                    isDashed: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHonorBadge({
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    required String label,
    bool isDashed = false,
  }) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: isDashed
                ? Border.all(
                    color: Colors.grey.withOpacity(0.3),
                    style: BorderStyle.solid)
                : null,
          ),
          child: Icon(icon, color: iconColor, size: 26),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: ScrapbookColors.inkBlack.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection(WidgetRef ref) {
    final userStats = ref.watch(userStatsStreamProvider).value;

    // 从持久化的真实 totalSavedBytes 转换出展示数字
    final totalBytes = userStats?.totalSavedBytes ?? 0;

    // 假设平均一张照片 3MB，大致反推清理张数（或者展示一个带千分位的体验值）
    final estimatePhotos = (totalBytes / (1024 * 1024 * 3)).floor();
    final clearedStr = estimatePhotos > 0 ? estimatePhotos.toString() : '2,340';

    // 真实节约空间 (GB)
    final spaceStr = totalBytes > 0
        ? (totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)
        : '4.5';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Transform.rotate(
        angle: -0.015,
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F9F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black.withOpacity(0.05)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: CustomPaint(
                painter: _LinesPainter(), // 绘制划线纸底层线框
                child: Row(
                  children: [
                    Expanded(
                        child: _buildStatItem(
                            clearedStr, '累计清理 (张)', const Color(0xFF5A5A5A))),
                    Container(
                        width: 1,
                        height: 40,
                        color: Colors.blueGrey.withOpacity(0.15)),
                    Expanded(
                        child: _buildStatItem(spaceStr, '释放空间 (GB)',
                            ScrapbookColors.greenAccent)),
                    Container(
                        width: 1,
                        height: 40,
                        color: Colors.blueGrey.withOpacity(0.15)),
                    Expanded(
                        child: _buildStatItem(
                            '12', '手账创作 (本)', const Color(0xFFC6A664))),
                  ],
                ),
              ),
            ),
            // 半透明绿色胶带
            Positioned(
              top: -8,
              child: WashiTape(
                color: ScrapbookColors.greenAccent.withOpacity(0.25),
                width: 80,
                height: 16,
                angle: 0.02,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, Color valueColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: valueColor,
            fontFamily: 'serif',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: ScrapbookColors.inkBlack.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.black.withOpacity(0.03)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildSettingRow(
              icon: Icons.history_edu_rounded,
              bgColor: const Color(0xFFE8F5E9),
              iconColor: ScrapbookColors.greenAccent,
              title: '整理日志',
            ),
            Divider(
                height: 1,
                color: Colors.black.withOpacity(0.03),
                indent: 16,
                endIndent: 16),
            _buildSettingRow(
              icon: Icons.diamond_rounded,
              bgColor: const Color(0xFFFFF3E0),
              iconColor: Colors.orange,
              title: '会员中心',
            ),
            Divider(
                height: 1,
                color: Colors.black.withOpacity(0.03),
                indent: 16,
                endIndent: 16),
            _buildSettingRow(
              icon: Icons.cloud_sync_rounded,
              bgColor: const Color(0xFFE3F2FD),
              iconColor: Colors.blue,
              title: '数据同步',
              trailingText: '已同步',
            ),
            Divider(
                height: 1,
                color: Colors.black.withOpacity(0.03),
                indent: 16,
                endIndent: 16),
            _buildSettingRow(
              icon: Icons.settings_rounded,
              bgColor: const Color(0xFFF5F5F5),
              iconColor: Colors.grey,
              title: '设置',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    required String title,
    String? trailingText,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    color: ScrapbookColors.inkBlack,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (trailingText != null) ...[
                Text(
                  trailingText,
                  style: TextStyle(
                    fontSize: 11,
                    color: ScrapbookColors.inkBlack.withOpacity(0.4),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Icon(
                Icons.chevron_right_rounded,
                color: ScrapbookColors.inkBlack.withOpacity(0.3),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 模拟划线信笺纸的自定义画笔
class _LinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueGrey.withOpacity(0.08)
      ..strokeWidth = 1.0;

    // 绘制横线
    const double spacing = 18.0;
    double startY = spacing;
    while (startY < size.height) {
      canvas.drawLine(Offset(0, startY), Offset(size.width, startY), paint);
      startY += spacing;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
