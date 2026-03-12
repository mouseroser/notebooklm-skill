#!/bin/bash
# acl.sh — Access control for NotebookLM gateway

SKILL_DIR="${SKILL_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
ACL_FILE="${ACL_FILE:-$SKILL_DIR/config/acl.json}"

acl_error_json() {
  local error="$1" message="$2" detail="${3:-}"
  jq -n -c \
    --arg err "$error" \
    --arg msg "$message" \
    --arg det "$detail" \
    '{"ok":false,"allowed":false,"error":$err,"message":$msg,"detail":$det}'
}

acl_denied_json() {
  local agent_id="$1" role="$2" operation="$3" notebook="$4" reason="$5"
  local message="Permission denied"

  if [[ -n "$operation" && -n "$notebook" ]]; then
    message="Permission denied for operation '$operation' on notebook '$notebook'"
  elif [[ -n "$operation" ]]; then
    message="Permission denied for operation '$operation'"
  elif [[ -n "$notebook" ]]; then
    message="Permission denied for notebook '$notebook'"
  fi

  jq -n -c \
    --arg a "$agent_id" \
    --arg r "$role" \
    --arg op "$operation" \
    --arg nb "$notebook" \
    --arg rs "$reason" \
    --arg msg "$message" \
    '{"ok":false,"allowed":false,"error":"acl_denied","message":$msg,"detail":$rs,"agent":$a,"role":$r,"operation":$op,"notebook":$nb,"reason":$rs}'
}

check_acl() {
  local agent_id="$1" notebook="$2" operation="$3"

  if [[ -z "$agent_id" ]]; then
    acl_error_json "missing_param" "agent_id required" "check_acl"
    return 1
  fi

  if [[ ! -f "$ACL_FILE" ]]; then
    acl_error_json "acl_missing" "ACL config not found" "$ACL_FILE"
    return 1
  fi

  # Look up agent, fall back to _default
  local agent_entry
  agent_entry=$(jq -c --arg a "$agent_id" '.agents[$a] // .agents["_default"] // null' "$ACL_FILE" 2>/dev/null)

  if [[ -z "$agent_entry" || "$agent_entry" == "null" ]]; then
    acl_denied_json "$agent_id" "" "$operation" "$notebook" "no_acl_entry"
    return 1
  fi

  local role
  role=$(echo "$agent_entry" | jq -r '.role')

  # Admin role = allow all
  if [[ "$role" == "admin" ]]; then
    jq -n -c --arg a "$agent_id" '{"ok":true,"allowed":true,"agent":$a,"role":"admin","reason":"admin_bypass"}'
    return 0
  fi

  # None role = deny all
  if [[ "$role" == "none" ]]; then
    acl_denied_json "$agent_id" "$role" "$operation" "$notebook" "role_denied"
    return 1
  fi

  # Check operation permission
  if [[ -n "$operation" ]]; then
    local op_allowed
    op_allowed=$(echo "$agent_entry" | jq --arg op "$operation" '[.operations[] | select(. == $op)] | length')
    if [[ "$op_allowed" -eq 0 ]]; then
      acl_denied_json "$agent_id" "$role" "$operation" "$notebook" "operation_denied"
      return 1
    fi
  fi

  # Check notebook permission
  if [[ -n "$notebook" ]]; then
    local nb_access
    nb_access=$(echo "$agent_entry" | jq -r '.notebooks')
    if [[ "$nb_access" == '"*"' || "$nb_access" == '*' ]]; then
      # Wildcard — all notebooks allowed
      :
    else
      local nb_allowed
      nb_allowed=$(echo "$agent_entry" | jq --arg nb "$notebook" '[.notebooks[] | select(. == $nb)] | length')
      if [[ "$nb_allowed" -eq 0 ]]; then
        acl_denied_json "$agent_id" "$role" "$operation" "$notebook" "notebook_denied"
        return 1
      fi
    fi
  fi

  jq -n -c --arg a "$agent_id" --arg r "$role" '{"ok":true,"allowed":true,"agent":$a,"role":$r}'
  return 0
}
