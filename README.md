# warp-notify

`warp-notify` is a lightweight Swift command-line tool with two notification backends. The default native backend briefly launches an AppKit floating panel in the lower-right corner of the current display. The Warp backend writes a standard OSC escape sequence to the terminal.

The native panel joins all macOS Spaces, does not activate or focus itself, closes after about five seconds, and then the process exits. It is not a resident menu bar application. The project does not use SwiftUI, AppleScript, Objective-C runtime calls, or third-party packages.

## Requirements

- macOS 13 or later
- Swift 6
- AppKit for the default native panel
- Warp Terminal, or another OSC-compatible terminal, only for `--backend warp`

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
    --backend <backend>   auto, native, or warp; auto defaults to native
    --print               Write the OSC sequence to stdout without showing a panel
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

## Backends

`auto` and `native` show the AppKit panel. The panel is positioned on the display containing the mouse pointer, joins all Spaces, and is designed to remain visible when another desktop is active.

`warp` emits OSC 9 or OSC 777. For Warp notifications to appear:

1. Enable Notifications in Warp.
2. Allow Warp to display notifications in macOS System Settings.
3. Be aware that Warp may not display a desktop notification while it is in the foreground.
4. Focus or Do Not Disturb may block the notification.

The Warp backend checks `TERM_PROGRAM`, `TERM_PROGRAM_VERSION`, and `WARP_IS_LOCAL_SHELL_SESSION` only as hints. If the environment does not appear to be Warp, it prints a warning and still emits the standard OSC sequence. Use `--quiet` to suppress that warning.

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

`ShellIntegration/claude-notify-hook.sh` handles Claude Code's `PermissionRequest` event. It launches the native panel when a permission dialog is about to be shown and follows the same xbar enabled state.

`ShellIntegration/codex-notify-hook.sh` handles the Codex CLI legacy `notify` callback. Codex appends an `agent-turn-complete` JSON payload as the final command argument. For `codex-tui` sessions, the adapter sends the last assistant message through the Swift `warp-notify` executable. Codex CLI's legacy callback is emitted after a completed agent turn; it does not provide a permission-dialog event equivalent to Claude Code's `PermissionRequest` hook.

## Limitations

This tool does not support:

- notification group management
- listing or removing notifications
- custom icons
- sender spoofing
- click-to-execute actions
- click-to-open URLs
- interactive notification actions

The native panel is a custom transient window, not a Notification Center notification. It will not appear in notification history. macOS can still limit window visibility in some locked-screen or secure full-screen contexts.

## Development

```bash
swift test
swift build -c release
```

The test suite uses injected input and output implementations and does not emit real desktop notifications.

## License

Apache License 2.0. See [LICENSE](LICENSE).
