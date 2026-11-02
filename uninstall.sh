#!/usr/bin/env bash
# 卸载输入法。加 --purge 同时删除本机数据（统计、词汇本、输入习惯、缓存）。
set -euo pipefail
NAME="LanguageInput"
pkill -x "$NAME" 2>/dev/null || true
pkill -x QingjianSwift 2>/dev/null || true
rm -rf "$HOME/Library/Input Methods/QingjianSwift.app"   # 旧名称
rm -rf "$HOME/Library/Input Methods/$NAME.app"
echo "已移除 ~/Library/Input Methods/$NAME.app（请在 系统设置 ▸ 键盘 ▸ 输入法 里删掉对应条目）"
if [ "${1:-}" = "--purge" ]; then
  rm -rf "$HOME/Library/Application Support/LanguageInput" "$HOME/Library/Application Support/QingjianSwift"
  defaults delete com.languageinput.inputmethod.LanguageInput 2>/dev/null || true
  security delete-generic-password -s "LanguageInput.ai" -a "api-key" 2>/dev/null || true
  echo "已删除本机数据与保存的密钥"
fi
