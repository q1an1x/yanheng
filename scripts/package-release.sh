#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
VERSION=${VERSION:-0.1.0}
ARCH=${ARCH:-arm64}
DIST="$ROOT/dist"
APP="$ROOT/build/言衡.app"
PACKAGE_NATIVE="$ROOT/packages/yanheng-native/aarch64-apple-darwin/libYanhengNative.dylib"

mkdir -p "$DIST"

swift test --package-path "$ROOT/native"
if [ "${SKIP_NATIVE_BUILD:-0}" != "1" ]; then
  swift build -c release --package-path "$ROOT/native"
  cp "$ROOT/native/.build/release/libYanhengNative.dylib" "$PACKAGE_NATIVE"
fi

EXPECTED=$(sed -n 's/^校验和 = "\([0-9a-f]*\)"/\1/p' "$ROOT/packages/yanheng-native/言序.toml")
ACTUAL=$(shasum -a 256 "$PACKAGE_NATIVE" | awk '{print $1}')
if [ "$EXPECTED" != "$ACTUAL" ]; then
  echo "原生制品摘要已变化：$ACTUAL" >&2
  echo "请更新 packages/yanheng-native/言序.toml 后重新锁定依赖。" >&2
  exit 1
fi

yanbao check --manifest-path "$ROOT"
yanbao build --manifest-path "$ROOT" --release --bundle
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
