# 🪸 NotebookLM Skill — 完整流程图

```
┌─────────────────────────────────────────────────────────┐
│  🌐 NotebookLM Skill Architecture                       │
│  Gateway: nlm-gateway.sh                                │
│  CLI: notebooklm v0.3.2                                 │
│  Proxy: http://127.0.0.1:8234 (Surge 美国节点)          │
│  Auth: ~/.notebooklm/storage_state.json                 │
│  Data: ~/.openclaw/notebooklm-data/                     │
└─────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════
  📚 Notebook Registry
═══════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────┐
│  Registered Notebooks                                   │
├─────────────────────────────────────────────────────────┤
│  • openclaw-docs (50源，满载)                           │
│    - OpenClaw 文档知识库                                │
│    - 用于：星链 Step 1.5/6 历史知识查询                 │
│                                                         │
│  • media-research (3源)                                 │
│    - 自媒体调研知识库                                   │
│    - 用于：自媒体 Step 2/5.5 调研和衍生内容             │
│                                                         │
│  • memory (5源，待迁移)                                 │
│    - 记忆知识库                                         │
│    - 计划迁移到向量数据库                               │
└─────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════
  🔐 ACL (Access Control List)
═══════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────┐
│  Agent Roles & Permissions                              │
├─────────────────────────────────────────────────────────┤
│  admin (完全访问)                                        │
│    • main                                               │
│    • 权限：所有操作 + 笔记本管理                         │
│                                                         │
│  contributor (贡献者)                                    │
│    • wemedia → media-research, memory                   │
│    • gemini → memory, media-research, openclaw-docs     │
│    • brainstorming → memory, media-research, openclaw-docs│
│    • 权限：query, source-add/list, artifact, research   │
│                                                         │
│  reader (只读)                                          │
│    • coding, review, test, docs → openclaw-docs, memory │
│    • 权限：query, source-list                           │
│                                                         │
│  monitor (监控)                                         │
│    • monitor-bot                                        │
│    • 权限：health-check, query                          │
└─────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════
  🔄 Operation Flow
═══════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────┐
│  1️⃣  Agent Request                                      │
│     ↓                                                   │
│     agent calls: nlm-gateway.sh <operation>             │
│                  --agent <agent_id>                     │
│                  --notebook <name>                      │
│                  [operation-specific params]            │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  2️⃣  Gateway Processing                                 │
│     ┌─────────────────────────────────────────────┐    │
│     │  ACL Check                                  │    │
│     │  • Verify agent role                        │    │
│     │  • Check notebook access                    │    │
│     │  • Validate operation permission            │    │
│     └─────────────────┬───────────────────────────┘    │
│                       ↓                                 │
│     ┌─────────────────────────────────────────────┐    │
│     │  Cache Check (if applicable)                │    │
│     │  • Query: TTL 1h                            │    │
│     │  • Source list: TTL 5min                    │    │
│     │  • Hit → return cached result               │    │
│     │  • Miss → continue                          │    │
│     └─────────────────┬───────────────────────────┘    │
│                       ↓                                 │
│     ┌─────────────────────────────────────────────┐    │
│     │  Rate Limit Check                           │    │
│     │  • 10 requests/min per agent                │    │
│     │  • Backoff if exceeded                      │    │
│     └─────────────────┬───────────────────────────┘    │
│                       ↓                                 │
│     ┌─────────────────────────────────────────────┐    │
│     │  Content Filter (query only)                │    │
│     │  • Check deny patterns                      │    │
│     │  • Block sensitive queries                  │    │
│     └─────────────────┬───────────────────────────┘    │
└─────────────────────────┼───────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  3️⃣  CLI Execution                                      │
│     ┌─────────────────────────────────────────────┐    │
│     │  Proxy Setup                                │    │
│     │  • https_proxy=http://127.0.0.1:8234        │    │
│     │  • http_proxy=http://127.0.0.1:8234         │    │
│     └─────────────────┬───────────────────────────┘    │
│                       ↓                                 ┌─────────────────────────────────────────────┐    │
│     │  notebooklm CLI                             │    │
│     │  • query / source / artifact / research     │    │
│     │  • Authenticated via storage_state.json     │    │
│     └─────────────────┬───────────────────────────┘    │
└─────────────────────────┼───────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  4️⃣  Response Processing                                │
│     ┌─────────────────────────────────────────────┐    │
│     │  Parse CLI Output                           │    │
│     │  • Extract answer/sources/artifacts         │    │
│     │  • Handle errors                            │    │
│     └─────────────────┬───────────────────────────┘    │
│                       ↓                                 │
│     ┌─────────────────────────────────────────────┐    │
│     │  Cache Update (if applicable)               │    │
│     │  • Store result with TTL                    │    │
│     └─────────────────┬───────────────────────────┘    │
│                       ↓                                 │
│     ┌─────────────────────────────────────────────┐    │
│     │  Audit Log                                  │    │
│     │  • Log to audit.jsonl                       │    │
│     │  • Track: agent, notebook, operation,       │    │
│     │    status, latency, error                   │    │
│     └─────────────────┬───────────────────────────┘    │
└─────────────────────────┼───────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  5️⃣  Return JSON Response                               │
│     {                                                   │
│       "ok": true,                                       │
│       "cached": false,                                  │
│       "data": { ... }                                   │
│     }                                                   │
└─────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════
  📋 Operations
═══════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────┐
│  🔍 Query                                                │
├─────────────────────────────────────────────────────────┤
│  nlm-gateway.sh query \                                 │
│    --agent <agent_id> \                                 │
│    --notebook <name> \                                  │
│    --query "question" \                                 │
│    [--no-cache]                                         │
│                                                         │
│  Response:                                              │
│  {                                                      │
│    "ok": true,                                          │
│    "cached": false,                                     │
│    "data": {                                            │
│      "answer": "...",                                   │
│      "sources": [...]                                   │
│    }                                                    │
│  }                                                      │
│                                                         │
│  Cache: 1 hour TTL                                      │
│  Rate: 10 req/min per agent                             │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  📄 Source Management                                    │
├─────────────────────────────────────────────────────────┤
│  Add source:                                            │
│  nlm-gateway.sh source \                                │
│    --agent <agent_id> \                                 │
│    --subcmd add \                                       │
│    --notebook <name> \                                  │
│    --path <url|file>                                    │
│                                                         │
│  List sources:                                          │
│  nlm-gateway.sh source \                                │
│    --agent <agent_id> \                                 │
│    --subcmd list \                                      │
│    --notebook <name> \                                  │
│    [--no-cache]                                         │
│                                                         │
│  Remove source:                                         │
│  nlm-gateway.sh source \                                │
│    --agent <agent_id> \                                 │
│    --subcmd remove \                                    │
│    --notebook <name> \                        │
│    --source-id <id>                                     │
│                                                         │
│  Supported types: URL, PDF, YouTube, text, file        │
│  Cache: 5 min TTL (list only)                           │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  🎨 Artifact Generation                                  │
├─────────────────────────────────────────────────────────┤
│  Generate:                                              │
│  nlm-gateway.sh artifact \                              │
│    --agent <agent_id> \                                 │
│    --subcmd generate \                                  │
│    --notebook <name> \                                  │
│    <type>                                               │
│                                                         │
│  Download:                                              │
│  nlm-gateway.sh artifact \                              │
│    --agent <agent_id> \                                 │
│    --subcmd download \                                  │
│    --notebook <name> \                                  │
│    <artifact_id>                                        │
│                                                         │
│  Types:                                                 │
│  • podcast      - 音频播客                              │
│  • video        - 视频                                  │
│  • slides       - 幻灯片                                │
│  • infographic  - 信息图                                │
│  • report       - 报告                                  │
│  • mind-map     - 思维导图                              │
│  • quiz         - 测验                                  │
│  • flashcards   - 问答卡片                              │
│                                                         │
│  Download path: ~/.openclaw/notebooklm-data/artifacts/ │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  🔬 Research                                             │
├─────────────────────────────────────────────────────────┤
│  nlm-gateway.sh research \                              │
│    --agent <agent_id> \                                 │
│    --notebook <name> \                                  │
│    --query "research topic"                             │
│                                                         │
│  Triggers web/Drive research and adds results as       │
│  new sources to the notebook                            │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  📚 Notebook Registry                                    │
├─────────────────────────────────────────────────────────┤
│  List:                                                  │
│  nlm-gateway.sh notebooks \                             │
│    --agent <agent_id> \                                 │
│    --subcmd list                                        │
│                                                         │
│  Get details:                                           │
│  nlm-gateway.sh notebooks \                             │
│    --agent <agent_id> \                                 │
│    --subcmd get <name>                                  │
│                                                         │
│  Add (admin only):                                      │
│  nlm-gateway.sh notebooks \                             │
│    --agent <agent_id> \                                 │
│    --subcmd add \                                       │
│    <name> <notebook_id> "description"                   │
│                                                         │
│  Remove (admin only):                                   │
│  nlm-gateway.sh notebooks \                             │
│    --agent <agent_id> \                                 │
│    --subcmd remove <name>                               │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  🏥 Health Check                                         │
├─────────────────────────────────────────────────────────┤
│  On-demand:                                             │
│  nlm-gateway.sh health --agent <agent_id>               │
│                                                         │
│  Cron-friendly (for monitor-bot):                      │
│  nlm-health.sh [agent_id]                               │
│                                                         │
│  Response:                                              │
│  {                                                      │
│    "ok": true,                                          │
│    "auth": true,                                        │
│    "auth_message": "authenticated",                     │
│    "notebooks_registered": 3,                           │
│    "cache_size_kb": 1024,                               │
│    "data_dir": "..."                                    │
│  }                                                      │
└─────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════
  ⚠️ Error Handling & Graceful Degradation
═══════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────┐
│  Error Categories                                       │
├─────────────────────────────────────────────────────────┤
│  auth_expired (retry: false)                            │
│    • Authentication has expired                         │
│    • Action: re-login with `notebooklm login`           │
│                                                         │
│  rate_limited (retry: true)                             │
│    • Too many requests                                  │
│    • Action: auto-backoff, retry after delay            │
│                                                         │
│  cli_error (retry: false)                               │
│    • CLI command failed                                 │
│    • Action: check CLI installation and config          │
│                                                         │
│  network_error (retry: true)                            │
│    • Network issue                                      │
│    • Action: retry with exponential backoff             │
│                                                         │
│  acl_denied (retry: false)                              │
│    • Permission denied                                  │
│    • Action: check ACL configuration                    │
│                                                         │
│  notebook_not_found (retry: false)                      │
│    • Notebook not registered                            │
│    • Action: register notebook first                    │
│                                                         │
│  timeout (retry: true)                                  │
│    • Request timed out                                  │
│    • Action: retry with longer timeout                  │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  Graceful Degradation                                   │
├─────────────────────────────────────────────────────────┤
│  When NotebookLM is unavailable:                        │
│                                                         │
│  {                                                      │
│    "ok": false,                                         │
│    "error": "cli_error",                                │
│    "message": "NotebookLM service unavailable",         │
│    "fallback": true,                                    │
│    "retry": false                                       │
│  }                                                      │
│                                                         │
│  Calling agents should:                                 │
│  1. Check `fallback` flag                               │
│  2. Push Warning to monitor group                       │
│  3. Skip the operation gracefully                       │
│  4. Continue pipeline without blocking                  │
└─────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════
  📊 Data Directory Structure
═══════════════════════════════════════════════════════════

```
~/.openclaw/notebooklm-data/
├── logs/
│   └── audit.jsonl              # Operation audit logs
│       {
│         "timestamp": "2026-03-06T10:00:00Z",
│         "agent": "main",
│         "notebook": "memory",
│         "operation": "query",
│         "status": "ok",
│         "latency_ms": 1500,
│         "error": ""
│       }
│
├── cache/
│   ├── query/                   # Query result cache (TTL: 1h)
│   │   └── <hash>.json
│   └── source_list/             # Source list cache (TTL: 5min)
│       └── <notebook>.json
│
├── artifacts/                   # Downloaded artifact staging
│   ├── podcast_<id>.mp3
│   ├── mind-map_<id>.png
│   └── ...
│
└── lock/
    └── nlm.lock                 # Concurrency lock file
