# 📝 CozyClean 开发更新日志

> 记录每次推送到 GitHub 的更新内容，按时间倒序排列。

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
