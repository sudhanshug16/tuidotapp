#!/bin/zsh
set -euo pipefail

root_dir="${0:A:h:h}"
configuration="${CONFIGURATION:-release}"
app_version="${APP_VERSION:-0.1.1}"
build_number="${BUILD_NUMBER:-1}"
signing_identity="${CODE_SIGN_IDENTITY:--}"
app_dir="$root_dir/dist/TuiDotApp.app"
contents_dir="$app_dir/Contents"
macos_dir="$contents_dir/MacOS"
resources_dir="$contents_dir/Resources"

cd "$root_dir"
swift build -c "$configuration"

bin_dir="$(swift build -c "$configuration" --show-bin-path)"
binary_path="$bin_dir/tuidotapp"
if [[ "$app_dir" != "$root_dir/dist/TuiDotApp.app" ]]; then
    echo "Refusing to clear unexpected app path: $app_dir" >&2
    exit 1
fi
rm -rf "$app_dir"
mkdir -p "$macos_dir" "$resources_dir"
install -m 755 "$binary_path" "$macos_dir/TuiDotApp"

resource_bundle="$(find "$bin_dir" -maxdepth 1 -type d -name '*TuiDotApp.bundle' -print -quit)"
if [[ -n "$resource_bundle" ]]; then
    /usr/bin/ditto "$resource_bundle" "$resources_dir/${resource_bundle:t}"
fi
"$root_dir/scripts/create-icns.sh" \
    "$root_dir/Sources/TuiDotApp/Resources/TuiDotAppIcon.png" \
    "$resources_dir/AppIcon.icns"

plutil -create xml1 "$contents_dir/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleDevelopmentRegion string en' "$contents_dir/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleExecutable string TuiDotApp' "$contents_dir/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleIdentifier string app.tui.desktop' "$contents_dir/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleInfoDictionaryVersion string 6.0' "$contents_dir/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleName string TuiDotApp' "$contents_dir/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleDisplayName string TuiDotApp' "$contents_dir/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string AppIcon' "$contents_dir/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundlePackageType string APPL' "$contents_dir/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $app_version" "$contents_dir/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $build_number" "$contents_dir/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :LSMinimumSystemVersion string 14.0' "$contents_dir/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :NSHighResolutionCapable bool true' "$contents_dir/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :NSQuitAlwaysKeepsWindows bool false' "$contents_dir/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleURLTypes array' "$contents_dir/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleURLTypes:0 dict' "$contents_dir/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleURLTypes:0:CFBundleURLName string app.tui.desktop.launch' "$contents_dir/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleURLTypes:0:CFBundleTypeRole string Viewer' "$contents_dir/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleURLTypes:0:CFBundleURLSchemes array' "$contents_dir/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string tuidotapp' "$contents_dir/Info.plist"

codesign_args=(--force --deep --sign "$signing_identity")
if [[ "$signing_identity" != "-" ]]; then
    codesign_args+=(--options runtime --timestamp)
fi
codesign "${codesign_args[@]}" "$app_dir"
echo "$app_dir"
