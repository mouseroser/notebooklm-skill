#!/bin/bash
# nlm-health.sh — NotebookLM health check (cron-friendly)
# Reads proxy from settings.json and runs health check via gateway
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SETTINGS_FILE="$SKILL_DIR/config/settings.json"

# Load proxy if configured
NLM_PROXY=$(jq -r '.proxy // ""' "$SETTINGS_FILE" 2>/dev/null)
if [[ -n "$NLM_PROXY" ]]; then
  export https_proxy="$NLM_PROXY"
  export http_proxy="$NLM_PROXY"
fi

exec "$SCRIPT_DIR/nlm-gateway.sh" health --agent "${1:-monitor-bot}"
