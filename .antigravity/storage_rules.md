# Storage & Platform Access Rules

所有持久化与平台访问必须遵守统一链路：

`UI -> Controller -> Repository -> DataSource -> Storage/Platform`

## 1. 禁止直连
以下直连一律禁止：
- UI/Widget 直连数据库
- UI/Widget 直连 PhotoManager
- Controller 直连 SharedPreferences / 文件系统 / PhotoManager / 数据库

## 2. Repository 职责
- 作为业务层与底层存储/平台的唯一抽象边界。
- 对上暴露稳定接口；对下协调 datasource。
- 负责错误转换与失败兜底，不把底层异常原样泄漏到 UI。

## 3. DataSource 职责
- 封装具体读写动作（数据库、相册、文件、平台插件）。
- 统一输入输出结构，避免上层感知插件细节。

## 4. Blitz 专项
- 物理删除必须通过 repository + datasource 执行。
- 控制器可做删除确认与统计埋点，但不得直接调用 PhotoManager。

## 5. 可测试性
- Repository 接口需可 mock。
- 关键存储流程必须有失败路径测试（权限不足、空结果、异常抛出）。
