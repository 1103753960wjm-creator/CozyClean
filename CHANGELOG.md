# 📝 CozyClean 开发更新日志

> 记录每次推送到 GitHub 的更新内容，按时间倒序排列。

---

## v0.2.7 — 2026-02-24

### 🎨 UI/UX 视觉再升级
- **仪表盘成就看板优化** — 将原本横向铺满的宽边横幅修改为紧凑居中的精美**“悬浮胶囊”**形态。
  - 提升了圆角度数 (` BorderRadius.circular(20)` )。
  - 缩减了内外边距、下调了字体大小与阴影厚度，使整体质感更加轻盈内敛。
  - 使用 `MainAxisSize.min` 与 Flexible 替代 Expanded 控制尺寸自适应包裹，页面呼吸感显著提升。

---

## v0.2.6 — 2026-02-24

### ✨ 成就数据闭环与全链路打通
- **仪表盘成就看板入住** — 在 `DashboardPage` 引入了全新的动态数据看板组件。不仅实时反映为手机清理出的真实 KB/MB 空间大小，还使用 `TweenAnimationBuilder` 增加了数字无缝增长动画。
- **结算写入事务同步** — `SummaryPage` 信封投掷动画落幕后，现已接入底层的 `UserStatsController.recordCleaningSession`，真正实现了：刷卡 → 系统相册删除 → 播放彩屑结算 → **累加本地持久化成就大盘**。
- **全局基础工具库** — 引入了干净清爽的 `FormatUtils` 静态工具类，封装通用的 `formatBytes` 流量数据处理算法，统一各端的显示单位自动升降级规则。

---

## v0.2.5 — 2026-02-24

### ✨ 数据打通与用户状态持久化
- **新增用户状态控制器 (UserStatsController)** — 基于 Drift 数据库实现用户状态全面持久化。涵盖单机版默认用户的 `dailyEnergyRemaining`（每日体力）和 `isPro`（会员标识）双核心属性。
- **动态仪表盘接入真实流数据** — `DashboardPage` 现已彻底告别静态 UI，通过 `userStatsStreamProvider` 全面监听本地状态。
  - 普通用户展示“数字体力+动态彩环（绿/红）”
  - Pro 用户展示专享“无限∞符号+尊贵满圈金环”
  - 点击侧标题问候语可模拟体验 Pro 身份开/关的全局联动反馈。

### 🚀 骨架屏消灭行动与体验双重优化
- **消除 PhotoCard 闪烁** — 去除所有异步的 `FutureBuilder` 和骨架屏。采用原生端全同步提供内存缩略图字节流，基于图片 ` gaplessPlayback`，在框架级封杀高速出卡时的残影闪变问题。
- **状态流闭环同步** — `BlitzController` 现已无缝挂载 `UserStatsController`，刷卡消费体力的动作实时向底层 Drift 发出更新事务，驱动首页数据环全自动即时折损呈现。
- **简化查询与边界自保** — `BlitzController` 照片排重系统进一步优化，在 `getDeletedPhotoIds` 中精准过滤已被删除状态的数据；修正末端卡片边界判断，护航快速甩卡不报错。

---

## v0.2.4 — 2026-02-23

### ✨ 新增功能
- **新增仪表盘主页 (DashboardPage)** — 引入全新的手账质感首页，提供统一的入口。包含用户问候、今日体力条、清理数据环以及功能选择器（已开放“闪电战”，预告“截图粉碎”与“时光机”）。
- **更新应用入口** — `main.dart` 默认指向 `DashboardPage`。

### 🚀 性能与体验深度优化
- **UI 渲染精细化重建** — 彻底重构了 `BlitzPage` 的状态监听逻辑，引入 Riverpod `.select(...)` 实现精细化局部刷新，剥离了 Swiper 滑动主区与顶部状态栏的重建关系，彻底解决连滑时画面卡顿与动画中断的问题。
- **图片加载光速提升** — `PhotoCard` 摒弃获取本地 `.file` 所需的磁盘 IO 耗时，改为直接向原生层请求 800x800 的内存缩略图字节流 (`thumbnailDataWithSize`)，彻底消除滑动接缝期骨架屏闪烁感。
- **底层组件状态驻留** — 为生成的 `PhotoCard` 强制绑定 `ValueKey(photo.id)`，保护其底层 `State` 在图层数组移位时免遭销毁，配合 Flutter 原生的 `gaplessPlayback` 实现无缝过渡。

---

## v0.2.3 — 2026-02-22

### 🎨 UI/UX 质感大升级与动画打磨

#### ⚡ 闪电战页面深度重构 (BlitzPage & PhotoCard)
- **拍立得质感卡片** — 将 `PhotoCard` 升级为拟真拍立得相纸风格，采用纯白底框护城河设计，配合双层阴影营造强烈的悬浮立体感。
- **动态印章反馈 (Stamp Layer)** — 滑动卡片时，会根据滑动方向在卡片边缘动态渐显红色的 `DISCARD` 或绿色的 `KEEP` 印章，极大地增强了手势滑动的物理反馈。
- **底部操作区极简风** — 移除了传统的喜欢/删除大圆按钮，改为极简的“丢弃 / 保留”文本手柄，将视觉重心完全交还给照片本身。
- **仿真手账撤销按钮** — 左下角新增自带轻微倾斜、撕纸贴片风格的撤销 (`unswipe`) 按钮，体验更轻盈自然。
- **层叠厚度优化** — 在 `AppinioSwiper` 中配置 `backgroundCardCount: 2` 并设置透视缩放与纵向偏移，令卡片堆叠具备极佳的景深。

