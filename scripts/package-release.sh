#!/bin/zsh
set -euo pipefail

root_dir="${0:A:h:h}"
version="${1:-${APP_VERSION:-1.0.0}}"
archive_name="TuiDotApp-${version}-macOS.zip"

APP_VERSION="$version" "$root_dir/scripts/build-app.sh"

cd "$root_dir/dist"
rm -f "$archive_name" "$archive_name.sha256"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent TuiDotApp.app "$archive_name"
/usr/bin/shasum -a 256 "$archive_name" > "$archive_name.sha256"
codesign --verify --deep --strict --verbose=2 TuiDotApp.app

echo "$root_dir/dist/$archive_name"
