#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v flutter >/dev/null 2>&1; then
  echo "❌ Flutter not found. Install Flutter first: https://docs.flutter.dev/get-started/install"
  exit 1
fi

echo "🚀 Generating missing Flutter platform folders..."
flutter create . --project-name ghostchat --org com.ghostchat.app

echo "📦 Installing dependencies..."
flutter pub get

echo "✅ Base app scaffold is ready."
echo "Next: run 'flutterfire configure' and then 'flutter run'"
