#!/bin/bash
# auth.sh — NotebookLM auth validation

NOTEBOOKLM_HOME="${NOTEBOOKLM_HOME:-$HOME/.notebooklm}"
STORAGE_STATE="$NOTEBOOKLM_HOME/storage_state.json"

check_auth() {
  if [[ ! -f "$STORAGE_STATE" ]]; then
    jq -n -c --arg ss "$STORAGE_STATE" \
      '{"ok":false,"error":"auth_missing","message":("storage_state.json not found at " + $ss + ". Run: notebooklm login")}'
    return 1
  fi

  # Verify it's valid JSON
  if ! jq empty "$STORAGE_STATE" 2>/dev/null; then
    jq -n -c '{"ok":false,"error":"auth_corrupt","message":"storage_state.json is not valid JSON"}'
    return 1
  fi

  jq -n -c '{"ok":true,"message":"Auth file exists and is valid JSON"}'
  return 0
}

validate_auth() {
  # First check file exists
  local file_check
  file_check=$(check_auth)
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    echo "$file_check"
    return 1
  fi

  # Test actual auth by listing notebooks
  local output
  local exit_code
  output=$(notebooklm list --json 2>&1)
  exit_code=$?

  if [[ $exit_code -eq 0 ]]; then
    jq -n -c '{"ok":true,"message":"Auth validated successfully"}'
    return 0
  fi

  # Sanitize output for JSON embedding
  local safe_output
  safe_output=$(echo "$output" | head -5 | tr '\n' ' ')
  jq -n -c --arg msg "$safe_output" \
    '{"ok":false,"error":"auth_expired","message":("Auth validation failed: " + $msg)}'
  return 1
}
