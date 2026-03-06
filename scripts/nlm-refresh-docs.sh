#!/bin/bash
set -uo pipefail
# nlm-refresh-docs.sh — OpenClaw 文档全量同步
# 功能：比对变化、增量导入新页面、清除已下线页面、刷新已有源、跑升级

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SETTINGS_FILE="$SKILL_DIR/config/settings.json"
DATA_DIR="${DATA_DIR:-$HOME/.openclaw/notebooklm-data}"
LOG_FILE="$DATA_DIR/logs/refresh.log"
CORE_DOCS="$SKILL_DIR/config/core-docs.txt"

mkdir -p "$(dirname "$LOG_FILE")"

# Load proxy
NLM_PROXY=$(jq -r '.proxy // ""' "$SETTINGS_FILE" 2>/dev/null)
if [[ -n "$NLM_PROXY" ]]; then
  export https_proxy="$NLM_PROXY"
  export http_proxy="$NLM_PROXY"
fi

# Get notebook ID
source "$SCRIPT_DIR/lib/registry.sh"
NB_ID=$(registry_get "openclaw-docs" | jq -r '.notebook.id // empty')
if [[ -z "$NB_ID" ]]; then
  echo '{"ok":false,"error":"notebook_not_found"}'
  exit 1
fi

TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "[$TS] === Starting full sync ===" >> "$LOG_FILE"

# --- Step 0: 跑 OpenClaw 升级 ---
echo "[$TS] Step 0: Checking OpenClaw updates..." >> "$LOG_FILE"
UPDATE_OUT=$(openclaw update --check 2>&1 || true)
if echo "$UPDATE_OUT" | grep -qi "available\|new version\|update"; then
  echo "[$TS] Update available, running upgrade..." >> "$LOG_FILE"
  openclaw update 2>&1 >> "$LOG_FILE" || true
  UPGRADED=true
else
  echo "[$TS] Already up to date" >> "$LOG_FILE"
  UPGRADED=false
fi

# --- Step 1: 获取最新 sitemap ---
echo "[$TS] Step 1: Fetching sitemap..." >> "$LOG_FILE"
SITEMAP_URLS=$(curl -sS "https://docs.openclaw.ai/sitemap.xml" 2>/dev/null \
  | grep -o '<loc>[^<]*</loc>' | sed 's/<loc>//;s/<\/loc>//' \
  | grep "zh-CN" \
  | grep -E "/(start|concepts|install|gateway|channels|cli|tools|automation|nodes|reference|security|plugins)(/[^/]+)?$" \
  | grep -v "/https:" | sort -u)
SITEMAP_COUNT=$(echo "$SITEMAP_URLS" | wc -l | tr -d ' ')
echo "[$TS] Sitemap: $SITEMAP_COUNT zh-CN pages found" >> "$LOG_FILE"

# --- Step 2: 获取当前 notebook 源 ---
SOURCES_JSON=$(notebooklm source list -n "$NB_ID" --json 2>&1)
CURRENT_URLS=$(echo "$SOURCES_JSON" | jq -r '.sources[] | select(.url != null) | .url' | sort -u)
CURRENT_COUNT=$(echo "$CURRENT_URLS" | grep -c "." || echo 0)
TOTAL_SOURCES=$(echo "$SOURCES_JSON" | jq '.sources | length')
echo "[$TS] Current: $CURRENT_COUNT URL sources, $TOTAL_SOURCES total" >> "$LOG_FILE"

# --- Step 3: 比对变化 ---
NEW_URLS=$(comm -23 <(echo "$SITEMAP_URLS") <(echo "$CURRENT_URLS"))
DEAD_URLS=$(comm -13 <(echo "$SITEMAP_URLS") <(echo "$CURRENT_URLS"))
NEW_COUNT=$(echo "$NEW_URLS" | wc -l | tr -d ' ')
DEAD_COUNT=$(echo "$DEAD_URLS" | wc -l | tr -d ' ')
echo "[$TS] Diff: +$NEW_COUNT new, -$DEAD_COUNT removed" >> "$LOG_FILE"

# --- Step 4: 清除已下线页面 ---
REMOVED=0
if [[ $DEAD_COUNT -gt 0 ]]; then
  echo "$DEAD_URLS" | while IFS= read -r url; do
    [[ -z "$url" ]] && continue
    SRC_ID=$(echo "$SOURCES_JSON" | jq -r --arg u "$url" '.sources[] | select(.url == $u) | .id')
    if [[ -n "$SRC_ID" ]]; then
      notebooklm source delete "$SRC_ID" -n "$NB_ID" 2>&1 > /dev/null && {
        echo "[$TS] REMOVED: $url" >> "$LOG_FILE"
        REMOVED=$((REMOVED + 1))
      } || {
        echo "[$TS] REMOVE_FAIL: $url" >> "$LOG_FILE"
      }
      sleep 1
    fi
  done
fi

# --- Step 5: 增量导入新页面（不超过 50 源上限）---
ADDED=0
SLOTS=$((50 - TOTAL_SOURCES + REMOVED))
if [[ $NEW_COUNT -gt 0 && $SLOTS -gt 0 ]]; then
  echo "$NEW_URLS" | head -n "$SLOTS" | while IFS= read -r url; do
    [[ -z "$url" ]] && continue
    RESULT=$(notebooklm source add "$url" -n "$NB_ID" --json 2>&1)
    TITLE=$(echo "$RESULT" | jq -r '.source.title // "failed"')
    echo "[$TS] ADDED: $TITLE ($url)" >> "$LOG_FILE"
    ADDED=$((ADDED + 1))
    sleep 2
  done
fi

# --- Step 6: 刷新已有 URL 源 ---
REFRESHED=0
REFRESH_FAIL=0
echo "$CURRENT_URLS" | while IFS= read -r url; do
  [[ -z "$url" ]] && continue
  # 跳过已删除的
  echo "$DEAD_URLS" | grep -qF "$url" && continue
  SRC_ID=$(echo "$SOURCES_JSON" | jq -r --arg u "$url" '.sources[] | select(.url == $u) | .id')
  if [[ -n "$SRC_ID" ]]; then
    notebooklm source refresh "$SRC_ID" -n "$NB_ID" 2>&1 > /dev/null && {
      REFRESHED=$((REFRESHED + 1))
    } || {
      echo "[$TS] REFRESH_FAIL: $url" >> "$LOG_FILE"
      REFRESH_FAIL=$((REFRESH_FAIL + 1))
    }
    sleep 2
  fi
done

echo "[$TS] === Sync complete: upgraded=$UPGRADED added=$ADDED removed=$REMOVED refreshed=$REFRESHED failed=$REFRESH_FAIL ===" >> "$LOG_FILE"
echo "{\"ok\":true,\"upgraded\":$UPGRADED,\"added\":$ADDED,\"removed\":$REMOVED,\"refreshed\":$REFRESHED,\"failed\":$REFRESH_FAIL}"
