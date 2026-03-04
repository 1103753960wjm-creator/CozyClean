/// CozyClean — 手账海报生成页
///
/// 展示用户收藏的照片（最多 6 张），以拍立得贴纸风格
/// 双列随机交错排列在手账风长图上。
///
/// 功能：
///   1. 双列随机交错拍立得布局
///   2. 可编辑标题 + 感受输入
///   3. Widget→Image 渲染生成海报
///   4. 保存/分享后跳转详情页
///   5. 保存到手账历史（Journals 表）
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:cozy_clean/data/local/app_database.dart';
import 'package:cozy_clean/features/journal/presentation/pages/journal_detail_page.dart';
import 'package:cozy_clean/features/journal/presentation/widgets/poster_components.dart';
import 'package:cozy_clean/features/blitz/data/providers/blitz_data_providers.dart'; // 导入 database provider

/// 手账海报生成页
class PosterPage extends ConsumerStatefulWidget {
  /// 收藏的照片列表
  final List<AssetEntity> photos;

  const PosterPage({super.key, required this.photos});

  @override
  ConsumerState<PosterPage> createState() => _PosterPageState();
}

class _PosterPageState extends ConsumerState<PosterPage> {
  final GlobalKey _repaintKey = GlobalKey();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _feelingController = TextEditingController();
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _titleController.text = 'COZYCLEAN 治愈记忆瞬间';
    // 输入时实时刷新海报预览和字数提示
    _titleController.addListener(_handleStateChange);
    _feelingController.addListener(_handleStateChange);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _feelingController.dispose();
    super.dispose();
  }

  // ============================================================
  // 海报渲染与保存
  // ============================================================

  /// 将海报 Widget 渲染为图片，保存到文件和数据库
  ///
  /// 返回保存的 [Journal] 记录，用于跳转详情页。
  Future<Journal?> _generateAndSave() async {
    // 渲染海报前，先移除控制器监听器，防止渲染过程中的异步 UI 变更导致 RepaintBoundary 失效或图片重新加载
    _titleController.removeListener(_handleStateChange);
    _feelingController.removeListener(_handleStateChange);

    try {
      setState(() => _isGenerating = true);
      // 给 UI 一个短暂的稳定窗口，确保图片加载完全，防止捕获到占位符
      await Future.delayed(const Duration(milliseconds: 300));

      // 1. 捕获 RepaintBoundary
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;

      // 2.0 倍率足以产生清晰的 800px 左右长图，同时显著降低内存压力
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final bytes = byteData.buffer.asUint8List();

      // 2. 保存到文件系统
      final dir = await getApplicationDocumentsDirectory();
      final posterDir = Directory('${dir.path}/posters');
      if (!await posterDir.exists()) {
        await posterDir.create(recursive: true);
      }

      final fileName = 'poster_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${posterDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      // 3. 保存到数据库
      final db = ref.read(appDatabaseProvider);
      final companion = JournalsCompanion.insert(
        title: _titleController.text.isEmpty
            ? 'COZYCLEAN 治愈记忆瞬间'
            : _titleController.text,
        photoIds: jsonEncode(widget.photos.map((p) => p.id).toList()),
        posterPath: file.path,
        feeling: Value(
            _feelingController.text.isEmpty ? null : _feelingController.text),
      );

      final id = await db.into(db.journals).insert(companion);

      // 查询刚插入的记录
      return await (db.select(db.journals)..where((t) => t.id.equals(id)))
          .getSingle();
    } catch (e) {
      debugPrint('海报生成失败: $e');
      return null;
    } finally {
      // 恢复监听
      if (mounted) {
        _titleController.addListener(_handleStateChange);
        _feelingController.addListener(_handleStateChange);
        setState(() => _isGenerating = false);
      }
    }
  }

  void _handleStateChange() {
    if (mounted) setState(() {});
  }

  /// 保存海报并跳转详情页
  Future<void> _saveAndNavigate() async {
    HapticFeedback.mediumImpact();
    final journal = await _generateAndSave();
    if (journal != null && mounted) {
      // 替换当前页为详情页（避免按 back 回到编辑页）
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => JournalDetailPage(journal: journal)),
      );
    }
  }

  /// 分享海报（先生成再分享，分享后跳转详情页）
  Future<void> _shareAndNavigate() async {
    HapticFeedback.lightImpact();
    final journal = await _generateAndSave();
    if (journal != null && mounted) {
      await Share.shareXFiles([XFile(journal.posterPath)], text: journal.title);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => JournalDetailPage(journal: journal),
          ),
        );
      }
    }
  }

  // ============================================================
  // build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScrapbookColors.cream,
      body: Column(
        children: [
          // 自定义顶部导航栏 (使用 Stack 确保标题绝对居中，且不因左右按钮宽度产生偏移或挤压)
          Container(
            height: 56,
            margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 8,
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_rounded,
                      color: Color(0xFF4A4238),
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const Text(
                  '手账海报',
                  style: TextStyle(
                    color: Color(0xFF4A4238),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // 标题编辑区
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFDF7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE0D8CC),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _titleController,
                    textAlign: TextAlign.center,
                    maxLength: 16,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF4A4238),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                    decoration: InputDecoration(
                      hintText: '点击自定义标题...',
                      hintStyle: TextStyle(
                        color: Colors.black.withOpacity(0.3),
                        fontStyle: FontStyle.italic,
                      ),
                      border: InputBorder.none,
                      counterText: '', // 隐藏默认 "0/16" 计数器
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _titleController.text.length >= 16
                      ? '⚠ 已达到标题上限 16 字'
                      : '✎ 点击上方可自定义标题（${_titleController.text.length}/16）',
                  style: TextStyle(
                    fontSize: 10,
                    color: _titleController.text.length >= 16
                        ? const Color(0xFFC75D56)
                        : Colors.black.withValues(alpha: 0.25),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // 感受编辑区
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFDF7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE0D8CC),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _feelingController,
                    maxLines: 3,
                    minLines: 1,
                    maxLength: 40,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B6560),
                      height: 1.6,
                    ),
                    decoration: InputDecoration(
                      hintText: '写下此刻的感受...',
                      hintStyle: TextStyle(
                        color: Colors.black.withOpacity(0.25),
                        fontStyle: FontStyle.italic,
                      ),
                      border: InputBorder.none,
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                if (_feelingController.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _feelingController.text.length >= 40
                          ? '⚠ 已达到感受上限 40 字'
                          : '${_feelingController.text.length}/40',
                      style: TextStyle(
                        fontSize: 10,
                        color: _feelingController.text.length >= 40
                            ? const Color(0xFFC75D56)
                            : Colors.black.withOpacity(0.25),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 海报预览区
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: RepaintBoundary(
                key: _repaintKey,
                child: Center(child: _buildPosterContent()),
              ),
            ),
          ),

          // 底部按钮区
          _buildBottomActions(),
        ],
      ),
    );
  }

  // ============================================================
  // 海报内容
  // ============================================================

  /// 海报内容 — 手账风长图
  Widget _buildPosterContent() {
    final photos = widget.photos;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      width: screenWidth - 40, // 提供明确宽度，解决长图内 Text 消失问题
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        // 奶咖渐变背景
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFDF7), Color(0xFFF8F2E6)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5DFD3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── 顶部装饰 ──
          _buildTopDecoration(),

          const SizedBox(height: 20),

          // ── 标题 ──
          Text(
            _titleController.text.isEmpty
                ? 'COZYCLEAN 治愈记忆瞬间'
                : _titleController.text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF4A4238),
              letterSpacing: 3,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),

          // ── 日期 ──
          Text(
            DateFormat('yyyy.MM.dd').format(DateTime.now()),
            style: TextStyle(
              fontSize: 11,
              color: Colors.black.withOpacity(0.35),
              letterSpacing: 2,
            ),
          ),

          // ── 感受文字 ──
          if (_feelingController.text.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFE5DFD3).withOpacity(0.6),
                ),
              ),
              child: Text(
                _feelingController.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: const Color(0xFF4A4238).withOpacity(0.7),
                  height: 1.8,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // ── 分割线装饰 ──
          Row(
            children: [
              Expanded(
                child: Container(height: 0.5, color: const Color(0xFFE0D8CC)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '✦',
                  style: TextStyle(fontSize: 10, color: Color(0xFFD4AF37)),
                ),
              ),
              Expanded(
                child: Container(height: 0.5, color: const Color(0xFFE0D8CC)),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── 记忆碎片整理数据 ──
          _buildMemoryStats(photos.length),

          const SizedBox(height: 20),

          // ── 照片硬编码独立渲染 ──
          _buildPhotoLayout(photos),

          const SizedBox(height: 24),

          // ── 底部水印 ──
          _buildWatermark(),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// 顶部装饰
  Widget _buildTopDecoration() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 24,
          height: 2,
          decoration: BoxDecoration(
            color: ScrapbookColors.brown,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          '◇',
          style: TextStyle(fontSize: 8, color: ScrapbookColors.brown),
        ),
        const SizedBox(width: 8),
        Container(
          width: 24,
          height: 2,
          decoration: BoxDecoration(
            color: ScrapbookColors.brown,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    );
  }

  /// 碎片整理统计条框
  Widget _buildMemoryStats(int count) {
    // 模拟占位：张数 * 4.5 MB
    final savedMB = (count * 4.5).toStringAsFixed(1);
    return Container(
      // 减小内边距，从 20 降至 12，防止窄屏溢出
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ScrapbookColors.brown.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 14, // 略微缩小图标
            color: ScrapbookColors.brown.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 6),
          Text(
            '珍藏 $count 张', // 精简文字
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: ScrapbookColors.brown.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 1,
            height: 10,
            color: ScrapbookColors.brown.withValues(alpha: 0.3),
          ),
          const SizedBox(width: 8),
          Text(
            '释放 $savedMB MB', // 精简文字
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: ScrapbookColors.greenAccent,
            ),
          ),
        ],
      ),
    );
  }

  /// 根路由方法：根据照片长度，下发给 1-6 任何一套纯静态的高级布局
  Widget _buildPhotoLayout(List<AssetEntity> photos) {
    if (photos.isEmpty) return const SizedBox.shrink();

    // 我们强制限制最高6张，以匹配6套设计
    final safePhotos = photos.take(6).toList();

    // 固定提供一个足够绘图的宽高画布 (按比例即可，宽 320, 高视具体情况)
    return Container(
      width: double.infinity,
      height: _getCanvasHeight(safePhotos.length),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // 通用背景修饰（光晕散落）
          const Positioned(
            top: 20,
            left: 10,
            child: DecorativeBlur(
              color: ScrapbookColors.greenAccent,
              size: 150,
            ),
          ),
          const Positioned(
            bottom: 20,
            right: 10,
            child: DecorativeBlur(color: Color(0xFFE8D5C4), size: 180),
          ),

          ..._buildPreciseLayout(safePhotos),
        ],
      ),
    );
  }

  double _getCanvasHeight(int count) {
    switch (count) {
      case 1:
        return 380;
      case 2:
        return 540;
      case 3:
        return 600;
      case 4:
        return 480;
      case 5:
        return 540;
      case 6:
        return 520;
      default:
        return 380;
    }
  }

  List<Widget> _buildPreciseLayout(List<AssetEntity> photos) {
    switch (photos.length) {
      case 1:
        return _layout1(photos);
      case 2:
        return _layout2(photos);
      case 3:
        return _layout3(photos);
      case 4:
        return _layout4(photos);
      case 5:
        return _layout5(photos);
      case 6:
        return _layout6(photos);
      default:
        return [];
    }
  }

  Widget _buildRawPhoto(AssetEntity photo, double width, double height) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: AssetEntityImage(
        photo,
        isOriginal: false,
        thumbnailSize: const ThumbnailSize(400, 400), // 降低尺寸，减少渲染海报长图时的总显存开销
        fit: BoxFit.cover,
        width: width,
        height: height,
        errorBuilder: (_, __, ___) => Container(
          width: width,
          height: height,
          color: const Color(0xFFF0EBE2),
          child: const Icon(Icons.photo_rounded, color: Colors.black26),
        ),
      ),
    );
  }

  Widget _buildDecoratedCard({
    required Widget child,
    required double angle,
    double tapeAngle = 0,
    Color tapeColor = const Color(0xFFF9E4B7),
  }) {
    return Transform.rotate(
      angle: angle,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          PolaroidCard(child: child),
          Positioned(
            top: -10,
            child: WashiTape(color: tapeColor, angle: tapeAngle),
          ),
        ],
      ),
    );
  }

  // --- 布局 1 ---
  List<Widget> _layout1(List<AssetEntity> p) {
    return [
      Positioned(
        top: 20,
        child: _buildDecoratedCard(
          child: _buildRawPhoto(p[0], 220, 220),
          angle: -0.05,
          tapeAngle: -0.1,
          tapeColor: const Color(0xFFE5D5C8),
        ),
      ),
    ];
  }

  // --- 布局 2 ---
  List<Widget> _layout2(List<AssetEntity> p) {
    return [
      Positioned(
        top: 20,
        left: 20,
        child: _buildDecoratedCard(
          child: _buildRawPhoto(p[0], 220, 260), // aspect-[4/5] approximate
          angle: -0.05, // -3deg is ~-0.05 rad
          tapeAngle: 0.03, // 2deg
          tapeColor: const Color(
            0xFFFFF59D,
          ).withValues(alpha: 0.6), // yellow-200/60
        ),
      ),
      Positioned(
        top: 240,
        right: 20,
        child: _buildDecoratedCard(
          child: _buildRawPhoto(p[1], 220, 260),
          angle: 0.07, // 4deg
          tapeAngle: -0.02, // -1deg
          tapeColor: const Color(
            0xFF90CAF9,
          ).withValues(alpha: 0.5), // blue-200/50
        ),
      ),
    ];
  }

  // --- 布局 3 ---
  List<Widget> _layout3(List<AssetEntity> p) {
    return [
      Positioned(
        top: 20,
        left: 20,
        child: _buildDecoratedCard(
          child: _buildRawPhoto(p[0], 170, 210),
          angle: -0.05, // -3 deg
          tapeAngle: 0.03, // 2 deg
          tapeColor: const Color(0xFFFFF59D).withValues(alpha: 0.6), // yellow
        ),
      ),
      Positioned(
        top: 190,
        right: 15,
        child: _buildDecoratedCard(
          child: _buildRawPhoto(p[1], 130, 170),
          angle: 0.07, // 4 deg
          tapeAngle: -0.017, // -1 deg
          tapeColor: const Color(0xFF90CAF9).withValues(alpha: 0.5), // blue
        ),
      ),
      Positioned(
        top: 360,
        left: 25,
        child: _buildDecoratedCard(
          child: _buildRawPhoto(p[2], 190, 150), // aspect-[4/3]
          angle: -0.017, // -1 deg
          tapeAngle: -0.017, // -1 deg
          tapeColor: const Color(0xFFFFF59D).withValues(alpha: 0.5), // yellow
        ),
      ),
    ];
  }

  // --- 布局 4 ---
  List<Widget> _layout4(List<AssetEntity> p) {
    return [
      Positioned(
        top: 20,
        left: 10,
        child: _buildDecoratedCard(
          child: _buildRawPhoto(p[0], 110, 140), // aspect-[4/5]
          angle: -0.05, // -3 deg
          tapeAngle: -0.08, // -5 deg
          tapeColor: const Color(0xFFC5E1A5).withValues(alpha: 0.6), // green
        ),
      ),
      Positioned(
        top: 35,
        right: 10,
        child: _buildDecoratedCard(
          child: _buildRawPhoto(p[1], 110, 140),
          angle: 0.03, // 2 deg
          tapeAngle: 0.08, // 5 deg
          tapeColor: const Color(0xFFF48FB1).withValues(alpha: 0.5), // pink
        ),
      ),
      Positioned(
        top: 180,
        left: 10,
        child: _buildDecoratedCard(
          child: _buildRawPhoto(p[2], 110, 140),
          angle: 0.07, // 4 deg
          tapeAngle: 0.03, // 2 deg
          tapeColor: const Color(0xFF81D4FA).withValues(alpha: 0.5), // blue
        ),
      ),
      Positioned(
        top: 195,
        right: 10,
        child: _buildDecoratedCard(
          child: _buildRawPhoto(p[3], 110, 140),
          angle: -0.03, // -2 deg
          tapeAngle: -0.05, // -3 deg
          tapeColor: const Color(0xFFFFF59D).withValues(alpha: 0.6), // yellow
        ),
      ),
    ];
  }

  // --- 布局 5 ---
  List<Widget> _layout5(List<AssetEntity> p) {
    return [
      Positioned(
        top: 15, // down slightly
        left: 15, // right slightly
        child: _buildDecoratedCard(
          child: _buildRawPhoto(p[0], 100, 100), // reduced from 110
          angle: -0.05, // -3 deg
          tapeAngle: -0.03, // -2 deg
          tapeColor:
              const Color(0xFFF8C8DC).withValues(alpha: 0.8), // tape-pink
        ),
      ),
      Positioned(
        top: 25,
        right: 15,
        child: _buildDecoratedCard(
          child: _buildRawPhoto(p[1], 115, 85), // reduced scale
          angle: 0.07, // 4 deg
          tapeAngle: 0.03, // 2 deg
          tapeColor:
              const Color(0xFFAEC6CF).withValues(alpha: 0.8), // tape-blue
        ),
      ),
      Positioned(
        top: 160,
        left: 45,
        child: _buildDecoratedCard(
          child: _buildRawPhoto(p[2], 135, 100), // reduced scale
          angle: -0.017, // -1 deg
          tapeAngle: -0.017, // -1 deg
          tapeColor: const Color(0xFFFFF59D).withValues(alpha: 0.6), // yellow
        ),
      ),
      Positioned(
        top: 320,
        left: 20,
        child: _buildDecoratedCard(
          child: _buildRawPhoto(p[3], 90, 90), // reduced from 100
          angle: 0.1, // 6 deg
        ),
      ),
      Positioned(
        top: 310,
        right: 15,
        child: _buildDecoratedCard(
          child: _buildRawPhoto(p[4], 110, 110), // reduced from 120
          angle: -0.08, // -5 deg
          tapeAngle: 0.05, // 3 deg
          tapeColor: const Color(0xFFAEC6CF).withValues(alpha: 0.8), // blue
        ),
      ),
    ];
  }

  // --- 布局 6 ---
  List<Widget> _layout6(List<AssetEntity> p) {
    return [
      Positioned(
        top: 10,
        left: 10,
        child: _buildDecoratedCard(
          child: _buildRawPhoto(p[0], 95, 95),
          angle: -0.05, // -3 deg
          tapeAngle: 0.03, // 2 deg (tape-pattern-3)
          tapeColor: const Color(
            0xFFC1E1C1,
          ).withValues(alpha: 0.9), // tape-green
        ),
      ),
      Positioned(
        top: 25,
        right: 15,
        child: _buildDecoratedCard(
          child: _buildRawPhoto(p[1], 105, 80),
          angle: 0.07, // 4 deg
        ),
      ),
      Positioned(
        top: 135,
        left: 35,
        child: _buildDecoratedCard(
          child: _buildRawPhoto(p[2], 120, 160), // aspect-[3/4] approx
          angle: 0.03, // 2 deg
          tapeAngle: -0.07, // -4 deg
          tapeColor: const Color(
            0xFFF4E06D,
          ).withValues(alpha: 0.7), // tape-yellow
        ),
      ),
      Positioned(
        top: 160,
        right: 25,
        child: _buildDecoratedCard(
          child: _buildRawPhoto(p[3], 85, 85),
          angle: -0.08, // -5 deg
        ),
      ),
      Positioned(
        top: 340,
        left: 20,
        child: _buildDecoratedCard(
          child: _buildRawPhoto(p[4], 90, 90),
          angle: -0.03, // -2 deg
          tapeAngle: 0.05, // 3 deg
          tapeColor: const Color(
            0xFFAEC6CF,
          ).withValues(alpha: 0.8), // tape-blue
        ),
      ),
      Positioned(
        top: 330,
        right: 15,
        child: _buildDecoratedCard(
          child: _buildRawPhoto(p[5], 115, 85), // aspect-[4/3] approx
          angle: 0.05, // 3 deg
          tapeAngle: -0.017, // -1 deg
          tapeColor: const Color(
            0xFFF8C8DC,
          ).withValues(alpha: 0.8), // tape-pink
        ),
      ),
    ];
  }

  /// 底部水印
  Widget _buildWatermark() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 30, height: 0.5, color: const Color(0xFFE5DFD3)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'CozyClean · 治愈记忆',
            style: TextStyle(
              fontSize: 10,
              color: Color(0xFFBDB5A6),
              letterSpacing: 2,
            ),
          ),
        ),
        Container(width: 30, height: 0.5, color: const Color(0xFFE5DFD3)),
      ],
    );
  }

  // ============================================================
  // 底部按钮
  // ============================================================

  /// 底部操作栏 (参照第四个手帐原型布局，上下分为两排)
  Widget _buildBottomActions() {
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
            color: ScrapbookColors.brown.withValues(alpha: 0.05), // border-t
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 第一排：取消、分享 (使用与详情页相同的方块样式)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.close_rounded,
                    label: '取消编辑',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.share_rounded,
                    label: '直接分享',
                    onPressed: _isGenerating ? null : _shareAndNavigate,
                  ),
                ),
                // 留白保持三分排版对称，也可以放点其他占位
                const Spacer(),
              ],
            ),
          ),

          // 第二排：保存海报并查看
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isGenerating ? null : _saveAndNavigate,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: _isGenerating ? Colors.grey : ScrapbookColors.brown,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      if (!_isGenerating)
                        BoxShadow(
                          color: ScrapbookColors.brown.withValues(alpha: 0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isGenerating)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      else
                        const Icon(Icons.save_alt_rounded,
                            size: 16, color: ScrapbookColors.cream),
                      const SizedBox(width: 8),
                      Text(
                        _isGenerating ? '正在拼贴照片并排版...' : '拼贴完成，生成手账海报',
                        style: const TextStyle(
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
  }) {
    final isDisabled = onPressed == null;
    final bColor = ScrapbookColors.brown.withOpacity(0.1);
    final finalTextColor = isDisabled ? Colors.grey : ScrapbookColors.brown;

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: bColor, width: 1),
      ),
      elevation: 0.5,
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
