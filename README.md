# NotebookLM OpenClaw Skill — 用户指南

> 本文档面向晨星（系统管理员），提供 NotebookLM Skill 的完整使用指南。

## 概述

NotebookLM Skill 为 OpenClaw 多代理系统提供统一的 NotebookLM 接口，具备以下能力：

- **查询**：基于笔记本内容回答问题
- **源管理**：添加、列出、删除资料源
- **Artifact 生成**：生成播客、视频、幻灯片、报告、思维导图等
- **研究**：触发 Web/Drive 研究并 **访问存储结果
-控制**：基于代理角色的权限管理
- **健康监控**：认证状态、API 可用性检查

## 架构简图

```
┌─────────────────────────────────────────────────────────────┐
│                     OpenClaw Agents                         │
│  (main, wemedia, coding, review, docs, brainstorming...)    │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│              nlm-gateway.sh (Gateway)                       │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────────┐    │
│  │   ACL   │  │ Cache   │  │  Rate   │  │  Content    │    │
│  │ Check   │  │ Manager │  │  Limit  │  │  Filter     │    │
│  └────┬────┘  └────┬────┘  └────┬────┘  └──────┬──────┘    │
└───────┼────────────┼────────────┼──────────────┼──────────┘
        │            │            │              │
        ▼            ▼            ▼              ▼
┌─────────────────────────────────────────────────────────────┐
│                  notebooklm CLI                            │
│              (Python package: notebooklm-py)                │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                   Google NotebookLM API                    │
└─────────────────────────────────────────────────────────────┘
```

## 快速开始

### 1. 安装依赖

```bash
# 安装 notebooklm-py (通过 uv)
uv pip install notebooklm-py

# 确认安装成功
notebooklm --version
```

### 2. 配置代理

由于 NotebookLM 在某些地区需要代理访问，技能已预配置代理：

```json
// ~/.openclaw/skills/notebooklm/config/settings.json
{
  "proxy": "http://127.0.0.1:8234"
}
```

如需修改代理地址，编辑 `config/settings.json`。

### 3. 登录 NotebookLM

```bash
# 确保 Surge 增强模式开启并选择美国节点
notebooklm login
```

登录后，认证状态存储在 `~/.notebooklm/storage_state.json`。

### 4. 验证安装

```bash
cd ~/.openclaw/skills/notebooklm
./scripts/nlm-gateway.sh health --agent main
```

正常响应：
```json
{
  "ok": true,
  "auth": true,
  "auth_message": "authenticated",
  "notebooks_registered": 0,
  "cache_size_kb": 0,
  "data_dir": "/Users/lucifinil_chen/.openclaw/notebooklm-data"
}
```

## Notebook 管理

### 创建新 Notebook

