/// CozyClean — 手账详情页
///
/// 全屏展示手账海报长图，支持双指缩放和拖拽平移。
/// 顶部 AppBar 显示标题和创建时间，底部提供分享和删除操作。
///
/// 架构位置：features/journal/presentation/pages/
///   UI 层仅负责展示和调用 Controller 方法，
///   不直接访问数据库或文件系统。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:cozy_clean/data/local/app_database.dart';
import 'package:cozy_clean/features/journal/application/controllers/journal_controller.dart';

/// 手账详情页 — 全屏查看长图
///
/// 使用 [InteractiveViewer] 支持缩放查看，
/// 底部按钮提供分享和删除功能。
class JournalDetailPage extends ConsumerWidget {
  /// 手账记录
  final Journal journal;

  const JournalDetailPage({super.key, required this.journal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = File(journal.posterPath);
    final dateStr = DateFormat('yyyy年MM月dd日 HH:mm').format(journal.createdAt);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F0E8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Color(0xFF4A4238)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            Text(
              journal.title,
              style: const TextStyle(
                color: Color(0xFF4A4238),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              dateStr,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.4),
                fontSize: 11,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          // 分享按钮
          IconButton(
            icon: const Icon(Icons.share_rounded,
                color: Color(0xFF6B6560), size: 22),
            onPressed: () => _sharePoster(context, file),
          ),
        ],
      ),
      body: Column(
        children: [
          // 长图展示区 — 支持缩放
          Expanded(
            child: file.existsSync()
                ? InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            file,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  )
                : _buildImageNotFound(),
          ),

          // 底部操作区
          _buildBottomBar(context, ref),
        ],
      ),
    );
  }

  /// 图片不存在时的占位 UI
  Widget _buildImageNotFound() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_rounded, size: 64, color: Color(0xFFD4CBBB)),
          SizedBox(height: 12),
          Text(
            '海报图片已被移除',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF9E9689),
            ),
          ),
        ],
      ),
    );
  }

  /// 底部操作栏
  Widget _buildBottomBar(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF9F6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // 删除按钮
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _confirmDelete(context, ref),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('删除'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFC75D56),
                  side: const BorderSide(color: Color(0xFFE0D8CC)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 返回主页按钮
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                icon: const Icon(Icons.home_rounded, size: 18),
                label: const Text('主页'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8BA888),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 分享按钮
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () =>
                    _sharePoster(context, File(journal.posterPath)),
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text('分享'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8A6549),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 分享海报
  Future<void> _sharePoster(BuildContext context, File file) async {
    if (!file.existsSync()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('海报图片不存在')),
        );
      }
      return;
    }
    await Share.shareXFiles(
      [XFile(file.path)],
      text: journal.title,
    );
  }

  /// 确认删除弹窗
  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除手账'),
        content: const Text('确定要删除这篇手账吗？删除后无法恢复。'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消', style: TextStyle(color: Color(0xFF9E9689))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await ref
                  .read(journalControllerProvider.notifier)
                  .deleteJournal(journal.id);
              if (success && context.mounted) {
                Navigator.of(context).pop(); // 返回列表页
              }
            },
            child: const Text('删除', style: TextStyle(color: Color(0xFFC75D56))),
          ),
        ],
      ),
    );
  }
}
