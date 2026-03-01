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

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:cozy_clean/features/blitz/data/providers/blitz_data_providers.dart';
import 'package:cozy_clean/features/journal/data/repositories/journal_repository.dart';
import 'package:cozy_clean/features/journal/presentation/pages/journal_detail_page.dart';
import 'package:cozy_clean/data/local/app_database.dart';

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

  /// 每张照片的随机偏移量和旋转角度（initState 时固定）
  late final List<_PhotoPlacement> _placements;

  @override
  void initState() {
    super.initState();
    _titleController.text = 'COZYCLEAN 治愈记忆瞬间';
    // 输入时实时刷新海报预览和字数提示
    _titleController.addListener(() => setState(() {}));
    _feelingController.addListener(() => setState(() {}));
    // 预生成随机布局参数（固定种子避免每次 rebuild 变化）
    _placements = _generatePlacements(widget.photos.length);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _feelingController.dispose();
    super.dispose();
  }

  /// 生成每张照片的随机偏移和旋转参数
  List<_PhotoPlacement> _generatePlacements(int count) {
    final rng = Random(42); // 固定种子
    return List.generate(count, (i) {
      return _PhotoPlacement(
        angle: (rng.nextDouble() - 0.5) * 0.12, // -0.06 ~ 0.06 rad
        offsetX: (rng.nextDouble() - 0.5) * 12, // -6 ~ 6 px
        offsetY: rng.nextDouble() * 6, // 0 ~ 6 px
      );
    });
  }

  // ============================================================
  // 海报渲染与保存
  // ============================================================

  /// 将海报 Widget 渲染为图片，保存到文件和数据库
  ///
  /// 返回保存的 [Journal] 记录，用于跳转详情页。
  Future<Journal?> _generateAndSave() async {
    try {
      setState(() => _isGenerating = true);

      // 1. 捕获 RepaintBoundary
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
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
      final repo = JournalRepository(db);
      final id = await repo.saveJournal(
        title: _titleController.text,
        photoAssetIds: widget.photos.map((p) => p.id).toList(),
        posterFilePath: file.path,
        feeling: _feelingController.text,
      );

      // 4. 查询刚保存的记录
      final journal = await repo.getJournalById(id);

      setState(() => _isGenerating = false);
      return journal;
    } catch (e) {
      setState(() => _isGenerating = false);
      debugPrint('[PosterPage] 海报生成失败: $e');
      return null;
    }
  }

  /// 保存海报并跳转详情页
  Future<void> _saveAndNavigate() async {
    HapticFeedback.mediumImpact();
    final journal = await _generateAndSave();
    if (journal != null && mounted) {
      // 替换当前页为详情页（避免按 back 回到编辑页）
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => JournalDetailPage(journal: journal),
        ),
      );
    }
  }

  /// 分享海报（先生成再分享，分享后跳转详情页）
  Future<void> _shareAndNavigate() async {
    HapticFeedback.lightImpact();
    final journal = await _generateAndSave();
    if (journal != null && mounted) {
      await Share.shareXFiles(
        [XFile(journal.posterPath)],
        text: journal.title,
      );
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
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Color(0xFF4A4238)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '手账海报',
          style: TextStyle(
            color: Color(0xFF4A4238),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
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
                        color: Colors.black.withValues(alpha: 0.3),
                        fontStyle: FontStyle.italic,
                      ),
                      border: InputBorder.none,
                      counterText: '', // 隐藏默认 "0/16" 计数器
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
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
                        color: Colors.black.withValues(alpha: 0.25),
                        fontStyle: FontStyle.italic,
                      ),
                      border: InputBorder.none,
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
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
                            : Colors.black.withValues(alpha: 0.25),
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
                child: _buildPosterContent(),
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        // 奶咖渐变背景
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFFDF7),
            Color(0xFFF8F2E6),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5DFD3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
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
              color: Colors.black.withValues(alpha: 0.35),
              letterSpacing: 2,
            ),
          ),

          // ── 感受文字 ──
          if (_feelingController.text.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFE5DFD3).withValues(alpha: 0.6),
                ),
              ),
              child: Text(
                _feelingController.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: const Color(0xFF4A4238).withValues(alpha: 0.7),
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
                child: Text('✦',
                    style: TextStyle(fontSize: 10, color: Color(0xFFD4AF37))),
              ),
              Expanded(
                child: Container(height: 0.5, color: const Color(0xFFE0D8CC)),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── 照片双列交错排列 ──
          _buildDualColumnPhotos(photos),

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
            color: const Color(0xFFD4AF37),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          '◇',
          style: TextStyle(fontSize: 8, color: Color(0xFFD4AF37)),
        ),
        const SizedBox(width: 8),
        Container(
          width: 24,
          height: 2,
          decoration: BoxDecoration(
            color: const Color(0xFFD4AF37),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    );
  }

  /// 双列随机交错照片布局
  ///
  /// 照片分配到左右两列，交替填充。
  /// 每张照片使用预生成的 [_PhotoPlacement] 实现微旋转和偏移，
  /// 营造手贴效果。左右列宽度微调制造不对称感。
  Widget _buildDualColumnPhotos(List<AssetEntity> photos) {
    if (photos.isEmpty) return const SizedBox.shrink();

    // 单张直接居中大图
    if (photos.length == 1) {
      return Center(
        child: _buildPolaroid(photos[0], _placements[0], width: 180),
      );
    }

    // 分配到左右两列（交替）
    final List<int> leftIndices = [];
    final List<int> rightIndices = [];
    for (int i = 0; i < photos.length; i++) {
      if (i % 2 == 0) {
        leftIndices.add(i);
      } else {
        rightIndices.add(i);
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左列
        Expanded(
          child: Column(
            children: leftIndices.map((i) {
              return Padding(
                padding: EdgeInsets.only(bottom: 14, top: i == 0 ? 8 : 0),
                child: _buildPolaroid(photos[i], _placements[i]),
              );
            }).toList(),
          ),
        ),
        const SizedBox(width: 8),
        // 右列（起始偏移，营造交错感）
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 30),
            child: Column(
              children: rightIndices.map((i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _buildPolaroid(photos[i], _placements[i]),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  /// 单张拍立得风格照片
  ///
  /// 白色外框 + 底部留白 + 微旋转 + 阴影，
  /// 照片使用 [AssetEntityImage] 加载缩略图。
  Widget _buildPolaroid(AssetEntity photo, _PhotoPlacement placement,
      {double? width}) {
    return Transform.translate(
      offset: Offset(placement.offsetX, placement.offsetY),
      child: Transform.rotate(
        angle: placement.angle,
        child: Container(
          width: width,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(2, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            children: [
              // 照片区域
              Padding(
                padding:
                    const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 4),
                child: AspectRatio(
                  aspectRatio: 0.85,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: AssetEntityImage(
                      photo,
                      isOriginal: false,
                      thumbnailSize: const ThumbnailSize(600, 600),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFF0EBE2),
                        child: const Icon(Icons.photo_rounded,
                            color: Colors.black26, size: 32),
                      ),
                    ),
                  ),
                ),
              ),
              // 底部留白（拍立得特征）
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
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

  /// 底部操作按钮
  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF7),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 保存按钮 → 保存后跳转详情页
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isGenerating ? null : _saveAndNavigate,
              icon: _isGenerating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.save_alt_rounded, size: 18),
              label: Text(_isGenerating ? '生成中...' : '保存海报'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8BA888),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 分享按钮 → 分享后跳转详情页
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isGenerating ? null : _shareAndNavigate,
              icon: const Icon(Icons.share_rounded, size: 18),
              label: const Text('分享'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 照片摆放参数 — 旋转角度和偏移量
///
/// 在 initState 时预生成，避免每次 rebuild 随机值变化。
class _PhotoPlacement {
  final double angle;
  final double offsetX;
  final double offsetY;

  const _PhotoPlacement({
    required this.angle,
    required this.offsetX,
    required this.offsetY,
  });
}