```

═══════════════════════════════════════════════════════════
  ⏰ Cron Jobs
═══════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────┐
│  Health Check (every 6 hours)                           │
├─────────────────────────────────────────────────────────┤
│  Schedule: 0 */6 * * *                                  │
│  Command: nlm-health.sh monitor-bot                     │
│  Purpose: Monitor auth status and API availability      │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  Document Refresh (daily at 04:00)                      │
├─────────────────────────────────────────────────────────┤
│  Schedule: 0 4 * * *                                    │
│  Command: nlm-sync.sh                                   │
│  Purpose: Sync openclaw-docs sources                    │
└─────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════
  🔧 Configuration Files
═══════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────┐
│  config/acl.json                                        │
├─────────────────────────────────────────────────────────┤
│  Per-agent access control                               │
│  • role: admin | contributor | reader | monitor | none  │
│  • notebooks: ["name1", "name2"] or "*"                 │
│  • operations: ["query", "source-add", ...]             │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  config/notebooks.json                                  │
├─────────────────────────────────────────────────────────┤
│  Notebook name → ID registry                            │
│  {                                                      │
│    "openclaw-docs": {                                   │
│      "id": "notebook-id-here",                          │
│      "description": "OpenClaw docs"                     │
│    }                                                    │
│  }                                                      │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  config/settings.json                                   │
├─────────────────────────────────────────────────────────┤
│  • proxy: "http://127.0.0.1:8234"                       │
│  • rate_limit: 10 req/min per agent                     │
│  • cache_ttl:                                           │
│    - query: 3600s (1h)                                  │
│    - source_list: 300s (5min)                           │
│  • content_filter_deny: ["pattern1", "pattern2"]        │
└─────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════
  🚀 Usage in Pipelines
═══════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────┐
│  星链流水线 (starchain-pipeline)                         │
├─────────────────────────────────────────────────────────┤
│  Step 1.5: 珊瑚(notebooklm) 查询历史知识                │
│    • Notebook: openclaw-docs, memory                    │
│    • Operation: query                                   │
│    • Purpose: 提供相关上下文和最佳实践                   │
│                                                         │
│  Step 6: 珊瑚(notebooklm) 查询文档模板                  │
│    • Notebook: openclaw-docs                            │
│    • Operation: query                                   │
│    • Purpose: 获取文档模板和示例                         │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  自媒体流水线 (wemedia-pipeline)                         │
├─────────────────────────────────────────────────────────┤
│  Step 2: 珊瑚(notebooklm) 深度调研                      │
│    • Notebook: media-research                           │
│    • Operation: query, research                         │
│    • Purpose: 历史研究和内容策略                         │
│                                                         │
│  Step 5.5: 珊瑚(notebooklm) 衍生内容生成                │
│    • Notebook: media-research                           │
│    • Operation: artifact (generate + download)          │
│    • Types: podcast, mind-map, quiz, infographic        │
│    • Purpose: 多样化内容形式                             │
└─────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════
  🏁 END
═══════════════════════════════════════════════════════════
```
