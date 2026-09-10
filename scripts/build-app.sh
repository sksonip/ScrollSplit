#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
configuration=${CONFIGURATION:-release}
scratch_path="$project_dir/.build"
app_path="$project_dir/dist/ScrollSplit.app"
package_scratch_path="$scratch_path/app"
require_stable_signing=${REQUIRE_STABLE_SIGNING:-0}

cd "$project_dir"

signing_identity=""
if command -v codesign >/dev/null 2>&1; then
    signing_identity=${CODESIGN_IDENTITY:-}

    if [ -z "$signing_identity" ] && command -v security >/dev/null 2>&1; then
        available_identities=$(security find-identity -v -p codesigning 2>/dev/null || true)
        signing_identity=$(printf '%s\n' "$available_identities" | awk '/"Developer ID Application:/{print $2; exit}')

        if [ -z "$signing_identity" ] && [ "$configuration" = "debug" ]; then
            signing_identity=$(printf '%s\n' "$available_identities" | awk '/"Apple Development:/{print $2; exit}')
        fi
    fi

    if [ -z "$signing_identity" ]; then
        if [ "$require_stable_signing" = "1" ]; then
            echo "error: stable code signing was required, but no suitable identity was found" >&2
            echo "Install a valid signing certificate or set CODESIGN_IDENTITY, then rebuild." >&2
            exit 1
        fi

        signing_identity="-"
        echo "warning: no stable code-signing identity found; using ad-hoc signing (TCC permissions may need to be granted again after rebuild)" >&2
    fi

    if [ "$require_stable_signing" = "1" ] && [ "$signing_identity" = "-" ]; then
        echo "error: REQUIRE_STABLE_SIGNING=1 cannot be used with ad-hoc CODESIGN_IDENTITY=-" >&2
        exit 1
    fi
elif [ "$require_stable_signing" = "1" ]; then
    echo "error: stable code signing was required, but codesign is unavailable" >&2
    exit 1
fi

mkdir -p "$scratch_path/ModuleCache"

CLANG_MODULE_CACHE_PATH="$scratch_path/ModuleCache" swift build \
    --scratch-path "$package_scratch_path" \
    --configuration "$configuration" \
    --product ScrollSplit

bin_path=$(CLANG_MODULE_CACHE_PATH="$scratch_path/ModuleCache" swift build \
    --scratch-path "$package_scratch_path" \
    --configuration "$configuration" \
    --show-bin-path)
binary_path="$bin_path/ScrollSplit"
sparkle_framework_path="$bin_path/Sparkle.framework"

if [ ! -x "$binary_path" ] || [ ! -d "$sparkle_framework_path" ]; then
    echo "error: SwiftPM did not produce ScrollSplit and Sparkle.framework" >&2
    exit 1
fi

rm -rf "$app_path"
mkdir -p "$app_path/Contents/MacOS"
mkdir -p "$app_path/Contents/Resources"
mkdir -p "$app_path/Contents/Frameworks"
cp "$project_dir/Resources/Info.plist" "$app_path/Contents/Info.plist"
cp "$binary_path" "$app_path/Contents/MacOS/ScrollSplit"
cp "$project_dir/Resources/ScrollSplit.icns" "$app_path/Contents/Resources/ScrollSplit.icns"
ditto "$sparkle_framework_path" "$app_path/Contents/Frameworks/Sparkle.framework"

if [ -n "$signing_identity" ]; then
    codesign --force --sign "$signing_identity" --timestamp=none "$app_path"
    echo "Signing identity: $signing_identity"
fi

codesign --verify --deep --strict "$app_path"

echo "$app_path"
