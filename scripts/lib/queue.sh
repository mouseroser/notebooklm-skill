#!/bin/bash
# queue.sh — Rate limiting + content filtering for NotebookLM gateway

SKILL_DIR="${SKILL_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
DATA_DIR="${DATA_DIR:-$HOME/.openclaw/notebooklm-data}"
SETTINGS_FILE="${SETTINGS_FILE:-$SKILL_DIR/config/settings.json}"
RATE_LOG="$DATA_DIR/logs/rate.log"
RATE_LOCK_DIR="$DATA_DIR/lock/rate.lock"

# --- Rate Limiting ---
# NOTE: rate_check uses its own lock (RATE_LOCK_DIR) to protect rate.log
# reads/writes from concurrent access. The outer global lock in nlm-gateway.sh
# serializes CLI calls but may not cover all rate_check call sites.

_rate_lock_acquire() {
  local timeout=5 start=$SECONDS
  while (( SECONDS - start < timeout )); do
    if mkdir "$RATE_LOCK_DIR" 2>/dev/null; then
      echo $$ > "$RATE_LOCK_DIR/pid"
      return 0
    fi
    # Stale lock check
    if [[ -f "$RATE_LOCK_DIR/pid" ]]; then
      local holder
      holder=$(cat "$RATE_LOCK_DIR/pid" 2>/dev/null)
      if [[ -n "$holder" ]] && ! kill -0 "$holder" 2>/dev/null; then
        rm -rf "$RATE_LOCK_DIR"
        continue
      fi
    fi
    sleep 0.1
  done
  return 1
}

_rate_lock_release() {
  rm -rf "$RATE_LOCK_DIR" 2>/dev/null
}

rate_check() {
  local agent_id="${1:-unknown}"
  mkdir -p "$(dirname "$RATE_LOG")" "$(dirname "$RATE_LOCK_DIR")"
  touch "$RATE_LOG"

  # Acquire rate-specific lock to protect rate.log
  if ! _rate_lock_acquire; then
    jq -n -c '{"ok":false,"error":"rate_lock_timeout","message":"Could not acquire rate lock"}'
    return 1
  fi
  # Ensure lock is released on return
  trap '_rate_lock_release' RETURN

  local now
  now=$(date +%s)
  local per_minute per_hour
  per_minute=$(jq -r '.rate_limit_per_minute // 10' "$SETTINGS_FILE" 2>/dev/null)
  per_hour=$(jq -r '.rate_limit_per_hour // 100' "$SETTINGS_FILE" 2>/dev/null)

  # Clean old entries (>1h)
  local cutoff_hour=$(( now - 3600 ))
  local tmp="${RATE_LOG}.tmp.$$"
  awk -v cutoff="$cutoff_hour" -F'|' '$1 >= cutoff' "$RATE_LOG" > "$tmp" 2>/dev/null
  mv "$tmp" "$RATE_LOG"

  # Count last minute
  local cutoff_min=$(( now - 60 ))
  local count_min
  count_min=$(awk -v cutoff="$cutoff_min" -F'|' '$1 >= cutoff' "$RATE_LOG" | wc -l | tr -d ' ')

  if [[ $count_min -ge $per_minute ]]; then
    jq -n -c --argjson count "$count_min" --argjson limit "$per_minute" \
      '{"ok":false,"error":"rate_limited","window":"minute","count":$count,"limit":$limit}'
    return 1
  fi

  # Count last hour
  local count_hour
  count_hour=$(wc -l < "$RATE_LOG" | tr -d ' ')

  if [[ $count_hour -ge $per_hour ]]; then
    jq -n -c --argjson count "$count_hour" --argjson limit "$per_hour" \
      '{"ok":false,"error":"rate_limited","window":"hour","count":$count,"limit":$limit}'
    return 1
  fi

  # Record this request
  echo "${now}|${agent_id}" >> "$RATE_LOG"
  jq -n -c --argjson mc "$(( count_min + 1 ))" --argjson hc "$(( count_hour + 1 ))" \
    '{"ok":true,"minute_count":$mc,"hour_count":$hc}'
  return 0
}

# --- Content Filter ---
# Fix #1: Normalize path with realpath to prevent ../ and symlink bypass

content_filter() {
  local path="$1"
  if [[ -z "$path" ]]; then
    jq -n -c '{"ok":false,"error":"missing_param","message":"Path required for content filter"}'
    return 1
  fi

  # Expand ~ then normalize with realpath to prevent traversal/symlink bypass
  local expanded_path="${path/#\~/$HOME}"
  # Use realpath if the path exists, otherwise use a logical normalization
  if [[ -e "$expanded_path" ]]; then
    expanded_path=$(realpath "$expanded_path" 2>/dev/null || echo "$expanded_path")
  else
    # For non-existent paths, resolve .. components logically
    # Python fallback for logical normalization on macOS
    expanded_path=$(python3 -c "import os,sys; print(os.path.normpath(sys.argv[1]))" "$expanded_path" 2>/dev/null || echo "$expanded_path")
  fi

  # Load deny patterns from settings
  local patterns
  patterns=$(jq -r '.content_filter_deny[]' "$SETTINGS_FILE" 2>/dev/null)

  if [[ -z "$patterns" ]]; then
    jq -n -c --arg p "$path" '{"ok":true,"allowed":true,"path":$p}'
    return 0
  fi

  while IFS= read -r pattern; do
    # Expand ~ in pattern too
    local expanded_pattern="${pattern/#\~/$HOME}"
    if echo "$expanded_path" | grep -qE "$expanded_pattern" 2>/dev/null; then
      jq -n -c --arg p "$path" --arg mp "$pattern" \
        '{"ok":true,"allowed":false,"path":$p,"matched_pattern":$mp,"reason":"content_filter_denied"}'
      return 1
    fi
  done <<< "$patterns"

  jq -n -c --arg p "$path" '{"ok":true,"allowed":true,"path":$p}'
  return 0
}

# --- Retry with exponential backoff (Fix #3) ---

retry_with_backoff() {
  local max_retries base_delay max_delay cmd
  max_retries=$(jq -r '.retry_max // 3' "$SETTINGS_FILE" 2>/dev/null)
  base_delay=$(jq -r '.retry_backoff_base // 2' "$SETTINGS_FILE" 2>/dev/null)
  max_delay=$(jq -r '.retry_backoff_max // 120' "$SETTINGS_FILE" 2>/dev/null)
  shift 0
  cmd=("$@")
  local attempt=0 delay result
  while (( attempt < max_retries )); do
    result=$("${cmd[@]}" 2>&1) && { echo "$result"; return 0; }
    attempt=$((attempt + 1))
    delay=$(( base_delay ** attempt ))
    (( delay > max_delay )) && delay=$max_delay
    sleep "$delay"
  done
  echo "$result"
  return 1
}
