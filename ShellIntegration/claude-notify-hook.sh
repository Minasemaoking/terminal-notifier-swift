#!/bin/bash

set -u

ENABLED_FILE="$HOME/.config/warp-notify/enabled"
NOTIFIER="$HOME/.local/bin/warp-notify"

input="$(cat)"

[[ -f "$ENABLED_FILE" ]] || exit 0
[[ -x "$NOTIFIER" ]] || exit 0

event_name="$(printf '%s' "$input" | /usr/bin/jq -r '.hook_event_name // ""')"

if [[ "$event_name" == "PermissionRequest" ]]; then
    tool_name="$(printf '%s' "$input" | /usr/bin/jq -r '.tool_name // "Tool"')"
    detail="$(printf '%s' "$input" | /usr/bin/jq -r \
        '.tool_input.description // .tool_input.command // .tool_input.file_path // "Approval required"')"
    title="Claude Code Permission"
    message="$tool_name: $detail"
else
    title="$(printf '%s' "$input" | /usr/bin/jq -r '.title // "Claude Code"')"
    message="$(printf '%s' "$input" | /usr/bin/jq -r '.message // "Claude Code needs your attention"')"
fi

sequence="$($NOTIFIER --quiet --print --title "$title" --message "$message")" || exit 1

/usr/bin/jq -n --arg terminalSequence "$sequence" '{terminalSequence: $terminalSequence}'
