import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 引入我们刚刚写好的闪电战页面
import 'presentation/pages/blitz_page.dart';

void main() {
  // runApp 是 Flutter 程序的绝对起点
  runApp(
    // ProviderScope 是 Riverpod 状态管理的根基，必须包裹在最外层
    const ProviderScope(
      child: CozyCleanApp(),
    ),
  );
}

class CozyCleanApp extends StatelessWidget {
  const CozyCleanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CozyClean',
      debugShowCheckedModeBanner: false, // 隐藏右上角的 Debug 标签
      theme: ThemeData(
        // 植入 PRD 规定的核心色板
        primaryColor: const Color(0xFFF5F5DC),
        scaffoldBackgroundColor: const Color(0xFFF5F5DC), // 奶油底色
        useMaterial3: true,
      ),
      // 将 App 的启动首页强制指向闪电战页面
      home: const BlitzPage(),
    );
  }
}
