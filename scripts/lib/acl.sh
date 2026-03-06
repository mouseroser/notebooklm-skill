#!/bin/bash
# acl.sh — Access control for NotebookLM gateway

SKILL_DIR="${SKILL_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
ACL_FILE="${ACL_FILE:-$SKILL_DIR/config/acl.json}"

check_acl() {
  local agent_id="$1" notebook="$2" operation="$3"

  if [[ -z "$agent_id" ]]; then
    jq -n -c '{"ok":false,"allowed":false,"error":"missing_param","message":"agent_id required"}'
    return 1
  fi

  if [[ ! -f "$ACL_FILE" ]]; then
    jq -n -c '{"ok":false,"allowed":false,"error":"acl_missing","message":"ACL config not found"}'
    return 1
  fi

  # Look up agent, fall back to _default
  local agent_entry
  agent_entry=$(jq -c --arg a "$agent_id" '.agents[$a] // .agents["_default"] // null' "$ACL_FILE" 2>/dev/null)

  if [[ -z "$agent_entry" || "$agent_entry" == "null" ]]; then
    jq -n -c --arg a "$agent_id" '{"ok":true,"allowed":false,"agent":$a,"reason":"no_acl_entry"}'
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
    jq -n -c --arg a "$agent_id" '{"ok":true,"allowed":false,"agent":$a,"role":"none","reason":"role_denied"}'
    return 1
  fi

  # Check operation permission
  if [[ -n "$operation" ]]; then
    local op_allowed
    op_allowed=$(echo "$agent_entry" | jq --arg op "$operation" '[.operations[] | select(. == $op)] | length')
    if [[ "$op_allowed" -eq 0 ]]; then
      jq -n -c --arg a "$agent_id" --arg r "$role" --arg op "$operation" \
        '{"ok":true,"allowed":false,"agent":$a,"role":$r,"reason":"operation_denied","operation":$op}'
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
        jq -n -c --arg a "$agent_id" --arg r "$role" --arg nb "$notebook" \
          '{"ok":true,"allowed":false,"agent":$a,"role":$r,"reason":"notebook_denied","notebook":$nb}'
        return 1
      fi
    fi
  fi

  jq -n -c --arg a "$agent_id" --arg r "$role" '{"ok":true,"allowed":true,"agent":$a,"role":$r}'
  return 0
}
