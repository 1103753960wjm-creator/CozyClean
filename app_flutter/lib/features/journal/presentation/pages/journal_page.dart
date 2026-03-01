/// CozyClean — 手账列表页
///
/// 展示用户历史生成的手账长图海报，按年月分组显示。
/// 支持点击查看详情（缩放长图）、删除操作。
///
/// 架构位置：features/journal/presentation/pages/
///   UI 层通过 Riverpod 订阅 JournalController 状态，
///   不直接访问数据库或执行业务逻辑。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:cozy_clean/features/journal/application/controllers/journal_controller.dart';
import 'package:cozy_clean/features/journal/presentation/pages/journal_detail_page.dart';
import 'package:cozy_clean/data/local/app_database.dart';

/// 手账列表页 — 展示用户历史手账
///
/// 使用 [ConsumerStatefulWidget] 在 initState 中加载数据，
/// 通过 ref.watch 订阅列表状态变化。
class JournalPage extends ConsumerStatefulWidget {
  const JournalPage({super.key});

  @override
  ConsumerState<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends ConsumerState<JournalPage> {
  @override
  void initState() {
    super.initState();
    // 首次进入时加载手账列表
    Future.microtask(() {
      ref.read(journalControllerProvider.notifier).loadJournals();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(journalControllerProvider);

    return SafeArea(
      child: Column(
        children: [
          // 顶部标题
          _buildHeader(),
          // 列表内容
          Expanded(
            child: state.isLoading
                ? _buildLoading()
                : state.isEmpty
                    ? _buildEmptyState()
                    : _buildJournalList(state),
          ),
        ],
      ),
    );
  }

  /// 顶部标题栏
  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Text(
            '📖 我的手账',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4A4238),
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// 加载中状态
  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(
        color: Color(0xFF8A6549),
        strokeWidth: 2,
      ),
    );
  }

  /// 空状态 — 引导用户创建手账
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📖', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text(
            '还没有手账',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4A4238),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '整理照片时收藏喜欢的瞬间\n即可生成专属回忆手账',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: const Color(0xFF4A4238).withValues(alpha: 0.5),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  /// 手账列表 — 按年月分组
  Widget _buildJournalList(journalState) {
    final grouped = journalState.groupedByMonth as Map<String, List<Journal>>;
    final months = grouped.keys.toList();

    return RefreshIndicator(
      color: const Color(0xFF8A6549),
      onRefresh: () =>
          ref.read(journalControllerProvider.notifier).loadJournals(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: months.length,
        itemBuilder: (context, sectionIndex) {
          final month = months[sectionIndex];
          final journals = grouped[month]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 月份标题
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Text(
                  month,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8A7D6D),
                    letterSpacing: 1,
                  ),
                ),
              ),
              // 该月的手账卡片
              ...journals.map((journal) => _buildJournalCard(journal)),
            ],
          );
        },
      ),
    );
  }

  /// 单个手账卡片
  ///
  /// 左侧海报缩略图，右侧标题+日期+感受预览。
  /// 点击进入详情页查看完整长图。
  Widget _buildJournalCard(Journal journal) {
    final file = File(journal.posterPath);
    final dateStr = DateFormat('MM/dd HH:mm').format(journal.createdAt);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openDetail(journal),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDF7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFE8E0D4),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // 左侧缩略图
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 60,
                    height: 80,
                    child: file.existsSync()
                        ? Image.file(
                            file,
                            fit: BoxFit.cover,
                            cacheWidth: 120,
                          )
                        : Container(
                            color: const Color(0xFFF0EBE2),
                            child: const Icon(
                              Icons.broken_image_rounded,
                              color: Color(0xFFD4CBBB),
                              size: 24,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                // 右侧信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        journal.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4A4238),
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black.withValues(alpha: 0.35),
                        ),
                      ),
                      if (journal.feeling != null &&
                          journal.feeling!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          journal.feeling!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black.withValues(alpha: 0.4),
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                // 右箭头
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFD4CBBB),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 打开手账详情页
  void _openDetail(Journal journal) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => JournalDetailPage(journal: journal),
      ),
    )
        .then((_) {
      // 从详情页返回后刷新列表（可能已删除）
      ref.read(journalControllerProvider.notifier).loadJournals();
    });
  }
}
