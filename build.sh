#!/usr/bin/env bash
# 构建 LanguageInput.app（输入法）。需要 macOS 13+ 与 Xcode 或 Command Line Tools。
#
# 环境变量：
#   ARCHS="arm64 x86_64"   构建通用二进制（默认只构建本机架构）
#   SIGN_ID="Developer ID …" 使用指定证书签名（默认临时签名 "-"）
#   FULL_LEXICON=0|1|auto  是否联网生成完整词库（默认 auto：有 python3 且能联网就生成，失败则用随包的小词库）
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="LanguageInput"
BUILD_DIR="build"
APP="$BUILD_DIR/$APP_NAME.app"
ARCHS="${ARCHS:-$(uname -m)}"
SIGN_ID="${SIGN_ID:--}"
FULL_LEXICON="${FULL_LEXICON:-auto}"

if ! command -v swiftc >/dev/null 2>&1; then
  echo "未找到 swiftc：请先安装 Xcode 或运行 xcode-select --install" >&2
  exit 1
fi
SDK="$(xcrun --sdk macosx --show-sdk-path)"

# 1. 词库 ---------------------------------------------------------------
LEX="Resources/lexicon.tsv"
GLOSS="Resources/gloss_en.tsv"
if [ "$FULL_LEXICON" != "0" ] && [ ! -f data/lexicon.full.tsv ]; then
  if command -v python3 >/dev/null 2>&1; then
    echo "==> 生成完整词库（jieba 词频 + CC-CEDICT，需要联网）…"
    if ! python3 tools/build_lexicon.py --jieba DataSource/dict.txt --cedict DataSource/cedict_ts.u8 ; then
      echo "!! 生成完整词库失败，将使用随包附带的小词库（可稍后手动运行 tools/build_lexicon.py）" >&2
    fi
  fi
fi
if [ -f data/lexicon.full.tsv ]; then
  LEX="data/lexicon.full.tsv"
  [ -f data/gloss_en.full.tsv ] && GLOSS="data/gloss_en.full.tsv"
  echo "==> 使用完整词库：$LEX"
else
  echo "==> 使用随包附带的小词库：$LEX"
fi

# 2. 编译 ---------------------------------------------------------------
rm -rf "$APP" "$BUILD_DIR/bin"
mkdir -p "$BUILD_DIR/bin"
SOURCES=(Sources/*.swift)
BINS=()
for arch in $ARCHS; do
  echo "==> 编译 ($arch)…"
  swiftc -O -swift-version 5 -sdk "$SDK" -target "${arch}-apple-macos13.0" \
    -module-name LanguageInput -o "$BUILD_DIR/bin/$APP_NAME-$arch" "${SOURCES[@]}"
  BINS+=("$BUILD_DIR/bin/$APP_NAME-$arch")
done

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
if [ "${#BINS[@]}" -gt 1 ]; then
  lipo -create "${BINS[@]}" -output "$APP/Contents/MacOS/$APP_NAME"
else
  cp "${BINS[0]}" "$APP/Contents/MacOS/$APP_NAME"
fi

# 3. 打包资源 -------------------------------------------------------------
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp -R Resources/en.lproj Resources/zh-Hans.lproj "$APP/Contents/Resources/"
cp "$LEX" "$APP/Contents/Resources/lexicon.tsv"
cp "$GLOSS" "$APP/Contents/Resources/gloss_en.tsv"

echo "==> 生成图标…"
if swift tools/make_icon.swift "$BUILD_DIR/icons"; then
  cp "$BUILD_DIR/icons/icon.tiff" "$APP/Contents/Resources/icon.tiff"
  iconutil -c icns "$BUILD_DIR/icons/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
else
  echo "!! 图标生成失败：菜单栏图标会缺失（显示为空白/默认图标），请把上面的报错发给开发者" >&2
  exit 1
fi

# 4. 签名 ---------------------------------------------------------------
codesign --force --deep --sign "$SIGN_ID" "$APP"
echo "==> 完成：$APP"
echo "    下一步：./install.sh"
