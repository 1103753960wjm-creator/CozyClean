# CozyClean Architecture Rules (STRICT)

本文件定义 CozyClean 当前必须遵守的架构边界，目标是“可落地、可验证、可演进”。

## 1. 适用范围
- 适用于 `app_flutter/lib` 下所有业务代码。
- 以项目当前结构为准，不强制做一次性大迁移。

## 2. 当前标准分层（必须遵守）
`features/<feature>/` 内采用如下分层：

- `presentation/`：页面与组件，只负责渲染与交互转发。
- `application/`：Controller + State，负责业务编排与状态流转。
- `domain/`：纯业务模型与纯算法服务（无平台依赖）。
- `data/`：Repository、Datasource、外部系统适配（DB/相册/网络）。
- `core/`：跨 Feature 公共能力。

## 3. 依赖方向（强约束）
允许方向：
- `presentation -> application`
- `application -> domain | data | core`
- `data -> domain | core`
- `domain -> core`

禁止方向：
- `presentation -> data`
- `presentation -> platform plugin`
- `domain -> flutter ui / platform plugin`
- `core -> features`

## 4. 分层职责（强约束）
### 4.1 Presentation
允许：
- 读取状态、触发 controller 方法、UI 组合。

禁止：
- 直接访问数据库、`PhotoManager`、文件系统、网络。
- 在 `build()` 内做重计算或 IO。

### 4.2 Application
允许：
- 业务流程编排、状态更新、防抖、生命周期协调。

禁止：
- 绕过 Repository 直接访问持久化或平台层。

### 4.3 Domain
允许：
- 纯函数算法（如分组、评分、筛选策略）。

禁止：
- 引入 Flutter UI 包、平台插件包。

### 4.4 Data
允许：
- 访问 DB、PhotoManager、SharedPreferences、文件系统、网络。
- 对外提供稳定 repository 接口。

## 5. Blitz 关键专项约束
- 相册物理删除链路必须是：`UI -> Controller -> Repository -> Datasource -> PhotoManager`。
- Burst 分组逻辑必须在 `domain/services`，不得出现在 UI 或 widget `build()`。
- 列表页禁止加载原图，统一使用缩略图。

## 6. 迁移策略（避免规则与现状冲突）
- 当前按上述分层执行，优先保证功能正确与性能。
- 若未来引入 UseCase/Entity 全量 Clean Architecture，按 Feature 渐进迁移，不阻塞现有迭代。

## 7. 违规判定
出现以下任一情况视为违规：
- UI 直接调 datasource / plugin。
- Controller 直接调 storage/plugin。
- Domain 出现平台依赖。
- 业务重逻辑进入 `build()`。
