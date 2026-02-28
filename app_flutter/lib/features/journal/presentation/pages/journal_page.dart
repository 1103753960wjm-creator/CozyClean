/// CozyClean — 手账列表页
///
/// 展示用户历史生成的手账长图海报，按年月分组显示。
///
/// 当前版本：空状态占位页
///   后续 Feature 4 将实现完整功能：
///   - 从 Journals 数据库表读取手账记录
///   - 按年月分组 + 标题缩略图展示
///   - 点击查看长图详情
///
/// 架构位置：features/journal/presentation/pages/
///   UI 层仅负责展示，不直接访问数据库或执行业务逻辑。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 手账列表页 — 展示用户历史手账
///
/// 使用 [ConsumerWidget] 为后续接入 Riverpod 数据流做准备。
/// 当前为空状态占位，待 Feature 4 实现完整功能。
class JournalPage extends ConsumerWidget {
  const JournalPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 手账 Emoji 图标
            const Text(
              '📖',
              style: TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 16),
            // 标题
            const Text(
              '我的手账',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A4238),
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            // 引导文案
            Text(
              '整理照片时收藏喜欢的瞬间\n即可生成专属回忆手账',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: const Color(0xFF4A4238).withOpacity(0.5),
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
