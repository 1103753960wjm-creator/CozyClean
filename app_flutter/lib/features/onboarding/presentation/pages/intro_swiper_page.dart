import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cozy_clean/features/blitz/domain/repositories/onboarding_repository.dart';
import 'package:cozy_clean/features/journal/presentation/widgets/poster_components.dart';

class IntroSwiperPage extends ConsumerStatefulWidget {
  const IntroSwiperPage({super.key});

  @override
  ConsumerState<IntroSwiperPage> createState() => _IntroSwiperPageState();
}

class _IntroSwiperPageState extends ConsumerState<IntroSwiperPage>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  late final AudioPlayer _audioPlayer;
  late final AnimationController _elementsController;
  int _currentPage = 0;
  final int _totalSteps = 5;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _audioPlayer = AudioPlayer();
    _elementsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _audioPlayer.dispose();
    _elementsController.dispose();
    super.dispose();
  }

  bool _isAudioDisabled = false;

  void _playFlipSound() async {
    if (_isAudioDisabled) return;
    try {
      // 由于 page_flip.mp3 可能损坏（7字节），在 Android 上播放会抛出异步异常
      await _audioPlayer.play(AssetSource('audio/page_flip.mp3'));
    } catch (e) {
      debugPrint('引导页音效播放失败，已禁用音效: $e');
      _isAudioDisabled = true;
    }
  }

  void _onNext() {
    if (_currentPage < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutQuart,
      );
      _playFlipSound();
    } else {
      _finishOnboarding();
    }
  }

  void _finishOnboarding() async {
    await ref.read(onboardingRepositoryProvider).setSeenIntroSwiper();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5DC),
      body: Stack(
        children: [
          // 1. 动态纸张纹理层
          Positioned.fill(
            child: CustomPaint(
              painter: _PaperTexturePainter(),
            ),
          ),

          // 2. 装饰性背景光�?
          Positioned(
            top: 100,
            right: -50,
            child: _DecorativeBlur(
                color: const Color(0xFFD2B48C).withOpacity(0.1), size: 300),
          ),
          Positioned(
            bottom: 50,
            left: -80,
            child: _DecorativeBlur(
                color: const Color(0xFF8B5E3C).withOpacity(0.1), size: 400),
          ),

          // 3. 页面内容
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
              _playFlipSound();
            },
            itemCount: _totalSteps,
            itemBuilder: (context, index) {
              return _buildAnimatedPage(index);
            },
          ),

          // 4. 固定 UI 元素 (指示器与退�?
          _buildStaticUI(),

          // 5. 底部按钮容器
          _buildBottomAction(),
        ],
      ),
    );
  }

  Widget _buildStaticUI() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 20,
      left: 24,
      right: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildProgressDots(),
          if (_currentPage < _totalSteps - 1)
            GestureDetector(
              onTap: _finishOnboarding,
              child: const Text(
                '跳过',
                style: TextStyle(
                  color: Color(0xFF8C7A6B),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressDots() {
    return Row(
      children: List.generate(_totalSteps, (index) {
        final isActive = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          margin: const EdgeInsets.only(right: 8),
          width: isActive ? 24 : 8,
          height: 6,
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF8B5E3C)
                : const Color(0xFF8B5E3C).withOpacity(0.15),
            borderRadius: BorderRadius.circular(3),
            boxShadow: isActive
                ? [
                    BoxShadow(
                        color: const Color(0xFF8B5E3C).withOpacity(0.2),
                        blurRadius: 4)
                  ]
                : null,
          ),
        );
      }),
    );
  }

  Widget _buildBottomAction() {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 40,
      left: 32,
      right: 32,
      child: Column(
        children: [
          GestureDetector(
            onTap: _onNext,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5E3C),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5A3E29).withOpacity(0.4),
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.1),
                    offset: const Offset(0, -2),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _currentPage == _totalSteps - 1 ? '进入 CozyClean' : '下一页',
                      style: const TextStyle(
                        color: Color(0xFFFDFBF7),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded,
                        color: Color(0xFFFDFBF7), size: 18),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${_currentPage + 1} / $_totalSteps',
            style: const TextStyle(
              color: Color(0x448B5E3C),
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedPage(int index) {
    switch (index) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      case 3:
        return _buildStep4();
      case 4:
        return _buildStep5();
      default:
        return const SizedBox();
    }
  }

  // --- Step 1: Digital Desk ---
  Widget _buildStep1() {
    return _PageBase(
      title: '欢迎来到你的\n数字书桌',
      description: '让我们把拥挤的相册，\n整理成温暖的回忆?',
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned(
            top: 40,
            left: 20,
            child: _HandDrawnText(text: 'Click', rotate: -0.2, opacity: 0.3),
          ),
          const Positioned(
            bottom: 60,
            right: 0,
            child: _HandDrawnText(text: 'Memory', rotate: 0.1, opacity: 0.3),
          ),
          _FloatingWrapper(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 拍立得叠放效�?
                Transform.rotate(
                  angle: 0.08,
                  child: _PolaroidFrame(
                    width: 180,
                    height: 220,
                    child: Container(color: Colors.white),
                  ),
                ),
                Transform.rotate(
                  angle: -0.1,
                  child: _PolaroidFrame(
                    width: 180,
                    height: 220,
                    child: Image.asset(
                      'assets/images/onboarding/welcome.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // 胶带
                Positioned(
                  top: -15,
                  left: 60,
                  child: WashiTape(
                    color: const Color(0xFFD2B48C).withOpacity(0.5),
                    width: 70,
                    height: 24,
                    angle: -0.05,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 30,
            right: 40,
            child: _FloatingWrapper(
              duration: const Duration(seconds: 4),
              child: _CircularBadge(
                icon: Icons.face_retouching_natural,
                iconColor: const Color(0xFF8B5E3C),
                bgColor: Colors.white,
                size: 70,
                hasShadow: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Step 2: Basic Gestures ---
  Widget _buildStep2() {
    return _PageBase(
      title: '极简手势',
      description: '左滑是勇敢告别废片\n右滑是悉数珍藏美好?',
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned(top: 20, left: 30, child: _TwinkleStar(size: 24)),
          const Positioned(top: 40, right: 60, child: _TwinkleStar(size: 14)),
          _FloatingWrapper(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Transform.rotate(
                  angle: 0.05,
                  child: _PolaroidFrame(
                    width: 210,
                    height: 280,
                    title: 'Swipe!',
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(color: const Color(0xFFF9F7F2)),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Icon(Icons.arrow_back_ios_new_rounded,
                                color: Colors.black12, size: 32),
                            Icon(Icons.arrow_forward_ios_rounded,
                                color: Colors.black12, size: 32),
                          ],
                        ),
                        Icon(Icons.touch_app_outlined,
                            color: const Color(0xFF8B5E3C).withOpacity(0.1),
                            size: 80),
                      ],
                    ),
                  ),
                ),
                // 印章
                Positioned(
                  left: -50,
                  top: 100,
                  child: _Stamp(
                      text: '删除',
                      icon: Icons.delete,
                      color: const Color(0xFFD9534F),
                      rotate: -0.2),
                ),
                Positioned(
                  right: -50,
                  top: 100,
                  child: _Stamp(
                      text: '珍藏',
                      icon: Icons.favorite,
                      color: const Color(0xFF5CB85C),
                      rotate: 0.2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Step 3: Advanced Interactions ---
  Widget _buildStep3() {
    return _PageBase(
      title: '高阶交互',
      description: '上滑定格最高光瞬间，\n下滑让犹豫稍后再说?',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 10), // 减小顶部间隙
          _FloatingWrapper(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Transform.translate(
                  offset: const Offset(0, -10), // 减小偏移量从 -20 到 -10
                  child: Transform.rotate(
                    angle: -0.08,
                    child: _PolaroidFrame(
                      width: 140, // 略微减小宽度从 150 到 140
                      height: 190, // 略微减小高度从 200 到 190
                      title: 'Best Day!',
                      child: Image.asset(
                          'assets/images/onboarding/advanced.png',
                          fit: BoxFit.cover),
                    ),
                  ),
                ),
                const Positioned(
                  top: -20,
                  right: -10,
                  child:
                      Icon(Icons.auto_awesome, color: Colors.amber, size: 32),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16), // 减小间距从 20 到 16
          _FloatingWrapper(
            duration: const Duration(seconds: 4),
            child: Opacity(
              opacity: 0.5,
              child: Transform.rotate(
                angle: 0.05,
                child: const _PolaroidFrame(
                  width: 120, // 减小宽度从 130 到 120
                  height: 160, // 减小高度从 170 到 160
                  child: Center(
                      child: Icon(Icons.swipe_down_rounded,
                          color: Colors.black12, size: 40)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20), // 减小间距从 30 到 20
          // 木质笔架底部装饰
          Container(
            width: 220, // 减小宽度从 250 到 220
            height: 36, // 减小高度从 40 到 36
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFFD2B48C), const Color(0xFF8B5E3C)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)
              ],
            ),
            child: Center(
              child: Container(
                  width: 60,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(2))),
            ),
          ),
        ],
      ),
    );
  }

  // --- Step 4: Scrapbook Poster ---
  Widget _buildStep4() {
    return _PageBase(
      title: '记录高光',
      description: '每一轮清理结束，你收藏过的高光\n都会整合自动生成长图供你分享',
      child: Center(
        child: _FloatingWrapper(
          child: Container(
            width: 240,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFDFBF7),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 25,
                    offset: const Offset(0, 10)),
              ],
              border: Border.all(color: const Color(0xFFE8E0D5)),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Today\'s Story',
                            style: TextStyle(
                                fontFamily: 'serif',
                                fontSize: 16,
                                color: Color(0xFF8B5E3C),
                                fontWeight: FontWeight.bold)),
                        Text('2024.03.04',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.withOpacity(0.7))),
                      ],
                    ),
                    const Divider(
                        height: 20, thickness: 1.5, color: Color(0x118B5E3C)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MiniPolaroid(
                            path: 'assets/images/onboarding/poster1.jpg',
                            size: 90,
                            rotate: 0.05),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              border: Border(
                                  left: BorderSide(
                                      color: Colors.redAccent, width: 2)),
                              color: Color(0x05D9534F),
                            ),
                            child: const Text('阳光正好，微风不燥。清理完照片，心情也变得清爽起来...',
                                style: TextStyle(
                                    fontSize: 9,
                                    height: 1.4,
                                    fontStyle: FontStyle.italic,
                                    color: Color(0xFF4A3B32))),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _MiniPolaroid(
                        path: 'assets/images/onboarding/poster2.jpg',
                        size: 140,
                        rotate: -0.02),
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.bottomRight,
                      child: Text('COZYCLEAN',
                          style: TextStyle(
                              fontSize: 8,
                              letterSpacing: 2,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                // 顶部固定胶带
                Positioned(
                  top: -30,
                  left: 60,
                  child: WashiTape(
                      color: const Color(0xFFE6D5C3).withOpacity(0.8),
                      width: 100,
                      angle: 0.02),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Step 5: Achievement ---
  Widget _buildStep5() {
    return _PageBase(
      title: '治愈与成就?',
      description: '每天 5 分钟，解锁成就勋章，\n治愈相册空间和你的内心?',
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 旋转虚线�?
          RotationTransition(
            turns: _elementsController,
            child: CustomPaint(
              size: const Size(260, 260),
              painter: _DashedCirclePainter(
                  color: const Color(0xFF8B5E3C).withOpacity(0.4)),
            ),
          ),

          _FloatingWrapper(
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.15), blurRadius: 20)
                ],
                border: Border.all(color: const Color(0xFFFFF8E7), width: 5),
              ),
              child: const Icon(Icons.verified_user_rounded,
                  color: Color(0xFF8B5E3C), size: 64),
            ),
          ),

          _buildBadgeAnim(Icons.local_florist, 0, -90, Colors.amber),
          _buildBadgeAnim(Icons.cleaning_services, 90, 0, Colors.brown),
          _buildBadgeAnim(Icons.photo_library, -90, 0, Colors.blueGrey),
          _buildBadgeAnim(Icons.energy_savings_leaf, 0, 90, Colors.green),
        ],
      ),
    );
  }

  Widget _buildBadgeAnim(IconData icon, double x, double y, Color color) {
    return _FloatingWrapper(
      duration: const Duration(seconds: 4),
      child: Transform.translate(
        offset: Offset(x, y),
        child: _CircularBadge(
            icon: icon,
            iconColor: color,
            bgColor: const Color(0xFFFFF5E6),
            size: 44,
            hasShadow: true),
      ),
    );
  }
}

// --- 支撑组件 ---

class _PageBase extends StatelessWidget {
  final String title;
  final String description;
  final Widget child;

  const _PageBase(
      {required this.title, required this.description, required this.child});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          // 动态顶部边距 (压缩顶部以释放中间和底部空间)
          SizedBox(height: screenHeight * 0.06),
          Expanded(child: child),
          const SizedBox(height: 16), // 减少间距
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF8B5E3C),
              fontSize: 24, // 进一步精简字体尺寸，防止多行文本挤压
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8), // 减少间距
          Text(
            description,
            textAlign: TextAlign.center,
            maxLines: 3, // 限制行数防止极端情况溢出
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF8C7A6B).withOpacity(0.8),
              fontSize: 14,
              height: 1.4,
              fontStyle: FontStyle.italic,
            ),
          ),
          // 增加底部边距，确保文字处于按钮和指示器之上 (0.12 -> 0.18)
          SizedBox(height: screenHeight * 0.18),
        ],
      ),
    );
  }
}

