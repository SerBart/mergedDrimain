#!/bin/bash

# Build script for Flutter frontend
set -e

echo "Building Flutter frontend..."

# Default API base URL (can be overridden via environment variable)
API_BASE=${API_BASE:-"http://localhost:8080"}

# Navigate to frontend directory
cd frontend

# Install dependencies
echo "Running flutter pub get..."
flutter pub get

# Build for web in release mode
echo "Building Flutter web (release) with API_BASE=$API_BASE..."
flutter build web --release --dart-define=API_BASE="$API_BASE"

# Clean static resources directory
echo "Cleaning Spring Boot static resources..."
rm -rf ../src/main/resources/static/*

# Copy Flutter web build to Spring Boot static resources
echo "Copying Flutter web build to static resources..."
cp -r build/web/* ../src/main/resources/static/

echo "Flutter frontend build complete!"
echo "Static resources updated in src/main/resources/static/"