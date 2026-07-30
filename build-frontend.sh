#!/bin/bash
set -e

echo "Building Flutter frontend..."

API_BASE=${API_BASE:-"http://localhost:8080"}

cd frontend

echo "Running flutter pub get..."
flutter pub get

echo "Building Flutter web (release) with API_BASE=$API_BASE..."
flutter build web -v --release --dart-define=API_BASE="$API_BASE"

echo "Cleaning Spring Boot static resources..."
rm -rf ../src/main/resources/static/*

echo "Copying Flutter web build to static resources..."
cp -r build/web/* ../src/main/resources/static/

echo "Flutter frontend build complete!"
echo "Static resources updated in src/main/resources/static/"