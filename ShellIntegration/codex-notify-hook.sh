#!/bin/bash

set -u

ENABLED_FILE="$HOME/.config/warp-notify/enabled"
NOTIFIER="$HOME/.local/bin/warp-notify"
PREVIOUS_NOTIFIER="$HOME/.codex/computer-use/Codex Computer Use.app/Contents/SharedSupport/SkyComputerUseClient.app/Contents/MacOS/SkyComputerUseClient"

if (( $# == 0 )); then
    exit 0
fi
payload="${!#}"

# Preserve the callback that Codex Desktop installed before this integration.
if [[ -x "$PREVIOUS_NOTIFIER" ]]; then
    "$PREVIOUS_NOTIFIER" turn-ended "$payload" >/dev/null 2>&1 &
fi

[[ -f "$ENABLED_FILE" ]] || exit 0
[[ -x "$NOTIFIER" ]] || exit 0

event_type="$(printf '%s' "$payload" | /usr/bin/jq -r '.type // ""')"
client="$(printf '%s' "$payload" | /usr/bin/jq -r '.client // ""')"

[[ "$event_type" == "agent-turn-complete" ]] || exit 0
[[ -z "$client" || "$client" == "codex-tui" ]] || exit 0

message="$(printf '%s' "$payload" | /usr/bin/jq -r \
    '."last-assistant-message" // ."input-messages"[-1] // "Codex turn completed"')"

/usr/bin/nohup "$NOTIFIER" --quiet --backend native --title "Codex Complete" --message "$message" \
    >/dev/null 2>&1 &
