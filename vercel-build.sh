#!/bin/bash
set -e

git clone https://github.com/flutter/flutter.git -b stable --depth 1 flutter-sdk
export PATH="$PATH:$(pwd)/flutter-sdk/bin"

flutter doctor
flutter pub get
# CanvasKit hébergé avec l'app (et non sur le CDN de Google) : indispensable
# pour que l'app puisse s'ouvrir hors connexion.
flutter build web --release --no-web-resources-cdn

# Nouvelle version du cache hors connexion à chaque déploiement
sed -i "s/__BUILD_ID__/$(date +%s)/" build/web/velqix_sw.js