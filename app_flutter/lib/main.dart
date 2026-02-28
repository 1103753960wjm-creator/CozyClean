import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 引入我们的核心首页与闪电战
import 'presentation/pages/dashboard_page.dart';
import 'core/providers/shared_prefs_provider.dart';

Future<void> main() async {
  // 必须在此调用，以确保 runApp 之前的异步服务（如 SharedPreferences）正常执行
  WidgetsFlutterBinding.ensureInitialized();

  // 同步拿取本地存储实例
  final prefs = await SharedPreferences.getInstance();

  // runApp 是 Flutter 程序的绝对起点
  runApp(
    // ProviderScope 是 Riverpod 状态管理的根基，必须包裹在最外层
    ProviderScope(
      overrides: [
        // 注入已经加载好的 SharedPrefs，方便整个 App 同步读取
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const CozyCleanApp(),
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
        scaffoldBackgroundColor:
            const Color(0xFFFAF9F6), // 符合 Dashboard 原型的手账底色
        useMaterial3: true,
      ),
      // 将 App 的启动首页平滑过渡到手账风的主仪表盘 (Dashboard)
      home: const DashboardPage(),
    );
  }
}
