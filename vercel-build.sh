#!/bin/bash
set -e

git clone https://github.com/flutter/flutter.git -b stable --depth 1 flutter-sdk
export PATH="$PATH:$(pwd)/flutter-sdk/bin"

flutter doctor
flutter pub get
flutter build web --release