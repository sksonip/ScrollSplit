#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
configuration=${CONFIGURATION:-release}
scratch_path="$project_dir/.build"
app_path="$project_dir/dist/ScrollSplit.app"
binary_path="$scratch_path/direct/ScrollSplit"
require_stable_signing=${REQUIRE_STABLE_SIGNING:-0}

cd "$project_dir"

signing_identity=""
if command -v codesign >/dev/null 2>&1; then
    signing_identity=${CODESIGN_IDENTITY:-}

    if [ -z "$signing_identity" ] && command -v security >/dev/null 2>&1; then
        available_identities=$(security find-identity -v -p codesigning 2>/dev/null || true)
        signing_identity=$(printf '%s\n' "$available_identities" | awk '/"Apple Development:/{print $2; exit}')

        if [ -z "$signing_identity" ]; then
            signing_identity=$(printf '%s\n' "$available_identities" | awk '/"Developer ID Application:/{print $2; exit}')
        fi
    fi

    if [ -z "$signing_identity" ]; then
        if [ "$require_stable_signing" = "1" ]; then
            echo "error: stable code signing was required, but no Apple Development or Developer ID Application identity was found" >&2
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

mkdir -p "$scratch_path/ModuleCache" "$scratch_path/direct"

optimization="-O"
if [ "$configuration" = "debug" ]; then
    optimization="-Onone"
fi

CLANG_MODULE_CACHE_PATH="$scratch_path/ModuleCache" xcrun swiftc \
    -parse-as-library \
    "$optimization" \
    -target "$(uname -m)-apple-macosx13.0" \
    -framework AppKit \
    -framework ApplicationServices \
    -framework CoreGraphics \
    -framework ServiceManagement \
    Sources/ScrollSplit/App/ApplicationLaunchContext.swift \
    Sources/ScrollSplit/App/AppDelegate.swift \
    Sources/ScrollSplit/App/ReverseScrollingController.swift \
    Sources/ScrollSplit/Settings/AppSettings.swift \
    Sources/ScrollSplit/Scrolling/ScrollSourceClassifier.swift \
    Sources/ScrollSplit/Scrolling/ScrollEventTap.swift \
    Sources/ScrollSplit/Services/PermissionService.swift \
    Sources/ScrollSplit/Services/LoginItemService.swift \
    Sources/ScrollSplit/UI/SettingsWindowController.swift \
    -o "$binary_path"

mkdir -p "$app_path/Contents/MacOS"
mkdir -p "$app_path/Contents/Resources"
cp "$project_dir/Resources/Info.plist" "$app_path/Contents/Info.plist"
cp "$binary_path" "$app_path/Contents/MacOS/ScrollSplit"
cp "$project_dir/Resources/ScrollSplit.icns" "$app_path/Contents/Resources/ScrollSplit.icns"

if [ -n "$signing_identity" ]; then
    codesign --force --sign "$signing_identity" --timestamp=none "$app_path"
    echo "Signing identity: $signing_identity"
fi

echo "$app_path"
