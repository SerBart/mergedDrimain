@echo off
setlocal ENABLEDELAYEDEXPANSION

REM Build Flutter web and mirror into Spring Boot static resources

REM Allow overriding API base via environment, fallback to Railway URL
if "%API_BASE%"=="" (
  set API_BASE=https://mergeddrimain-production.up.railway.app
)

echo [1/3] Running flutter pub get...
pushd frontend >nul 2>&1
flutter pub get || goto :error

echo [2/3] Building Flutter web (release) with API_BASE=%API_BASE% ...
flutter build web --release --dart-define=API_BASE=%API_BASE% || goto :error
popd >nul 2>&1

echo [3/3] Mirroring build to src\main\resources\static ...
if not exist src\main\resources\static mkdir src\main\resources\static
robocopy frontend\build\web src\main\resources\static /MIR >nul

if %ERRORLEVEL% LSS 8 (
  echo Done. Static resources updated.
  exit /b 0
) else (
  goto :error
)

:error
echo Build or copy failed with error level %ERRORLEVEL%.
exit /b %ERRORLEVEL%
