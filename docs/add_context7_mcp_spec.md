# 规范：添加 Context7 MCP 服务器

## 1. 目标描述
将 `context7` MCP 服务器添加到 `mcp_config.json` 配置文件的首位，并为代码相关查询实现自动调用规则。

## 2. 拟议变更

### 配置更新
- **文件**：`c:\Users\Administrator\.gemini\antigravity\mcp_config.json`
- **动作**：在 `mcpServers` 对象的顶部添加以下条目：
```json
"context7": {
  "serverUrl": "https://mcp.context7.com/mcp",
  "headers": {
    "CONTEXT7_API_KEY": "ctx7sk-60db13ae-0558-4474-8eae-a9b2a321cea7"
  }
}
```

### 备份
- **动作**：在同一目录下创建一个名为 `mcp_config.json.bak` 的当前 `mcp_config.json` 备份。

### 自动调用规则
- **文件**：`e:\CozyClean\combined_ai_rules.md`
- **规则标题**：`规则：自动调用 Context7`
- **规则内容**：`每当处理涉及分析、解释或修改本项目代码的用户请求时，AI Agent 应当主动调用 context7 MCP 服务器工具，以获取相关的上下文和见解，确保响应的高质量和上下文感知。`

## 3. 数据结构定义
`mcp_config.json` 遵循标准 MCP 服务器配置架构：
```json
{
  "mcpServers": {
    "服务器名称": {
      "serverUrl": "URL",
      "headers": {
        "键": "值"
      }
    }
  }
}
```

## 4. 异常处理
- 如果未找到 `mcp_config.json`，则报告错误。
- 如果写入配置失败，则从备份恢复。
- 如果 API 密钥无效，则在验证期间通知用户。

## 5. 需要用户评审
- [x] 确认自动调用规则的位置（`combined_ai_rules.md`）。
- [x] 确认服务器 URL 和请求头与提供的信息一致。
