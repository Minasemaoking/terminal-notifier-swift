# warp-notify

`warp-notify` is a lightweight Swift command-line tool that asks Warp Terminal to display a desktop notification by writing a standard OSC escape sequence. It does not use macOS notification frameworks, AppKit, SwiftUI, AppleScript, shell commands, or third-party packages.

The tool emits OSC 9 for message-only notifications and OSC 777 when a title is present. By default it writes directly to `/dev/tty`, falling back to stdout when `/dev/tty` cannot be opened.

## Requirements

- macOS 13 or later
- Swift 6
- Warp Terminal, or another terminal that supports these OSC notification sequences

## Installation

Build the release executable and install it in a directory on your `PATH`:

```bash
swift build -c release
install .build/release/warp-notify /usr/local/bin/warp-notify
```

An Apple Silicon Homebrew installation commonly uses `/opt/homebrew/bin`:

```bash
install .build/release/warp-notify /opt/homebrew/bin/warp-notify
```

No `sudo` is required when the destination directory is writable by your user.

## Usage

```bash
warp-notify --message "Build complete"
warp-notify --title "Build" --message "Build complete"
warp-notify -t "Build" -m "Complete"
echo "Tests passed" | warp-notify -t "Tests"
```

Use `--print` to send the generated escape sequence to stdout without opening `/dev/tty`:

```bash
warp-notify --print -t "Build" -m "Complete"
```

Available options:

```text
-t, --title <title>       Optional notification title
-m, --message <message>   Message; reads stdin when omitted and stdin is not a TTY
    --backend <backend>   auto or warp; both currently emit the same OSC sequence
    --print               Write only to stdout
    --quiet               Suppress the non-Warp environment warning
-h, --help                Show help
    --version             Show version
```

`title` and `message` are normalized before encoding: newlines become spaces, semicolons become fullwidth semicolons, control characters are removed, and surrounding whitespace is trimmed. Normal Unicode text, including Chinese and emoji, is preserved.

## Exit Codes

| Code | Meaning |
| ---: | --- |
| `0` | Success |
| `2` | CLI usage error |
| `3` | Input or encoding error |
| `4` | Output error |

## Warp Settings

For notifications to appear:

1. Enable Notifications in Warp.
2. Allow Warp to display notifications in macOS System Settings.
3. Be aware that Warp may not display a desktop notification while it is in the foreground.
4. Focus or Do Not Disturb may block the notification.

The tool checks `TERM_PROGRAM`, `TERM_PROGRAM_VERSION`, and `WARP_IS_LOCAL_SHELL_SESSION` only as hints. If the environment does not appear to be Warp, it prints a warning and still emits the standard OSC sequence. Use `--quiet` to suppress that warning.

## Notify After a Command

Add this function to your zsh configuration:

```zsh
notify-after() {
  "$@"
  local status=$?

  if (( status == 0 )); then
    warp-notify --title "Completed" --message "$*"
  else
    warp-notify --title "Failed" --message "$* (exit $status)"
  fi

  return $status
}
```

For example:

```bash
notify-after swift test
```

## xbar Notification Toggle

The repository includes an xbar menu and zsh integration for enabling or disabling notifications without opening Xcode or typing commands.

When enabled, an interactive zsh command that runs longer than the selected threshold sends a notification after it finishes. The menu supports thresholds of 5, 10, 30, or 60 seconds. Successful and failed commands use different notification titles.

The integration is not a resident service. The shell only records the command start time and checks a small state file when the prompt returns, so idle memory use is negligible.

`ShellIntegration/claude-notify-hook.sh` also adapts Claude Code's `PermissionRequest` hook to Claude Code's `terminalSequence` response format. This event fires when a permission dialog is about to be shown. The adapter is required because Claude Code hooks do not have a controlling terminal and therefore cannot write directly to `/dev/tty`. It still uses the Swift `warp-notify` executable to generate the OSC sequence and follows the same xbar enabled state.

`ShellIntegration/codex-notify-hook.sh` handles the Codex CLI legacy `notify` callback. Codex appends an `agent-turn-complete` JSON payload as the final command argument. For `codex-tui` sessions, the adapter sends the last assistant message through the Swift `warp-notify` executable. Codex CLI's legacy callback is emitted after a completed agent turn; it does not provide a permission-dialog event equivalent to Claude Code's `PermissionRequest` hook.

## Limitations

OSC notifications do not provide the richer features of the original `terminal-notifier`. This tool does not support:

- notification group management
- listing or removing notifications
- custom icons
- sender spoofing
- click-to-execute actions
- click-to-open URLs
- bypassing Focus or Do Not Disturb

Notification display remains controlled by Warp and macOS.

## Development

```bash
swift test
swift build -c release
```

The test suite uses injected input and output implementations and does not emit real desktop notifications.

## License

Apache License 2.0. See [LICENSE](LICENSE).
