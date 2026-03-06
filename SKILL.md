# NotebookLM Skill

Interact with Google NotebookLM via the `notebooklm` CLI through a managed gateway with ACL, caching, rate limiting, and content filtering.

## Description

Multi-agent gateway for NotebookLM operations: query notebooks, manage sources, generate artifacts, and run research — all with per-agent access control and structured JSON output.

## Commands

### Query a notebook
```bash
# Basic query
nlm-gateway.sh query --agent <agent_id> --notebook <name> --query "your question"

# Bypass cache
nlm-gateway.sh query --agent <agent_id> --notebook <name> --query "question" --no-cache

# Example
nlm-gateway.sh query --agent main --notebook memory --query "What is the current context?"
```

**Response format:**
```json
{
  "ok": true,
  "cached": false,
  "data": {
    "answer": "...",
    "sources": [...]
  }
}
```

### Source management
```bash
# Add source to notebook
nlm-gateway.sh source --agent <agent_id> --subcmd add --notebook <name> --path /path/to/file

# List sources in notebook
nlm-gateway.sh source --agent <agent_id> --subcmd list --notebook <name>

# List sources bypassing cache
nlm-gateway.sh source --agent <agent_id> --subcmd list --notebook <name> --no-cache

# Remove source from notebook
nlm-gateway.sh source --agent <agent_id> --subcmd remove --notebook <name> --source-id <source_id>
```

**Supported source types:** URL, PDF, YouTube, plain text, file

### Artifacts
```bash
# Generate artifact (podcast, video, slides, infographic, report, mind-map, quiz, flashcards)
nlm-gateway.sh artifact --agent <agent_id> --subcmd generate --notebook <name> <artifact_type>

# Download generated artifact
nlm-gateway.sh artifact --agent <agent_id> --subcmd download --notebook <name> <artifact_id>
```

**Artifact types:** `podcast`, `video`, `slides`, `infographic`, `report`, `mind-map`, `quiz`, `flashcards`

### Research
```bash
# Run web/Drive research on a notebook
nlm-gateway.sh research --agent <agent_id> --notebook <name> --query "research topic"
```

### Notebook registry
```bash
# List all registered notebooks
nlm-gateway.sh notebooks --agent <agent_id> --subcmd list

# Get notebook details
nlm-gateway.sh notebooks --agent <agent_id> --subcmd get <name>

# Add notebook to registry (admin only)
nlm-gateway.sh notebooks --agent <agent_id> --subcmd add <name> <notebook_id> "description"

# Remove notebook from registry (admin only)
nlm-gateway.sh notebooks --agent <agent_id> --subcmd remove <name>
```

### Health check
```bash
# On-demand health check
nlm-gateway.sh health --agent <agent_id>

# Cron-friendly health check (for monitor-bot)
nlm-health.sh [agent_id]
```

## Prerequisites

- `notebooklm` CLI installed and authenticated (`~/.notebooklm/storage_state.json`)
- `jq` available on PATH
- Proxy configured (for regions where NotebookLM is blocked)
- macOS or Linux

## Installation & Authentication

### 1. Install notebooklm-py via uv
```bash
uv pip install notebooklm-py
```

### 2. Configure proxy (if required)
The skill is pre-configured with proxy `http://127.0.0.1:8234` in `config/settings.json`.
If your proxy is different, edit:
```bash
vim ~/.openclaw/skills/notebooklm/config/settings.json
# Update "proxy" field
```

### 3. Login to NotebookLM
```bash
# Ensure Surge enhanced mode is on with US node
notebooklm login
```

This will open a browser for Google authentication. The auth state is stored in `~/.notebooklm/`.

### 4. Verify installation
```bash
nlm-gateway.sh health --agent main
```

## Configuration

| File | Description |
|------|-------------|
| `config/acl.json` | Per-agent access control (roles: admin, contributor, reader, monitor, none) |
| `config/notebooks.json` | Notebook name→ID registry |
| `config/settings.json` | Rate limits, TTLs, content filter deny patterns, proxy |

### ACL Roles

| Role | Permissions |
|------|-------------|
| `admin` | Full access to all notebooks and operations |
| `contributor` | Query, source add/list, artifact generate/download, research |
| `reader` | Query, source list only |
| `monitor` | Health check, query |
| `none` | No access |

### Default Agent Permissions

- **main**: admin (full access)
- **wemedia**: contributor (media-research, memory)
- **gemini**: contributor (memory, media-research, openclaw-docs)
- **brainstorming**: contributor (memory, media-research, openclaw-docs)
- **coding/review/test/docs**: reader (openclaw-docs, memory)
- **monitor-bot**: monitor (health-check, query)

## Error Handling

All operations return structured JSON. On failure:

```json
{
  "ok": false,
  "error": "error_category",
  "message": "human readable message",
  "fallback": true,
  "retry": false
}
```

### Error Categories

| Category | Retry | Description |
|----------|-------|-------------|
| `auth_expired` | false | Authentication has expired, need re-login |
| `rate_limited` | true | Too many requests, will auto-backoff |
| `cli_error` | false | CLI command failed |
| `network_error` | true | Network issue, will retry |
| `acl_denied` | false | Permission denied |
| `notebook_not_found` | false | Notebook not registered |
| `timeout` | true | Request timed out |

### Graceful Degradation

When NotebookLM is unavailable, the skill returns a fallback response instead of crashing. Calling agents should check the `fallback` flag:

```bash
result=$(nlm-gateway.sh query --agent main --notebook memory --query "test")
if echo "$result" | jq -e '.fallback == true' >/dev/null; then
  echo "Service unavailable, using fallback"
fi
```

## Data Directory

Runtime data stored at `~/.openclaw/notebooklm-data/`:

```
~/.openclaw/notebooklm-data/
├── logs/
│   └── audit.jsonl     # Operation audit logs
├── cache/
│   ├── query/          # Query result cache
│   └── source_list/   # Source list cache
├── artifacts/          # Downloaded artifact staging
└── lock/
    └── nlm.lock       # Concurrency lock file
```

## Cron Jobs

### Health Check (every 6 hours)
```bash
openclaw cron add --name notebooklm-health --schedule "0 */6 * * *" --command "nlm-health.sh monitor-bot"
```

### Source Sync (daily at 03:00)
```bash
openclaw cron add --name notebooklm-sync --schedule "0 3 * * *" --command "nlm-sync.sh"
```

## Metrics

The skill logs all operations to `~/.openclaw/notebooklm-data/logs/audit.jsonl`:

```json
{
  "timestamp": "2026-02-28T12:00:00Z",
  "agent": "main",
  "notebook": "memory",
  "operation": "query",
  "status": "ok",
  "latency_ms": 1500,
  "error": ""
}
```