class _PolaroidFrame extends StatelessWidget {
  final double width;
  final double height;
  final Widget child;
  final String? title;

  const _PolaroidFrame(
      {required this.width,
      required this.height,
      required this.child,
      this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 15,
              offset: const Offset(0, 8)),
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Expanded(
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(1), child: child)),
          if (title != null) ...[
            const SizedBox(height: 10),
            Text(title!,
                style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 16,
                    color: Color(0xFF8B5E3C),
                    fontStyle: FontStyle.italic)),
          ] else
            const SizedBox(height: 15),
        ],
      ),
    );
  }
}

class _MiniPolaroid extends StatelessWidget {
  final String path;
  final double size;
  final double rotate;

  const _MiniPolaroid(
      {required this.path, required this.size, required this.rotate});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotate,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)
          ],
        ),
        child: Image.asset(path,
            width: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
                width: size,
                height: size,
                color: Colors.grey.withOpacity(0.1))),
      ),
    );
  }
}

class _FloatingWrapper extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const _FloatingWrapper(
      {required this.child, this.duration = const Duration(seconds: 3)});

  @override
  State<_FloatingWrapper> createState() => _FloatingWrapperState();
}

class _FloatingWrapperState extends State<_FloatingWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: -6.0, end: 6.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) =>
          Transform.translate(offset: Offset(0, _anim.value), child: child),
      child: widget.child,
    );
  }
}

