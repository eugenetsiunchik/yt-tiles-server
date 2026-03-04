#!/usr/bin/env bash
set -euo pipefail

HOST="${1:-176.223.129.1}"
USER_NAME="${2:-root}"

IDENTITY_FILE="${SSH_IDENTITY_FILE:-$HOME/.ssh/id_rsa_yt_tiles}"

SSH_ARGS=()
if [[ -n "${IDENTITY_FILE}" && -f "${IDENTITY_FILE}" ]]; then
  SSH_ARGS+=(-i "${IDENTITY_FILE}" -o IdentitiesOnly=yes)
fi

SSH_CMD=(ssh "${SSH_ARGS[@]}" "${USER_NAME}@${HOST}")
SSH_CMD_STR="${SSH_CMD[*]}"

escape_applescript_string() {
  local s="${1:-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}

AS_SSH_CMD="$(escape_applescript_string "$SSH_CMD_STR")"

# Opens a new iTerm2 tab/window and runs SSH.
# If iTerm2 automation isn't available, falls back to running ssh in the current terminal.
if command -v osascript >/dev/null 2>&1; then
  if osascript >/dev/null <<EOF
tell application "iTerm"
  activate
  try
    if (count of windows) = 0 then
      create window with default profile
    else
      tell current window to create tab with default profile
    end if
    tell current session of current window to write text "${AS_SSH_CMD}"
  on error
    error number -128
  end try
end tell
EOF
  then
    exit 0
  fi
fi

exec "${SSH_CMD[@]}"