#### ✨ 结算动画重制 (SummaryPage)
- **卡片掉落物理动画** — 重构结算页动画系统，摒弃单纯的纸屑喷洒，改为根据实际清理的照片生成等比例的微型拍立得卡片，并在页面开启时执行带重力掉落、旋转散开的物理动效。
- **状态分离与更清晰的提示** — 新增成功与中止（未做修改）的差分状态展示，确保无论用户是否真的删除了照片，都有对应的优雅反馈。

---

## v0.2.2 — 2026-02-22

### ✨ 新特性
- **新增结算总结页面 (SummaryPage)** — 在闪电战完成所有卡片滑动后自动跳转至结算页，展示本次清理的具体张数并预估释放的存储空间，同时包含 `confetti` 庆祝纸屑动画。

### 🐛 闪电战体验优化 & Bug 修复
- **优化连滑体验** — 修复了在此前版本中快速连续滑动卡片导致的 UI 状态（进度、体力）未及时更新的 Bug，将状态更新调整为优先执行（乐观更新），保障用户视觉反馈的一致性和流畅感。
- **调整过滤逻辑** — 修改 Drift 查询方法为 `_getDeletedPhotoIds()`，加载照片时现在仅过滤标记为"删除"（`actionType = 1`）的照片，标记为"保留"（`actionType = 0`）的照片仍将继续展示。
- **完善边界路由** — `BlitzPage` 新增状态监听和 `onEnd` 双重校验机制，确保列表被完全滑空后稳定触发页面跳转，并新增导航锁（`_isNavigating`）防止重复触发。

### 📦 依赖更新
- 更新 `pubspec.yaml`，新增 `confetti` UI 动画包。

---

## v0.2.1 — 2026-02-21

### 🐛 闪电战模式 Bug 修复 & 稳定性优化

#### 🔧 BlitzController 修复
- **修复重复加载 Bug** — 新增独立防重入标志 `_loadingInProgress`，解决 `build()` 初始 `isLoading: true` 导致 `loadPhotos()` 无法触发的问题
- **修复数据库查询** — 简化 `_getProcessedPhotoIds()` 的 Drift 查询语句，移除不必要的 `addColumns` 调用
- **增加调试日志** — 在照片加载各阶段添加 `print` 日志输出，便于排查权限、相册、去重等环节问题
- **异常堆栈追踪** — `catch` 块增加 `stackTrace` 捕获，提升错误排查能力

#### 🛡️ BlitzPage 稳定性改进
- **新增 `initState` 加载触发** — 通过 `addPostFrameCallback` 在首帧渲染后触发 `loadPhotos()`，避免在 widget 构建期间修改 Provider 状态
- **新增错误信息展示 UI** — 当权限被拒或加载失败时，在屏幕上红字显示错误信息
- **新增滑动越界安全检查** — 在 `onSwipeEnd` 和 `cardBuilder` 中添加索引边界检查，防止滑完最后一张后数组越界崩溃

---

## v0.2.0 — 2026-02-21

### ✨ 搭建 Flutter 前端框架 & 实现闪电战核心功能

#### 🏗️ 项目架构
- 初始化 Flutter 项目，集成 **Riverpod** 状态管理
- 采用 **Clean Architecture** 分层架构：`presentation` / `domain` / `data`
- 配置 Android、iOS、Web、Windows、Linux、macOS 六大平台支持

#### ⚡ 闪电战模式 (Blitz Mode)
- `BlitzController` — 核心控制器（照片加载、去重、左滑删除/右滑保留）
- `BlitzState` — 状态管理（照片列表、当前位置、体力值）
- `BlitzPage` — 交互式刷卡页面 UI
- `PhotoCard` — 照片卡片展示组件

#### 🔌 数据层
- `ApiClient` — 远程 API 通信客户端
- `AuthRepositoryImpl` / `SyncRepositoryImpl` — 认证与同步仓库实现
- `IAuthRepository` / `ISyncRepository` — Domain 层仓库抽象接口

#### 📦 配置变更
- 更新 `pubspec.yaml`，新增 `photo_manager` 等依赖
- 添加 Flutter `.gitignore`
- 添加 `analysis_options.yaml` 代码质量配置

---

## v0.1.0 — 2026-02-20

### 🚀 项目初始化 — 后端框架搭建

#### 🏗️ Monorepo 结构
- 建立 `backend/` + `app_flutter/` 单仓多项目结构
- 添加项目根目录 `.gitignore`

#### ⚙️ FastAPI 后端
- `main.py` — 应用入口，配置 CORS 中间件与路由挂载
- `app/core/config.py` — 环境变量与应用配置
- `app/core/database.py` — SQLAlchemy 异步数据库引擎
- `app/core/security.py` — JWT 认证与密码加密
- `app/core/limiter.py` — 速率限制中间件

#### 📊 数据模型
- `app/models/base.py` — SQLAlchemy ORM 模型定义
  - `User` 用户表
  - `SyncSession` 同步会话表
  - `PhotoAction` 照片操作记录表
  - `AppConfig` 应用配置表

#### 🔗 API 接口
- `app/api/v1/auth.py` — 用户注册/登录接口
- `app/api/v1/sync.py` — 数据同步接口
- `app/api/deps.py` — 依赖注入（数据库会话、当前用户）

#### 📐 数据校验
- `app/schemas/auth.py` — 认证相关 Pydantic Schema
- `app/schemas/sync.py` — 同步相关 Pydantic Schema

#### 📦 依赖
- `requirements.txt` — FastAPI、SQLAlchemy、Alembic、PyJWT 等

#### 🗃️ Flutter 占位
- `app_flutter/pubspec.yaml` — Flutter 项目初始配置
- `app_flutter/lib/data/local/app_database.dart` — Drift 数据库模型定义
