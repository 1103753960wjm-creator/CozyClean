import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:confetti/confetti.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:cozy_clean/features/blitz/application/controllers/blitz_controller.dart';
import 'package:cozy_clean/features/journal/presentation/pages/poster_page.dart';
import 'package:cozy_clean/features/profile/application/controllers/user_stats_controller.dart';

/// 总结算动画页面 (Summary Page)
///
/// 两种结算流：
/// 1. 正常删除流：信封归档打包动画 → 系统级批量删除 → 撒花结算
/// 2. 全员珍藏流 (All-Kept)：跳过信封和删除 → 直接撒花 + 温暖结算 UI
class SummaryPage extends ConsumerStatefulWidget {
  final List<AssetEntity> deleteSet;

  /// 本次会话中用户收藏的照片（上滑收藏，最多 6 张）
  final List<AssetEntity> favoriteSet;

  /// 本次会话中用户审阅的照片总数
  final int totalReviewedCount;

  const SummaryPage({
    super.key,
    required this.deleteSet,
    this.favoriteSet = const [],
    this.totalReviewedCount = 0,
  });

  @override
  ConsumerState<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends ConsumerState<SummaryPage>
    with TickerProviderStateMixin {
  // --- 动效控制器 ---
  late AnimationController _envelopeAnimCtrl;

  late List<Animation<Offset>> _photosSlideAnims;
  late List<Animation<double>> _photosScaleAnims;
  late List<Animation<double>> _photosRotateAnims;

  late Animation<double> _flapRotateAnim;
  late Animation<double> _sealScaleAnim;
  late Animation<double> _sealOpacityAnim;
  late Animation<double> _envelopeBumpAnim;

  // --- 状态流转标识 ---
  late ConfettiController _confettiController;
  bool _isDeleting = false;
  bool _deleteFinished = false;
  int _actualDeletedCount = 0;
  String? _errorMessage;

  /// 全员珍藏流标识：当 deleteSet 为空时激活
  bool _isAllKeptFlow = false;

  // 假设常量：每张照片预计节省空间
  static const double _savingsPerPhotoMb = 3.0;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));

    // 强制初始化所有的动画，防止在空数据下层 build 报错 LateInitializationError
    _initAnimations();

    // ======================================
    // 全员珍藏流 (All-Kept Flow)
    // ======================================
    // 当用户保留了全部照片（deleteSet 为空），跳过信封动画和系统删除弹窗，
    // 直接进入温暖的"全员珍藏"结算页面并播放撒花。
    //
    // TODO: 全员珍藏路由分发
    // 情况 A：一张没删，但有上滑高光操作 (highlightSet.isNotEmpty)
    //   → 直接跳转至 [手账海报生成器]
    //   → 海报底部水印变为："重温了 N 张旧时光，留下了最闪耀的这一刻。"
    //
    // 情况 B：一张没删，也没上滑 (highlightSet.isEmpty) — 当前实现
    //   → 进入全员珍藏结果页
    // ======================================
    if (widget.deleteSet.isEmpty) {
      _isAllKeptFlow = true;
      _deleteFinished = true;
      // Bug #4 修复：全员珍藏流必须先提交 Keep 草稿，否则记录全部丢失
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final currentState = ref.read(blitzControllerProvider);
        ref.read(userStatsControllerProvider).commitBlitzSession(
          keeps: {
            ...currentState.sessionKept.map((p) => p.id),
            ...currentState.sessionFavorites.map((p) => p.id),
          },
          deletes: const {},
          savedBytes: 0,
        );
        ref.read(blitzControllerProvider.notifier).clearSessionDraft();

        _confettiController.play();
      });
      return;
    }

    // 第一帧绘制完成后，立刻播放打包动画
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _envelopeAnimCtrl.forward();
    });
  }

  void _initAnimations() {
    _envelopeAnimCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));

    _photosSlideAnims = [];
    _photosScaleAnims = [];
    _photosRotateAnims = [];

    // Phase 1: 0.0 - 0.5 照片交错飞入
    int photoCount = widget.deleteSet.take(3).length;
    for (int i = 0; i < photoCount; i++) {
      double start = i * 0.1;
      double end = start + 0.3;

      // 生成三个不同的抛物线起点
      double startX = (i == 0) ? -1.0 : (i == 2 ? 1.0 : 0.0);

      _photosSlideAnims.add(Tween<Offset>(
              begin: Offset(startX, -1.5), end: const Offset(0.0, 0.0))
          .animate(
        CurvedAnimation(
          parent: _envelopeAnimCtrl,
          curve: Interval(start, end, curve: Curves.easeInCubic),
        ),
      ));

      _photosScaleAnims.add(Tween<double>(begin: 1.2, end: 0.4).animate(
        CurvedAnimation(
          parent: _envelopeAnimCtrl,
          curve: Interval(start, end, curve: Curves.easeOut),
        ),
      ));

      _photosRotateAnims
          .add(Tween<double>(begin: (i - 1) * 0.6, end: (i - 1) * 0.15).animate(
        CurvedAnimation(
          parent: _envelopeAnimCtrl,
          curve: Interval(start, end, curve: Curves.easeInOut),
        ),
      ));
    }

    // Phase 2: 0.5 - 0.8 信封盖 3D 合拢
    _flapRotateAnim = Tween<double>(begin: -math.pi, end: 0.0).animate(
      CurvedAnimation(
        parent: _envelopeAnimCtrl,
        curve: const Interval(0.5, 0.8, curve: Curves.easeInOutBack),
      ),
    );

    // Phase 3: 0.8 - 1.0 火漆印章重重砸下
    _sealOpacityAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _envelopeAnimCtrl,
        curve: const Interval(0.8, 0.85, curve: Curves.easeIn),
      ),
    );
    _sealScaleAnim = Tween<double>(begin: 3.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _envelopeAnimCtrl,
        curve: const Interval(0.8, 1.0, curve: Curves.elasticOut),
      ),
    );

    // Phase 4: 0.8 - 1.0 伴随印章砸下的全局应力震荡 (Bump)
    _envelopeBumpAnim = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween<double>(begin: 0.0, end: 15.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 1),
      TweenSequenceItem(
          tween: Tween<double>(begin: 15.0, end: -5.0)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 1),
      TweenSequenceItem(
          tween: Tween<double>(begin: -5.0, end: 0.0)
              .chain(CurveTween(curve: Curves.elasticOut)),
          weight: 2),
    ]).animate(
      CurvedAnimation(
        parent: _envelopeAnimCtrl,
        curve: const Interval(0.8, 1.0), // 修复越界：Flutter 规定 end 必须 <= 1.0
      ),
    );

    // 监听动画完成事件，一旦封装完毕，无缝衔接触发真实批量删除
    _envelopeAnimCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _executeBulkDelete();
      }
    });
  }

  /// 核心底层删除逻辑
  Future<void> _executeBulkDelete() async {
    setState(() {
      _isDeleting = true;
    });

    try {
      final idsToDelete = widget.deleteSet.map((e) => e.id).toList();
      debugPrint('[SummaryPage] 开始会话删除: ${idsToDelete.length} 张');

      // 强行清理 Flutter 引擎内的 Image 文件缓存，防止由于上一个页面的 Image.file 未释放导致 FD 文件句柄占用
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      final deletedList = await ref
          .read(blitzControllerProvider.notifier)
          .confirmDeletion(idsToDelete);

      debugPrint('[SummaryPage] 删除结果: $deletedList');

      if (!mounted) return;

      // 如果本来就无需删除，或者最终系统确认且回调执行了清理
      final isSuccess = idsToDelete.isEmpty || deletedList.isNotEmpty;

      if (isSuccess) {
        _actualDeletedCount = deletedList.length;
        _deleteFinished = true;
        _confettiController.play(); // 播撒欢乐纸屑

        // ---- 数据结算：写入 Drift 数据库 ----
        // 使用页面常量 _savingsPerPhotoMb 计算节省空间，杜绝魔法数字
        final savedBytes =
            (_actualDeletedCount * _savingsPerPhotoMb * 1024 * 1024).toInt();

        final currentState = ref.read(blitzControllerProvider);
        ref.read(userStatsControllerProvider).commitBlitzSession(
            keeps: {
              ...currentState.sessionKept.map((p) => p.id),
              ...currentState.sessionFavorites.map((p) => p.id),
            },
            deletes: currentState.sessionDeleted.map((p) => p.id).toSet(),
            savedBytes: savedBytes);
        ref.read(blitzControllerProvider.notifier).clearSessionDraft();
      } else {
        // 用户有需要删除的照片，但底层返回空，代表被用户拒绝授权或底层失败
        _errorMessage = '操作被取消或清理失败';
        debugPrint(
            '[SummaryPage] 错误: deletedList is empty despite requesting deletions.');
        _deleteFinished = true;
      }
    } catch (e, stack) {
      debugPrint('[SummaryPage] 捕捉到异常: $e');
      debugPrint(stack.toString());
      if (!mounted) return;
      _errorMessage = '发生系统异常: $e';
      _deleteFinished = true;
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _envelopeAnimCtrl.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6), // 手账风
      body: Stack(
        children: [
          // ====================
          // 1. 底层：打包动画区
          // ====================
          if (!_deleteFinished && _errorMessage == null)
            Center(
              child: _buildEnvelopeAnimation(),
            ),

          // ====================
          // 2. 顶层：最终结算面板 (包含成功/取消/失败的状态兜底)
          // ====================
          if (_deleteFinished) ...[
            _buildResultContent(),
            // 顶层挂载喷射器
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Color(0xFF8BA888),
                  Color(0xFFE57373),
                  Color(0xFFFFD54F),
                  Color(0xFF81D4FA),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 信封仪式的组合动画栈
  Widget _buildEnvelopeAnimation() {
    return AnimatedBuilder(
      animation: _envelopeAnimCtrl,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _envelopeBumpAnim.value),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // A. 信封后衬底 (底层纸袋) + 内阴影模拟袋口
              Container(
                width: 200,
                height: 140,
                decoration: BoxDecoration(
                  color: const Color(0xFFC4A484), // 深牛皮纸色
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      offset: Offset(0, 5),
                      blurRadius: 15,
                    ),
                  ],
                ),
                alignment: Alignment.topCenter,
                // 袋口阴影遮罩
                child: Container(
                  height: 20,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.2),
                        Colors.transparent,
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                ),
              ),

              // B. 交错飞入的照片们
              // 避免在 widget.deleteSet.isEmpty 的情况下强行渲染可能出错
              if (widget.deleteSet.isNotEmpty) ..._buildAnimatedThumbnails(),

              // C1. 信封前包体 (底层不动)
              Positioned(
                bottom: 0,
                child: Container(
                  width: 200,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7BFA6),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 12,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                ),
              ),

              // C2. 3D 信封顶盖翻折 (铰链在 top: 40)
              Positioned(
                top: 40,
                child: Transform(
                  alignment: Alignment.topCenter,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.002) // 3D 透视视效
                    ..rotateX(_flapRotateAnim.value),
                  child: Container(
                    height: 80,
                    width: 200,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD7BFA6),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(40),
                        bottomRight: Radius.circular(40),
                      ),
                      border: Border.all(
                        color: Colors.black.withOpacity(0.05),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),

              // D. 火漆印章砸下封印 (顶层缩放)
              if (_envelopeAnimCtrl.value > 0.75)
                Positioned(
                  top: 90,
                  child: Transform.scale(
                    scale: _sealScaleAnim.value,
                    child: Opacity(
                      opacity: _sealOpacityAnim.value,
                      child: Container(
                        width: 55,
                        height: 55,
                        decoration: BoxDecoration(
                          color: const Color(0xFFB54B4B), // 暗红色火漆
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              // 泛光环境阴影
                              color: const Color(0xFFB54B4B).withOpacity(0.6),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                            BoxShadow(
                              // 锐利实体重心阴影
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),

              // 正在呼叫系统删除时的菊花 Loading
              if (_isDeleting)
                const Positioned(
                  bottom: -60,
                  child: Text(
                    '系统删除确认中...',
                    style: TextStyle(color: Colors.black45, fontSize: 14),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// 构建交替飘落的缩略图列表
  List<Widget> _buildAnimatedThumbnails() {
    final previewPhotos = widget.deleteSet.take(3).toList();
    if (previewPhotos.isEmpty || _photosSlideAnims.isEmpty) return [];

    return List.generate(previewPhotos.length, (index) {
      final photo = previewPhotos[index];
      // 防止越界（动效数组以长度生成）
      if (index >= _photosSlideAnims.length) return const SizedBox.shrink();

      return Transform.translate(
        // x 轴使用系数，y 轴 * 250 是高度掉落距离
        offset: Offset(_photosSlideAnims[index].value.dx * 80,
            _photosSlideAnims[index].value.dy * 250),
        child: Transform.scale(
          scale: _photosScaleAnims[index].value,
          child: Transform.rotate(
            angle: _photosRotateAnims[index].value,
            child: Container(
              width: 120,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(4, 4),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: FutureBuilder<Uint8List?>(
                  future: photo
                      .thumbnailDataWithSize(const ThumbnailSize.square(300)),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      return Image.memory(
                        snapshot.data!,
                        fit: BoxFit.cover,
                      );
                    }
                    return Container(color: Colors.grey[200]);
                  },
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  /// 构建最终展现结果
  ///
  /// 三种状态：
  /// 1. 全员珍藏流 (_isAllKeptFlow) → 温暖的 🌸 结算页
  /// 2. 正常删除成功 (isSuccess)     → ✨ 清理完成结算页
  /// 3. 删除取消/失败 (!isSuccess)   → 😅 中止提示页
  Widget _buildResultContent() {
    // 全员珍藏流：专属温暖 UI
    if (_isAllKeptFlow) {
      return _buildAllKeptResult();
    }

    final bool isSuccess = _actualDeletedCount > 0 && _errorMessage == null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶部 Emoji
            Text(
              isSuccess ? '✨' : '😅',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 72),
            ),
            const SizedBox(height: 16),

            // 庆祝/提示文案
            Text(
              isSuccess ? '清理完成！' : '清理已被中止',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isSuccess ? const Color(0xFF4A6B48) : Colors.black54,
              ),
            ),

            if (!isSuccess) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? '未做任何修改',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 14),
              ),
            ],

            const SizedBox(height: 48),

            // 无论成功失败，只要有数字都会展示
            if (isSuccess)
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
                        label: '真实清理',
                        targetValue: _actualDeletedCount.toDouble(),
                        suffix: '张',
                        isFloat: false,
                      ),
                      const SizedBox(height: 20),
                      const Divider(color: Color(0xFFE8F0E6), thickness: 1.5),
                      const SizedBox(height: 20),
                      _buildStatRow(
                        label: '预估释放',
                        targetValue: _actualDeletedCount * _savingsPerPhotoMb,
                        suffix: 'MB',
                        isFloat: true,
                        highlight: true,
                      ),
                    ],
                  ),
                ),
              ),

            // 收藏照片堆叠展示 + 生成手账海报按钮
            if (isSuccess && widget.favoriteSet.isNotEmpty)
              _buildFavoritesSection(),

            const SizedBox(height: 24),

            // 底部胶囊按钮
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isSuccess ? const Color(0xFF8BA888) : Colors.grey[400],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  elevation: 4,
                  shadowColor:
                      (isSuccess ? const Color(0xFF8BA888) : Colors.grey)
                          .withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  isSuccess ? '太棒了！返回首页' : '明白了，返回首页',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 全员珍藏专属结算页 (All-Kept Flow)
  ///
  /// 用户保留了所有照片时展示的温暖结算 UI：
  /// - 🌸 Emoji + "全员珍藏" 大标题
  /// - 照片总数统计卡片
  /// - 撒花效果（由 initState 中触发）
  /// - 不播放信封动画，不弹出系统删除确认框
  Widget _buildAllKeptResult() {
    final int reviewedCount = widget.totalReviewedCount;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 🌸 大 Emoji
            const Text(
              '🌸',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 72),
            ),
            const SizedBox(height: 16),

            // 大标题
            const Text(
              '全员珍藏',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A6B48),
              ),
            ),
            const SizedBox(height: 8),

            // 副标题
            const Text(
              '所有照片都是宝贵的回忆呢',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontStyle: FontStyle.italic,
                color: Color(0xFF8BA888),
                letterSpacing: 1.5,
              ),
            ),

            const SizedBox(height: 48),

            // 统计卡片
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // 巨大数字
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                          begin: 0, end: reviewedCount.toDouble()),
                      duration: const Duration(seconds: 2),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Text(
                          '${value.toInt()}',
                          style: const TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFD4AF37),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '个美好瞬间已悉数珍藏',
                      style: TextStyle(
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF6B453E),
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 收藏照片堆叠展示（全员珍藏流也显示）
            if (widget.favoriteSet.isNotEmpty) _buildFavoritesSection(),

            const SizedBox(height: 32),

            // 底部提示语
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                '今天没有需要告别的废片，全都是宝贵的记忆呢。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black38,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 底部胶囊按钮
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8BA888),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  elevation: 4,
                  shadowColor: const Color(0xFF8BA888).withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  '回到首页',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
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

  /// 收藏照片堆叠展示 + "生成手账海报"按钮
  ///
  /// 将上滑收藏的照片以拍立得风格堆叠显示，
  /// 并附带金色"生成手账海报"按钮引导用户进入海报编辑页。
  Widget _buildFavoritesSection() {
    final favorites = widget.favoriteSet;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      child: Column(
        children: [
          // 分割线
          const Divider(color: Color(0xFFE8E0D4), thickness: 1),
          const SizedBox(height: 12),

          // 标题
          const Text(
            '✨ 收藏的瞬间',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4A4238),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),

          // 堆叠照片
          SizedBox(
            height: 100,
            child: Center(
              child: SizedBox(
                width: favorites.length * 30.0 + 60,
                height: 100,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: List.generate(favorites.length, (index) {
                    final photo = favorites[index];
                    // 交替旋转角度，制造堆叠感
                    final angle = (index - favorites.length / 2) * 0.08;
                    final offsetX = index * 30.0;

                    return Positioned(
                      left: offsetX,
                      child: Transform.rotate(
                        angle: angle,
                        child: Container(
                          width: 64,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: Colors.white,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 6,
                                offset: const Offset(2, 3),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(1),
                            child: AssetEntityImage(
                              photo,
                              isOriginal: false,
                              thumbnailSize: const ThumbnailSize(200, 200),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: const Color(0xFFF0EBE2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // "生成手账海报"按钮
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PosterPage(photos: favorites),
                  ),
                );
              },
              icon: const Icon(Icons.auto_stories_rounded, size: 18),
              label: const Text(
                '生成手账海报',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.white,
                elevation: 2,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
