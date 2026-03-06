#!/bin/bash
# lock.sh — mkdir-based file lock (macOS compatible, no flock)

LOCK_DIR="${LOCK_DIR:-$HOME/.openclaw/notebooklm-data/lock/nlm.lock}"
LOCK_TIMEOUT="${LOCK_TIMEOUT:-60}"

acquire_lock() {
  local timeout="${1:-$LOCK_TIMEOUT}"
  local start=$SECONDS
  local pid=$$

  while (( SECONDS - start < timeout )); do
    if mkdir "$LOCK_DIR" 2>/dev/null; then
      echo "$pid" > "$LOCK_DIR/pid"
      jq -n -c --argjson pid "$pid" '{"ok":true,"action":"lock_acquired","pid":$pid}'
      return 0
    fi

    # Check if holding process is still alive
    if [[ -f "$LOCK_DIR/pid" ]]; then
      local holder
      holder=$(cat "$LOCK_DIR/pid" 2>/dev/null)
      if [[ -n "$holder" ]] && ! kill -0 "$holder" 2>/dev/null; then
        # Stale lock — remove and retry
        rm -rf "$LOCK_DIR"
        continue
      fi
    fi

    sleep 1
  done

  jq -n -c --argjson t "$timeout" \
    '{"ok":false,"error":"lock_timeout","message":("Failed to acquire lock within " + ($t|tostring) + "s"),"timeout":$t}'
  return 1
}

release_lock() {
  if [[ -d "$LOCK_DIR" ]]; then
    rm -rf "$LOCK_DIR"
    jq -n -c '{"ok":true,"action":"lock_released"}'
    return 0
  fi
  jq -n -c '{"ok":true,"action":"lock_not_held","message":"No lock to release"}'
  return 0
}
