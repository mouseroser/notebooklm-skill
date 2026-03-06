#!/bin/bash
# registry.sh — Notebook registry operations

SKILL_DIR="${SKILL_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
REGISTRY_FILE="${REGISTRY_FILE:-$SKILL_DIR/config/notebooks.json}"

_registry_ensure() {
  if [[ ! -f "$REGISTRY_FILE" ]]; then
    echo '{"notebooks":{}}' > "$REGISTRY_FILE"
  fi
}

registry_list() {
  _registry_ensure
  local result
  result=$(jq -c '{ok: true, count: (.notebooks | length), notebooks: .notebooks}' "$REGISTRY_FILE" 2>/dev/null)
  if [[ $? -ne 0 ]]; then
    jq -n -c '{"ok":false,"error":"registry_read_error","message":"Failed to read registry"}'
    return 1
  fi
  echo "$result"
  return 0
}

registry_get() {
  local name="$1"
  if [[ -z "$name" ]]; then
    jq -n -c '{"ok":false,"error":"missing_param","message":"Notebook name required"}'
    return 1
  fi
  _registry_ensure
  local entry
  entry=$(jq -c --arg n "$name" '.notebooks[$n] // null' "$REGISTRY_FILE")
  if [[ "$entry" == "null" ]]; then
    jq -n -c --arg n "$name" '{"ok":false,"error":"not_found","message":("Notebook " + $n + " not in registry")}'
    return 1
  fi
  jq -n -c --arg n "$name" --argjson e "$entry" '{ok: true, name: $n, notebook: $e}'
  return 0
}

registry_add() {
  local name="$1" id="$2" desc="${3:-}"
  if [[ -z "$name" || -z "$id" ]]; then
    jq -n -c '{"ok":false,"error":"missing_param","message":"Name and ID required"}'
    return 1
  fi
  _registry_ensure
  local tmp="${REGISTRY_FILE}.tmp.$$"
  if jq --arg n "$name" --arg i "$id" --arg d "$desc" \
    '.notebooks[$n] = {"id": $i, "description": $d, "added": (now | todate)}' \
    "$REGISTRY_FILE" > "$tmp" 2>/dev/null; then
    mv "$tmp" "$REGISTRY_FILE"
    jq -n -c --arg n "$name" --arg i "$id" '{"ok":true,"action":"added","name":$n,"id":$i}'
    return 0
  fi
  rm -f "$tmp"
  jq -n -c '{"ok":false,"error":"registry_write_error","message":"Failed to update registry"}'
  return 1
}

registry_remove() {
  local name="$1"
  if [[ -z "$name" ]]; then
    jq -n -c '{"ok":false,"error":"missing_param","message":"Notebook name required"}'
    return 1
  fi
  _registry_ensure
  local exists
  exists=$(jq --arg n "$name" '.notebooks | has($n)' "$REGISTRY_FILE")
  if [[ "$exists" != "true" ]]; then
    jq -n -c --arg n "$name" '{"ok":false,"error":"not_found","message":("Notebook " + $n + " not in registry")}'
    return 1
  fi
  local tmp="${REGISTRY_FILE}.tmp.$$"
  if jq --arg n "$name" 'del(.notebooks[$n])' "$REGISTRY_FILE" > "$tmp" 2>/dev/null; then
    mv "$tmp" "$REGISTRY_FILE"
    jq -n -c --arg n "$name" '{"ok":true,"action":"removed","name":$n}'
    return 0
  fi
  rm -f "$tmp"
  jq -n -c '{"ok":false,"error":"registry_write_error","message":"Failed to update registry"}'
  return 1
}
