#!/bin/bash

# <xbar.title>Warp Terminal Notifications</xbar.title>
# <xbar.version>v2.0.0</xbar.version>
# <xbar.author>Timothy</xbar.author>
# <xbar.desc>Enable or disable notifications for long-running terminal commands.</xbar.desc>

set -u

CONFIG_DIR="$HOME/.config/warp-notify"
ENABLED_FILE="$CONFIG_DIR/enabled"
THRESHOLD_FILE="$CONFIG_DIR/threshold"
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

mkdir -p "$CONFIG_DIR"

set_threshold() {
    printf '%s\n' "$1" > "$THRESHOLD_FILE"
}

case "${1:-}" in
    enable)
        : > "$ENABLED_FILE"
        exit 0
        ;;
    disable)
        rm -f "$ENABLED_FILE"
        exit 0
        ;;
    threshold)
        set_threshold "${2:-10}"
        exit 0
        ;;
    open-project)
        /usr/bin/open "/Users/Timothy/Projects/terminal-notifier-swift"
        exit $?
        ;;
esac

threshold="10"
if [[ -f "$THRESHOLD_FILE" ]]; then
    read -r threshold < "$THRESHOLD_FILE"
fi

if [[ -f "$ENABLED_FILE" ]]; then
    echo "Terminal 通知：開 | color=green"
    echo "---"
    echo "✓ 通知已啟用 | color=green"
    echo "關閉通知 | bash='$SCRIPT_PATH' param1=disable terminal=false refresh=true"
else
    echo "Terminal 通知：關 | color=gray"
    echo "---"
    echo "通知目前已關閉 | color=gray"
    echo "開啟通知 | bash='$SCRIPT_PATH' param1=enable terminal=false refresh=true"
fi

echo "---"
echo "通知門檻：${threshold} 秒"

for seconds in 5 10 30 60; do
    if [[ "$threshold" == "$seconds" ]]; then
        echo "-- ✓ ${seconds} 秒 | color=green"
    else
        echo "-- ${seconds} 秒 | bash='$SCRIPT_PATH' param1=threshold param2=$seconds terminal=false refresh=true"
    fi
done

echo "---"
echo "超過門檻的指令完成後才通知 | color=gray size=11"
echo "成功與失敗會使用不同標題 | color=gray size=11"
echo "用 Finder 開啟專案 | bash='$SCRIPT_PATH' param1=open-project terminal=false"
echo "重新整理 | refresh=true"
