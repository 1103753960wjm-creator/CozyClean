import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cozy_clean/features/blitz/presentation/pages/blitz_page.dart';
import '../controllers/user_stats_controller.dart';
import 'profile_page.dart';
import 'package:cozy_clean/features/journal/presentation/pages/journal_page.dart';
import 'package:cozy_clean/features/journal/application/controllers/journal_controller.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // 基础骨架，手账风暖白底色
    return Scaffold(
      backgroundColor: const Color(0xFFF5F1E5),
      bottomNavigationBar: _buildBottomNav(),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildDashboardContent(),
          const JournalPage(),
          const ProfilePage(),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(ref),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  _buildDataRing(ref),
                  const SizedBox(height: 20),
                  const Text(
                    '整理照片，就像整理心情。\n今天也要轻松一下哦。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF867C6A),
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildModeSection(context),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFD8B99E),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.person, color: Color(0xFF4A4238), size: 28),
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '早安,',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF867C6A),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '暖心妈妈',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4A4238),
                    ),
                  ),
                ],
              ),
            ],
          ),
          GestureDetector(
            onTap: () {
              final isPro =
                  ref.read(userStatsStreamProvider).value?.isPro ?? false;
              ref.read(userStatsControllerProvider).togglePro(!isPro);
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.settings,
                  color: Color(0xFF867C6A), size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRing(WidgetRef ref) {
    final userStatsAsync = ref.watch(userStatsStreamProvider);
    return Center(
      child: SizedBox(
        width: 190,
        height: 190,
        child: userStatsAsync.when(
          data: (stats) {
            final isPro = stats.isPro;
            final double rawProgress = isPro
                ? 1.0
                : (stats.dailyEnergyRemaining / 100.0).clamp(0.0, 1.0);
            return Stack(
              fit: StackFit.expand,
              children: [
                const CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 12,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEBE3D0)),
                ),
                Transform.flip(
                  flipX: true,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: rawProgress),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return CircularProgressIndicator(
                        value: value,
                        strokeWidth: 12,
                        backgroundColor: Colors.transparent,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF865F43)),
                      );
                    },
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 8),
                    const Text(
                      '今日能量',
                      style: TextStyle(fontSize: 12, color: Color(0xFF867C6A)),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          isPro ? '∞' : '${stats.dailyEnergyRemaining.toInt()}',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF6B453E),
                          ),
                        ),
                        if (!isPro)
                          const Text(
                            '/50',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFA1978A),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEBE3D0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt,
                              size: 14, color: Color(0xFF865F43)),
                          const SizedBox(width: 4),
                          Text(
                            isPro ? '全站免费' : '能量充足',
                            style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF865F43),
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
          loading: () => const Center(
              child: CircularProgressIndicator(color: Color(0xFF865F43))),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildModeSection(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '选择清理模式',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A4238)),
              ),
              GestureDetector(
                onTap: () {
                  _showAllModesModal(context);
                },
                child: const Row(
                  children: [
                    Text('全部 ',
                        style:
                            TextStyle(fontSize: 13, color: Color(0xFF867C6A))),
                    Icon(Icons.arrow_forward_ios,
                        size: 10, color: Color(0xFF867C6A)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 264,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _buildBigModeCard(
                context,
                title: '⚡ 闪电模式',
                subtitle: '快速清理相似照片，释放空间。',
                imagePath: 'assets/images/mode_blitz_bg.png',
                badge: 'FREE',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const BlitzPage())),
              ),
              const SizedBox(width: 16),
              _buildBigModeCard(
                context,
                title: '✂️ 截图粉碎机',
                subtitle: '自动识别并清理过期截图。',
                imagePath: 'assets/images/mode_shredder_bg.png',
                badge: 'PRO',
                isPro: true,
                onTap: () => _showComingSoon(context),
              ),
              const SizedBox(width: 16),
              _buildBigModeCard(
                context,
                title: '⌛ 时光旅行',
                subtitle: '重温美好回忆，拾起遗忘角落。',
                imagePath: 'assets/images/mode_time_machine_bg.png',
                badge: 'PRO',
                isPro: true,
                onTap: () => _showComingSoon(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBigModeCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String imagePath,
    required String badge,
    bool isPro = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 191,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(imagePath, fit: BoxFit.cover),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPro ? const Color(0xFFDCD2E7) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isPro
                                ? const Color(0xFF6B453E)
                                : const Color(0xFF865F43)),
                      ),
                    ),
                  ),
                  if (isPro)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                            color: Color(0xFF865F43), shape: BoxShape.circle),
                        child: const Icon(Icons.lock,
                            size: 14, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6B453E)),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(
                        subtitle,
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF867C6A),
                            height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllModesModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Color(0xFFF5F1E5),
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Row(
                children: [
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_back,
                          color: Color(0xFF6B453E), size: 20),
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text('全部模式',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4A4238))),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.85,
                  children: [
                    _buildGridCard(ctx,
                        title: '⚡ 闪电模式',
                        subtitle: '快速清理相似照片',
                        imagePath: 'assets/images/mode_blitz_bg.png',
                        badge: 'FREE', onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const BlitzPage()));
                    }),
                    _buildGridCard(ctx,
                        title: '✂️ 截图粉碎机',
                        subtitle: '清理过期截图',
                        imagePath: 'assets/images/mode_shredder_bg.png',
                        badge: 'PRO',
                        isPro: true,
                        onTap: () => _showComingSoon(ctx)),
                    _buildGridCard(ctx,
                        title: '⌛ 时光旅行',
                        subtitle: '重温美好回忆',
                        imagePath: 'assets/images/mode_time_machine_bg.png',
                        badge: 'PRO',
                        isPro: true,
                        onTap: () => _showComingSoon(ctx)),
                    _buildComingSoonGridCard(),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 40),
                child: Text(
                  '"每张照片都是时光的标本，\n值得被温柔对待。"',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF867C6A),
                      fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGridCard(BuildContext context,
      {required String title,
      required String subtitle,
      required String imagePath,
      required String badge,
      bool isPro = false,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 4))
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(imagePath, fit: BoxFit.cover),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                          color: isPro ? const Color(0xFFDCD2E7) : Colors.white,
                          borderRadius: BorderRadius.circular(10)),
                      child: Text(badge,
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isPro
                                  ? const Color(0xFF6B453E)
                                  : const Color(0xFF865F43))),
                    ),
                  ),
                  if (isPro)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                            color: Color(0xFF865F43), shape: BoxShape.circle),
                        child: const Icon(Icons.lock,
                            size: 12, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6B453E))),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF867C6A))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComingSoonGridCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFFEBE3D0),
            width: 1.5,
            style: BorderStyle.solid),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add, size: 32, color: Color(0xFFD8B99E)),
          SizedBox(height: 12),
          Text('敬请期待',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF867C6A))),
          SizedBox(height: 4),
          Text('更多模式开发中',
              style: TextStyle(fontSize: 10, color: Color(0xFFA1978A))),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('建设中，即将上线！🛠️', textAlign: TextAlign.center),
        backgroundColor: Color(0xFF865F43),
        duration: Duration(seconds: 2),
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
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          // 切换到手账 tab 时刷新列表
          if (index == 1) {
            ref.read(journalControllerProvider.notifier).loadJournals();
          }
        },
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
            label: '首页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_stories_outlined),
            activeIcon: Icon(Icons.auto_stories),
            label: '手账',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
