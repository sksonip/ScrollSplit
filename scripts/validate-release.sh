#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
info_plist="$project_dir/Resources/Info.plist"
expected_feed="https://github.com/sksonip/ScrollSplit/releases/latest/download/appcast.xml"
expected_interval="2592000"
tag=${1:-}
validate_built_app=${2:-0}

plist_value() {
    /usr/libexec/PlistBuddy -c "Print :$1" "$info_plist"
}

version=$(plist_value CFBundleShortVersionString)
build=$(plist_value CFBundleVersion)
feed=$(plist_value SUFeedURL)
public_key=$(plist_value SUPublicEDKey)
interval=$(plist_value SUScheduledCheckInterval)
automatic_checks=$(plist_value SUEnableAutomaticChecks)
automatic_installs=$(plist_value SUAllowsAutomaticUpdates)
signed_feed=$(plist_value SURequireSignedFeed)
verify_before_extraction=$(plist_value SUVerifyUpdateBeforeExtraction)

if ! printf '%s\n' "$version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "error: CFBundleShortVersionString must use MAJOR.MINOR.PATCH" >&2
    exit 1
fi

if ! printf '%s\n' "$build" | grep -Eq '^[1-9][0-9]*$'; then
    echo "error: CFBundleVersion must be a positive integer" >&2
    exit 1
fi

if [ -n "$tag" ] && [ "$tag" != "v$version" ]; then
    echo "error: tag $tag does not match app version v$version" >&2
    exit 1
fi

if [ "$feed" != "$expected_feed" ]; then
    echo "error: unexpected Sparkle feed URL: $feed" >&2
    exit 1
fi

case "$interval" in
    "$expected_interval"|"$expected_interval.000000") ;;
    *)
        echo "error: Sparkle checks must be scheduled every 30 days" >&2
        exit 1
        ;;
esac

if [ "$automatic_checks" != "true" ] || [ "$automatic_installs" != "false" ]; then
    echo "error: updates must be checked automatically and installed only with consent" >&2
    exit 1
fi

if [ "$signed_feed" != "true" ] || [ "$verify_before_extraction" != "true" ]; then
    echo "error: Sparkle feed and pre-extraction signature verification must be enabled" >&2
    exit 1
fi

if ! printf '%s\n' "$public_key" | grep -Eq '^[A-Za-z0-9+/]{43}=$'; then
    echo "error: SUPublicEDKey is missing or malformed" >&2
    exit 1
fi

if ! grep -q '"identity" : "sparkle"' "$project_dir/Package.resolved"; then
    echo "error: Package.resolved does not pin Sparkle" >&2
    exit 1
fi

app_path="$project_dir/dist/ScrollSplit.app"
if [ "$validate_built_app" = "1" ]; then
    [ -d "$app_path" ] || {
        echo "error: built app not found at $app_path" >&2
        exit 1
    }

    app_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$app_path/Contents/Info.plist")
    app_build=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$app_path/Contents/Info.plist")

    [ "$app_version" = "$version" ] && [ "$app_build" = "$build" ] || {
        echo "error: built app version does not match Resources/Info.plist" >&2
        exit 1
    }

    [ -d "$app_path/Contents/Frameworks/Sparkle.framework" ] || {
        echo "error: built app does not embed Sparkle.framework" >&2
        exit 1
    }

    codesign --verify --deep --strict "$app_path"
fi

echo "Release configuration valid: ScrollSplit $version ($build)"
