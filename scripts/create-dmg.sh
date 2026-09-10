#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
app_path="$project_dir/dist/ScrollSplit.app"
dmg_path="$project_dir/dist/ScrollSplit.dmg"
staging_dir=$(mktemp -d "${TMPDIR:-/tmp}/scrollsplit-dmg.XXXXXX")

cleanup() {
    rm -rf "$staging_dir"
}
trap cleanup EXIT INT TERM

if [ ! -d "$app_path" ]; then
    echo "error: build the app before creating the DMG" >&2
    exit 1
fi

ditto "$app_path" "$staging_dir/ScrollSplit.app"
ln -s /Applications "$staging_dir/Applications"

mkdir -p "$project_dir/dist"
rm -f "$dmg_path"
hdiutil create \
    -volname ScrollSplit \
    -srcfolder "$staging_dir" \
    -format UDZO \
    -ov \
    "$dmg_path"

echo "$dmg_path"
