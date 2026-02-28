/// CozyClean — 手账海报生成页
///
/// 展示用户收藏的照片（最多 6 张），以拍立得贴纸风格排列在
/// 手账风长图上，用户可以编辑标题、生成海报图片并分享。
///
/// 功能：
///   1. 拍立得风格照片排列
///   2. 可编辑标题
///   3. Widget→Image 渲染生成海报
///   4. 分享（系统 Share Sheet）
///   5. 保存到手账历史（Journals 表）
library;

import 'dart:io';
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
  bool _isGenerating = false;
  String? _generatedPath;

  @override
  void initState() {
    super.initState();
    _titleController.text =
        '${DateFormat('yyyy.MM.dd').format(DateTime.now())} 的美好瞬间';
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  // ============================================================
  // 海报渲染与保存
  // ============================================================

  /// 将海报 Widget 渲染为图片并保存到本地
  Future<String?> _generatePoster() async {
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
      await repo.saveJournal(
        title: _titleController.text,
        photoAssetIds: widget.photos.map((p) => p.id).toList(),
        posterFilePath: file.path,
      );

      setState(() {
        _generatedPath = file.path;
        _isGenerating = false;
      });

      return file.path;
    } catch (e) {
      setState(() => _isGenerating = false);
      debugPrint('[PosterPage] 海报生成失败: $e');
      return null;
    }
  }

  /// 分享海报
  Future<void> _sharePoster(String path) async {
    await Share.shareXFiles(
      [XFile(path)],
      text: _titleController.text,
    );
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
            child: TextField(
              controller: _titleController,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF4A4238),
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
              decoration: InputDecoration(
                hintText: '写下这一天的标题...',
                hintStyle: TextStyle(
                  color: Colors.black.withValues(alpha: 0.3),
                  fontStyle: FontStyle.italic,
                ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
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

  /// 海报内容 — 手账风长图
  Widget _buildPosterContent() {
    final photos = widget.photos;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF7),
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
          // 顶部装饰线
          Container(
            width: 40,
            height: 3,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 标题
          Text(
            _titleController.text.isEmpty ? '美好瞬间' : _titleController.text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4A4238),
              letterSpacing: 2,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),

          // 日期
          Text(
            DateFormat('yyyy 年 MM 月 dd 日').format(DateTime.now()),
            style: TextStyle(
              fontSize: 12,
              color: Colors.black.withValues(alpha: 0.4),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 24),

          // 照片排列区
          _buildPhotoGrid(photos),

          const SizedBox(height: 24),

          // 底部水印
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 30,
                height: 1,
                color: const Color(0xFFE5DFD3),
              ),
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
              Container(
                width: 30,
                height: 1,
                color: const Color(0xFFE5DFD3),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// 拍立得风格照片网格
  ///
  /// 根据照片数量自适应布局：
  ///   1 张: 居中大图
  ///   2 张: 并排
  ///   3 张: 2+1 交错
  ///   4 张: 2x2 网格
  ///   5-6 张: 2x3 网格
  Widget _buildPhotoGrid(List<AssetEntity> photos) {
    if (photos.isEmpty) return const SizedBox.shrink();

    if (photos.length == 1) {
      return Center(child: _buildPolaroid(photos[0], angle: -0.03));
    }

    // 2-6 张使用 Wrap 布局
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 16,
      children: List.generate(photos.length, (index) {
        // 交替旋转角度
        final angles = [-0.04, 0.03, -0.02, 0.04, -0.03, 0.02];
        final angle = angles[index % angles.length];
        return _buildPolaroid(photos[index], angle: angle);
      }),
    );
  }

  /// 单张拍立得风格照片
  Widget _buildPolaroid(AssetEntity photo, {double angle = 0.0}) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 130,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(3, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // 照片区域（带边距）
            Padding(
              padding:
                  const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 4),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(1),
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
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

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
          // 生成按钮
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isGenerating
                  ? null
                  : () async {
                      HapticFeedback.mediumImpact();
                      final path = await _generatePoster();
                      if (path != null && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('海报已保存 ✨',
                                textAlign: TextAlign.center),
                            backgroundColor: const Color(0xFF8BA888),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      }
                    },
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
          // 分享按钮
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () async {
                HapticFeedback.lightImpact();
                if (_generatedPath != null) {
                  await _sharePoster(_generatedPath!);
                } else {
                  // 先生成再分享
                  final path = await _generatePoster();
                  if (path != null) {
                    await _sharePoster(path);
                  }
                }
              },
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
