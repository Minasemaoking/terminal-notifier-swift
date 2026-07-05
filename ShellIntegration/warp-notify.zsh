# Notification hook for long-running interactive zsh commands.

autoload -Uz add-zsh-hook
zmodload zsh/datetime

typeset -g WARP_NOTIFY_COMMAND=""
typeset -gi WARP_NOTIFY_STARTED_AT=0

warp_notify_preexec() {
  WARP_NOTIFY_COMMAND="$1"
  WARP_NOTIFY_STARTED_AT=$EPOCHSECONDS
}

warp_notify_precmd() {
  local command_status=$?
  local enabled_file="$HOME/.config/warp-notify/enabled"
  local threshold_file="$HOME/.config/warp-notify/threshold"
  local notifier="$HOME/.local/bin/warp-notify"
  local threshold=10
  local elapsed
  local title
  local message

  if [[ -z "$WARP_NOTIFY_COMMAND" || $WARP_NOTIFY_STARTED_AT -le 0 ]]; then
    return
  fi

  elapsed=$(( EPOCHSECONDS - WARP_NOTIFY_STARTED_AT ))

  # Clear state before invoking the notifier so this prompt is handled once.
  local completed_command="$WARP_NOTIFY_COMMAND"
  WARP_NOTIFY_COMMAND=""
  WARP_NOTIFY_STARTED_AT=0

  [[ -f "$enabled_file" ]] || return
  [[ -x "$notifier" ]] || return

  if [[ -r "$threshold_file" ]]; then
    read -r threshold < "$threshold_file"
  fi
  [[ "$threshold" == <-> ]] || threshold=10
  (( elapsed >= threshold )) || return

  if (( command_status == 0 )); then
    title="Completed"
    message="$completed_command (${elapsed}s)"
  else
    title="Failed"
    message="$completed_command (exit $command_status, ${elapsed}s)"
  fi

  "$notifier" --quiet --backend native --title "$title" --message "$message" \
    >/dev/null 2>&1 &!
}

add-zsh-hook preexec warp_notify_preexec
add-zsh-hook precmd warp_notify_precmd
