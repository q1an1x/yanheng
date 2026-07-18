#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
VERSION=${VERSION:-1.0.0}
ARCH=${ARCH:-arm64}
DIST="$ROOT/dist"
APP="$ROOT/build/言衡.app"
YANXU_BIN=${YANXU_BIN:-yanxu}
YANBAO_BIN=${YANBAO_BIN:-yanbao}

mkdir -p "$DIST"
rm -rf "$APP"

YANXU_BIN="$YANXU_BIN" "$YANBAO_BIN" check --manifest-path "$ROOT"
YANXU_BIN="$YANXU_BIN" "$YANBAO_BIN" audit --manifest-path "$ROOT" --offline
"$YANXU_BIN" 编 "$ROOT" -o "$APP" --release --bundle
xattr -cr "$APP"

ZIP="$DIST/Yanheng-$VERSION-$ARCH.zip"
DMG="$DIST/Yanheng-$VERSION-$ARCH.dmg"
find "$DIST" -maxdepth 1 -type f \( -name "Yanheng-$VERSION-$ARCH.zip" -o -name "Yanheng-$VERSION-$ARCH.dmg" -o -name "SHA256SUMS" \) -delete

ditto -c -k --norsrc --keepParent "$APP" "$ZIP"

STAGING=$(mktemp -d "${TMPDIR:-/tmp}/yanheng-release.XXXXXX")
trap 'find "$STAGING" -depth -delete' EXIT
cp -R "$APP" "$STAGING/言衡.app"
ln -s /Applications "$STAGING/Applications"
hdiutil create -quiet -volname "言衡" -srcfolder "$STAGING" -ov -format UDZO "$DMG"

(
  cd "$DIST"
  shasum -a 256 "$(basename "$ZIP")" "$(basename "$DMG")" > SHA256SUMS
)

echo "发布制品："
echo "$ZIP"
echo "$DMG"
echo "$DIST/SHA256SUMS"
