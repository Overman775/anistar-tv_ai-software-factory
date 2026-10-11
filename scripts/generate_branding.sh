#!/usr/bin/env bash
set -euo pipefail

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_root"
command -v sips >/dev/null || { echo "This asset export requires macOS sips." >&2; exit 1; }
command -v fvm >/dev/null || { echo "Install FVM first." >&2; exit 1; }

fvm dart run flutter_launcher_icons
fvm dart run flutter_native_splash:create

# Android TV needs 80dp legacy icons; the package defaults to mobile 48dp.
densities=(mdpi hdpi xhdpi xxhdpi xxxhdpi)
icons=(80 120 160 240 320)
widths=(160 240 320 480 640)
heights=(90 135 180 270 360)
for index in "${!densities[@]}"; do
  directory="android/app/src/main/res/mipmap-${densities[$index]}"
  sips -z "${icons[$index]}" "${icons[$index]}" lib/packages/ui_kit/assets/images/anistar_launcher.png \
    --out "$directory/launcher_icon.png" >/dev/null
  sips -z "${heights[$index]}" "${widths[$index]}" lib/packages/ui_kit/assets/images/anistar_tv_banner.png \
    --out "$directory/ic_banner.png" >/dev/null
done
echo "Exported launcher icons, adaptive icon, Android TV banners and splash screens."
