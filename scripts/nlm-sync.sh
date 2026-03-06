#!/bin/bash
set -euo pipefail
# nlm-sync.sh — Source sync (cron-friendly)
# Refreshes source list caches for all registered notebooks

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REGISTRY="$SKILL_DIR/config/notebooks.json"

agent_id="${1:-main}"

if [[ ! -f "$REGISTRY" ]]; then
  echo '{"ok":false,"error":"no_registry","message":"notebooks.json not found"}'
  exit 1
fi

notebooks=$(jq -r '.notebooks | keys[]' "$REGISTRY" 2>/dev/null)
if [[ -z "$notebooks" ]]; then
  echo '{"ok":true,"synced":0,"message":"No notebooks registered"}'
  exit 0
fi

count=0
errors=0
while IFS= read -r nb; do
  result=$("$SCRIPT_DIR/nlm-gateway.sh" source --agent "$agent_id" --subcmd list --notebook "$nb" --no-cache 2>&1) || true
  if [[ $(echo "$result" | jq -r '.ok' 2>/dev/null) == "true" ]]; then
    count=$((count + 1))
  else
    errors=$((errors + 1))
  fi
done <<< "$notebooks"

jq -c -n --argjson s "$count" --argjson e "$errors" '{"ok":true,"synced":$s,"errors":$e}'
