#!/bin/zsh
set -euo pipefail

if (( $# != 2 )); then
    echo "usage: create-icns.sh SOURCE_IMAGE DESTINATION.icns" >&2
    exit 64
fi

source_image="$1"
destination="$2"
temporary_root="$(mktemp -d /tmp/tuidotapp-icon.XXXXXX)"
iconset="$temporary_root/AppIcon.iconset"
trap 'rm -rf "$temporary_root"' EXIT
mkdir -p "$iconset"

render() {
    local pixels="$1"
    local name="$2"
    /usr/bin/sips -s format png -z "$pixels" "$pixels" "$source_image" --out "$iconset/$name" >/dev/null
}

render 16 icon_16x16.png
render 32 icon_16x16@2x.png
render 32 icon_32x32.png
render 64 icon_32x32@2x.png
render 128 icon_128x128.png
render 256 icon_128x128@2x.png
render 256 icon_256x256.png
render 512 icon_256x256@2x.png
render 512 icon_512x512.png
render 1024 icon_512x512@2x.png

/usr/bin/iconutil -c icns "$iconset" -o "$destination"
