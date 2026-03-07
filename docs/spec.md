# CozyClean 相册清理秒开架构
# Blitz Prewarm System Spec (Production Version - Revised)

---

# 1. 目标 (Goals)
实现 **相册清理功能秒开（Instant Launch）**，达成 Google Photos 级体验。
- **0ms 进入页面**
- **无需等待扫描**
- **UI 与扫描完全解耦**

---

# 2. 架构原则 (Antigravity Strict Layering)
必须严格遵循单向依赖，禁止任何越级调用：
**UI → Controller → Repository → Datasource → PhotoManager**

### 2.1 修正：删除逻辑链路 (Deletion Fix)
目前的物理/回收站删除逻辑严禁在 `summary_page.dart` (UI) 直接调用 `PhotoManager`。
**正确路径**：
1. `summary_page` (UI) 调用 `blitzController.confirmDeletion()`。
2. `blitz_controller` 调用 `blitz_repository.trashPhotos()`。
3. `blitz_repository` 调用 `photo_datasource.trashPhotos()`。
4. `photo_datasource` 执行 `PhotoManager.editor.android.moveToTrash` 或 `deleteWithIds`。

---

# 3. 预热服务设计 (BlitzPrewarmService)
### 3.1 放置位置 (Core Service)
`PrewarmService` 必须放在 **`core/services/`**，它是跨 Feature 的全局生命周期服务。如果放在 `features/blitz`，会因为功能关闭而导致 Provider 被 Dispose。

### 3.2 内存安全缓存 (Memory Safety)
- **禁止缓存**：`AssetEntity` (Heavy Object), `Bitmap`, `Thumbnail`。
- **允许缓存**：`AssetLite` (DTO) 或 `String id`。
- **PhotoGroup 结构**：
  ```dart
  class PhotoGroupLite {
    final List<String> assetIds; // 仅存储 ID 字符串，避免内存爆炸
    final int bestIndex;
  }
  ```

---

# 4. 生命周期管理与监听
### 4.1 自动监听点 (Callback Registration)
- **位置**：`PrewarmService` 的 `init()` 方法中注册。
- **内容**：
  1. `AppLifecycleListener` (监听 resume/paused/inactive)。
  2. `PhotoManager.addChangeCallback` (监听相册变动)。
- **销毁**：在 `PrewarmService` 的 `dispose()` 中注销，严禁在 UI (HomePage) 注册。

### 4.2 状态刷新策略
- **onResume**: 必须强制标记 `isStale = true`，重新触发扫描（防抖 500ms）。原因：Android ROM 可能不发回调。
- **PhotoManager Callback**: 收到变化时 mark stale -> debounce scan。

---

# 5. Isolate 异构通信
### 5.1 AssetLite DTO
由于 `AssetEntity` 包含 MethodChannel，无法跨 Isolate 传递。
必须定义：
```dart
class AssetLite {
  final String id;
  final int timestamp;
}
```
### 5.2 流程
`DataSource` 获取全量 `AssetEntity` -> 提取 `AssetLite` 列表 -> 发送至 Isolate 执行 Burst Grouping -> 返回分组边界。

---

# 6. 状态定义 (PrewarmStatus)
```dart
enum PrewarmStatus {
  idle,       // 未扫描
  scanning,   // 扫描中
  ready,      // 数据可用且鲜活
  refreshing, // 数据可用但正在后台扫描更新 (stale)
}
```

---

# 7. 目录结构 (Clean Architecture)
```text
lib/
  core/
    services/
      blitz_prewarm_service.dart
    state/
      blitz_prewarm_state.dart
  features/
    blitz/
      application/
        controllers/blitz_controller.dart
        state/blitz_state.dart
      domain/
        entities/photo_group.dart
      infrastructure/
        repositories/blitz_repository.dart
        datasources/photo_datasource.dart
      presentation/
        pages/ widgets/
```

---

# 8. 性能与内存目标
- **内存占用**: < 100MB (只存元数据，不提加载 Thumbnail)。
- **Thumbnail 加载**: 由 UI 层 `ListView.builder` 懒加载，或配合 `extended_image` 处理缓存。

---

# 9. 开发阶段
- **Phase 0**: 纠正现有架构违规（将 SummaryPage 的删除逻辑下沉至 Datasource）。
- **Phase 1**: PrewarmService 核心框架 (core/services)。
- **Phase 2**: Isolate + AssetLite 异步分组。
- **Phase 3**: Lifecycle (resume) 与 PhotoManager 变更自动刷新（Debounce 500s）。
- **Phase 4**: 秒开交接逻辑与 UI 适配。
