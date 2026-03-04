# CozyClean 架构对齐与报错修复规范 (Phase 2 Spec)

## 1. 核心问题概述 (The Problem)
目前通过排查代码库结构，发现导致运行时红屏报错和类型不匹配的根本原因是**架构冗余与历史遗留文件冲突**。在引入 `Feature-First` (按功能模块拆分) 架构后，旧的全局 `lib/presentation/` 目录未能及时清理。

这意味着运行时 Flutter 同时加载了两个同名的类但位于不同路径：
- `lib/presentation/controllers/blitz_controller.dart`
- `lib/features/blitz/application/controllers/blitz_controller.dart`

这种“双胞胎”现象导致当我们尝试从 `main.dart` 访问路由或者在使用 Riverpod 监听状态时，抛出 `Type 'A' is not a subtype of type 'A'` 的红屏崩溃报错。

## 2. 核心修复点 (The Solution)

本次迁移将严格遵守 `.antigravity/flutter_rules.md` 与全局架构规范，彻底执行 **Feature-First** 目录重组。

### 2.1 目录清查与迁移名单

**【删除】冗余的历史文件 (保留 Feature 目录下最新的实现)**：
- `lib/presentation/controllers/blitz_controller.dart` -> **删除**
- `lib/presentation/controllers/blitz_state.dart` -> **删除**
- `lib/presentation/pages/blitz_page.dart` -> **删除**

**【迁移】尚未特征化的页面与逻辑，移动到对应的 Feature 目录下**：
- `lib/presentation/pages/dashboard_page.dart` -> 移至 `lib/features/dashboard/presentation/pages/dashboard_page.dart`
- `lib/presentation/pages/profile_page.dart` -> 移至 `lib/features/profile/presentation/pages/profile_page.dart`
- `lib/presentation/pages/summary_page.dart` -> 移至 `lib/features/blitz/presentation/pages/summary_page.dart` (属于闪电战流程的一环)
- `lib/presentation/controllers/user_stats_controller.dart` -> 移至 `lib/features/profile/application/controllers/user_stats_controller.dart` (管理用户体力与 Pro 状态，暂时归属于 Profile 特征或 Core)
- `lib/presentation/widgets/photo_card.dart` -> 移至 `lib/features/blitz/presentation/widgets/photo_card.dart`

**最终目标：彻底清空并删除 `lib/presentation/` 文件夹。**

### 2.2 全局导入路径修正 (Import Paths)
所有 Dart 文件中涉及迁移文件的导入路径，必须统一修改为绝对包路径（Package Import），以防止相对路径 (`../`) 再次引发类似的作用域问题。
示例：
- ❌ `import '../controllers/blitz_controller.dart';`
- ✅ `import 'package:cozy_clean/features/blitz/application/controllers/blitz_controller.dart';`

### 2.3 环境清理 (Environment Cleanup)
由于移动和删除了大规模的关联文件，Dart 的增量编译器会残留旧的缓存。迁移完成后，执行完整的环境清理以防万一：
1. `flutter clean`
2. `flutter pub get`
3. 重启运行。

## 3. 测试与验证计划 (Verification Plan)
1. **静态分析**：迁移后立刻执行 `flutter analyze`，确保不存在由于路径错误而导致的“文件找不到”或“未定义的方法”报错。
2. **启动测试**：重新运行 `flutter run`，验证应用可以正常进入并显示。不黑屏，控制台不报关于 `Controller` 找不到的错误。
3. **功能连通性测试**：
   - Dashboard -> Blitz (闪电战)
   - Dashboard -> Profile (我的)
   - 闪电战滑动结束 -> Summary (结算页)
   确保以上页面跳转和状态管理不出现红屏或 Provider 找不到的异常。

## 4. 行动许可 (User Review Required)
> [!IMPORTANT]
> 这是重大的目录结构调整，它将彻底铲除导致一直报错的毒瘤，但也伴随着批量调整导包路径。
> 若同意以此规范立刻开工作业，我们即可进入 **Phase 4 (执行)** 开始移动和删除文件，并在几分钟内完成修复！