class _TwinkleStar extends StatefulWidget {
  final double size;

  const _TwinkleStar({required this.size});

  @override
  State<_TwinkleStar> createState() => _TwinkleStarState();
}

class _TwinkleStarState extends State<_TwinkleStar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.8, end: 1.2).animate(_ctrl),
        child: Icon(Icons.star_rounded,
            color: const Color(0xFFD2B48C), size: widget.size),
      ),
    );
  }
}

class _Stamp extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  final double rotate;

  const _Stamp(
      {required this.text,
      required this.icon,
      required this.color,
      required this.rotate});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotate,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              shape: BoxShape.circle,
              border:
                  Border.all(color: color, width: 3, style: BorderStyle.none),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 4)
              ],
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 4),
          Text(text,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}

class _CircularBadge extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final double size;
  final bool hasShadow;

  const _CircularBadge(
      {required this.icon,
      required this.iconColor,
      required this.bgColor,
      required this.size,
      this.hasShadow = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        boxShadow: hasShadow
            ? [
                BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ]
            : null,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(icon, color: iconColor, size: size * 0.5),
    );
  }
}

class _HandDrawnText extends StatelessWidget {
  final String text;
  final double rotate;
  final double opacity;

  const _HandDrawnText(
      {required this.text, required this.rotate, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotate,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 32,
          color: const Color(0xFFD2B48C).withOpacity(opacity),
          fontStyle: FontStyle.italic,
          fontFamily: 'serif',
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _DecorativeBlur extends StatelessWidget {
  final Color color;
  final double size;

  const _DecorativeBlur({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(color: Colors.transparent),
      ),
    );
  }
}

class _PaperTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFD2B48C).withOpacity(0.15);
    const spacing = 24.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 0.8, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  const _DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    const double dashWidth = 8.0;
    const double dashSpace = 8.0;
    final double radius = size.width / 2;
    final double circum = 2 * math.pi * radius;
    final int dashCount = (circum / (dashWidth + dashSpace)).floor();

    for (int i = 0; i < dashCount; i++) {
      final double startAngle =
          (i * (dashWidth + dashSpace) / circum) * 2 * math.pi;
      final double sweepAngle = (dashWidth / circum) * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(radius, radius), radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
