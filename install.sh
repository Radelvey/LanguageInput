#!/usr/bin/env bash
# 安装到 ~/Library/Input Methods 并登记为输入源。
set -euo pipefail
cd "$(dirname "$0")"

NAME="LanguageInput"
SRC="build/$NAME.app"
DEST_DIR="$HOME/Library/Input Methods"
DEST="$DEST_DIR/$NAME.app"

[ -d "$SRC" ] || ./build.sh

mkdir -p "$DEST_DIR"
# 清理旧名称（QingjianSwift）的安装，避免两个输入法同时存在
pkill -x QingjianSwift 2>/dev/null || true
rm -rf "$DEST_DIR/QingjianSwift.app"
pkill -x "$NAME" 2>/dev/null || true
sleep 0.5
rm -rf "$DEST"
cp -R "$SRC" "$DEST"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

"$DEST/Contents/MacOS/$NAME" --register || true

cat <<MSG

已安装到：$DEST

接下来：
  1. 打开 系统设置 ▸ 键盘 ▸ 文字输入 ▸ 输入法 ▸ 编辑…
  2. 点 ＋ ▸ 简体中文 ▸ 「语言输入法」▸ 添加
  3. 用菜单栏的输入法图标（或 Control+空格 / 🌐）切换到它
首次安装后如果列表里没有出现，请注销并重新登录一次。
设置窗口：在输入法菜单里点「语言输入法 设置…」，或运行  open "$DEST"
MSG