1. 在 [NotebookLM Web](https://notebooklm.google.com/) 创建笔记本
2. 复制笔记本 ID（从 URL）
3. 注册到 Skill：

```bash
./scripts/nlm-gateway.sh notebooks --agent main --subcmd add \
  --name my-notebook \
  --id "your-notebook-id" \
  --desc "Description here"
```

### 列出已注册 Notebook

```bash
./scripts/nlm-gateway.sh notebooks --agent main --subcmd list
```

### 删除 Notebook 注册

```bash
./scripts/nlm-gateway.sh notebooks --agent main --subcmd remove --name my-notebook
```

## 常用操作

### 查询 Notebook

```bash
./scripts/nlm-gateway.sh query \
  --agent main \
  --notebook memory \
  --query "What is the current project status?"
```

### 添加源

```bash
# 添加 URL
./scripts/nlm-gateway.sh source \
  --agent main \
  --subcmd add \
  --notebook memory \
  --path "https://example.com/article"

# 添加本地 PDF
./scripts/nlm-gateway.sh source \
  --agent main \
  --subcmd add \
  --notebook memory \
  --path "/path/to/document.pdf"
```

### 列出源

```bash
./scripts/nlm-gateway.sh source \
  --agent main \
  --subcmd list \
  --notebook memory
```

### 生成 Artifact

```bash
# 生成播客
./scripts/nlm-gateway.sh artifact \
  --agent wemedia \
  --subcmd generate \
  --notebook media-research \
  podcast

# 生成报告
./scripts/nlm-gateway.sh artifact \
  --agent wemedia \
  --subcmd generate \
  --notebook media-research \
  report
```

### 运行研究

```bash
./scripts/nlm-gateway.sh research \
  --agent main \
  --notebook media-research \
  --query "Latest AI trends 2026"
```

## ACL 配置说明

访问控制配置在 `config/acl.json`：

```json
{
  "agents": {
    "main": {
      "role": "admin",
      "notebooks": "*",
      "operations": ["query", "source-add", "source-remove", ...]
    },
    "wemedia": {
      "role": "contributor",
      "notebooks": ["media-research", "memory"],
      "operations": ["query", "source-add", ...]
    }
  }
}
```

### 角色说明

| 角色 | 说明 |
|------|------|
| `admin` | 完全访问，可管理笔记本注册表 |
| `contributor` | 可查询、添加源、生成 Artifact |
| `reader` | 仅查询和列出源 |
| `monitor` | 仅健康检查和查询 |
| `none` | 禁止访问 |

### 修改代理权限

编辑 `config/acl.json`，添加或修改代理条目：

```json
"new-agent": {
  "role": "reader",
  "notebooks": ["memory", "openclaw-docs"],
  "operations": ["query", "source-list"]
}
```

## 常见问题排查

### 认证过期

```
{"ok":false,"error":"auth_expired","message":"Authentication expired"}
```

**解决**：重新登录
```bash
notebooklm login
```

### 代理连接失败

```
{"ok":false,"error":"network_error","message":"Connection refused"}
```

**解决**：
1. 确认代理服务运行中 (`http://127.0.0.1:8234`)
2. 或修改 `config/settings.json` 中的代理地址

### 权限拒绝

```
{"ok":false,"error":"acl_denied","message":"Operation not allowed for agent X"}
```

**解决**：检查 `config/acl.json` 中该代理的权限配置

### 速率限制

```
{"ok":false,"error":"rate_limited","message":"Too many requests"}
```

**解决**：等待一分钟或调整 `config/settings.json` 中的速率限制

### Notebook 未找到

```
{"ok":false,"error":"notebook_not_found","message":"Notebook 'xxx' not registered"}
```

**解决**：先在 NotebookLM Web 创建，然后在 config/notebooks.json 中注册

## 定时任务

### 健康检查（每 6 小时）

```bash
openclaw cron add \
  --name notebooklm-health \
  --schedule "0 */6 * * *" \
  --command "nlm-health.sh monitor-bot"
```

### 源同步（每日 03:00）

```bash
openclaw cron add \
  --name notebooklm-sync \
  --schedule "0 3 * * *" \
  --command "nlm-sync.sh"
```

## 数据位置

| 数据 | 路径 |
|------|------|
| 认证状态 | `~/.notebooklm/storage_state.json` |
| 运行时数据 | `~/.openclaw/notebooklm-data/` |
| 审计日志 | `~/.openclaw/notebooklm-data/logs/audit.jsonl` |
| 查询缓存 | `~/.openclaw/notebooklm-data/cache/query/` |
| 源列表缓存 | `~/.openclaw/notebooklm-data/cache/source_list/` |
| Artifact 暂存 | `~/.openclaw/notebooklm-data/artifacts/` |

## 相关文档

- [Spec 文档](~/.openclaw/workspace/agents/brainstorming/ideas/notebooklm-skill-spec.md)
- [Plan 文档](~/.openclaw/workspace/agents/brainstorming/ideas/notebooklm-skill-plan.md)
- [notebooklm-py GitHub](https://github.com/tananaev/notebooklm-py)
