# CozyClean Workflow Rules (Spec + TDD)

目标：既保证质量，又避免流程过重导致开发停滞。

## 1. 双模式工作流

### 1.1 Fast Path（严格快速通道）
适用于：**同时满足全部条件** 的小改动。

准入条件（全部满足才可进入 Fast Path）：
- 只改 1 个业务文件（可额外新增/修改 1 个对应测试文件）
- 净改动建议 <= 60 行（不含格式化噪音）
- 不修改公共接口签名、数据结构、数据库 schema、路由契约
- 不跨层（不得同时改 presentation/application/domain/data 多层）
- 不涉及高风险链路：删除、权限、生命周期、并发/Isolate、缓存策略、启动流程
- 预计 30 分钟内可完成实现与验证

步骤：
1. 快速澄清与假设确认（必要时问 1-3 个关键问题）
2. 直接实现
3. 本地校验（format/analyze/test）
4. 输出变更说明与风险

升级规则：任一准入条件不满足，立即切换 Standard Path。
说明：用户明确“同意继续”后，默认自动推进，不反复等待确认。

### 1.2 Standard Path（默认）
适用于：新功能、架构重构、跨模块改造、高风险变更。

步骤：
1. Discovery：澄清边界与决策点
2. Spec：更新 `docs/spec.md`（目标、边界、异常、数据结构）
3. Test Design：先补/先改测试
4. Plan：任务拆分与顺序
5. Execution：按计划编码
6. Verification：跑校验并闭环
7. Reporting：总结结果与后续建议

## 2. 何时必须走 Standard Path
满足任一条件即进入 Standard Path：
- 涉及跨层重构（presentation/application/domain/data）
- 涉及数据结构迁移
- 涉及性能架构升级（如 isolate pipeline、预热缓存体系）
- 涉及状态切换可见性问题（如白屏/空状态闪现/加载态抖动）
- 涉及删除链路、权限链路、生命周期监听
- 预计工时 >= 2 小时

## 3. 验证标准（DoD）
至少满足：
- 功能行为符合 spec
- 无新增 analyzer error
- 受影响测试通过
- 核心路径有日志可观测
- 性能改动有对比结论（命中率、耗时或首屏体验描述）

## 4. 异常处理
验证失败必须继续修复，直到闭环；除非用户明确要求停止。