#!/bin/bash
# cache.sh — Result caching for NotebookLM gateway

DATA_DIR="${DATA_DIR:-$HOME/.openclaw/notebooklm-data}"
CACHE_DIR="${CACHE_DIR:-$DATA_DIR/cache}"

_cache_key() {
  local input="$1"
  echo -n "$input" | shasum -a 256 | cut -d' ' -f1
}

cache_get() {
  local namespace="$1" key_input="$2" ttl="${3:-3600}"
  local key
  key=$(_cache_key "$key_input")
  local cache_file="$CACHE_DIR/${namespace}/${key}.json"

  if [[ ! -f "$cache_file" ]]; then
    jq -n -c '{"ok":false,"hit":false}'
    return 1
  fi

  # Check TTL
  local now file_age file_mod
  now=$(date +%s)
  if [[ "$(uname)" == "Darwin" ]]; then
    file_mod=$(stat -f %m "$cache_file" 2>/dev/null)
  else
    file_mod=$(stat -c %Y "$cache_file" 2>/dev/null)
  fi
  file_age=$(( now - file_mod ))

  if [[ $file_age -gt $ttl ]]; then
    rm -f "$cache_file"
    jq -n -c --argjson age "$file_age" '{"ok":false,"hit":false,"reason":"expired","age":$age}'
    return 1
  fi

  local data
  data=$(cat "$cache_file")
  # Validate cached data is valid JSON before embedding
  if ! echo "$data" | jq empty 2>/dev/null; then
    rm -f "$cache_file"
    jq -n -c '{"ok":false,"hit":false,"reason":"corrupt_cache"}'
    return 1
  fi
  printf '%s\n' "$data" | jq -c --argjson age "$file_age" '{ok:true,hit:true,age:$age,data:.}'
  return 0
}

cache_set() {
  local namespace="$1" key_input="$2" data="$3"
  local key
  key=$(_cache_key "$key_input")
  local dir="$CACHE_DIR/${namespace}"
  mkdir -p "$dir"
  local cache_file="$dir/${key}.json"

  echo "$data" > "$cache_file"
  jq -n -c --arg k "$key" '{"ok":true,"action":"cached","key":$k}'
  return 0
}

cache_invalidate() {
  local namespace="$1" key_input="$2"
  if [[ -n "$key_input" ]]; then
    local key
    key=$(_cache_key "$key_input")
    rm -f "$CACHE_DIR/${namespace}/${key}.json"
    jq -n -c --arg k "$key" '{"ok":true,"action":"invalidated","key":$k}'
  else
    rm -rf "$CACHE_DIR/${namespace}"
    jq -n -c --arg ns "$namespace" '{"ok":true,"action":"namespace_cleared","namespace":$ns}'
  fi
  return 0
}
