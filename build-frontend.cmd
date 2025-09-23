@echo off
setlocal enabledelayedexpansion
pushd frontend
flutter build web --release --dart-define=API_BASE=
popd

set STATIC_DIR=src\main\resources\static
if not exist %STATIC_DIR% mkdir %STATIC_DIR%

for /f %%i in ('dir /b %STATIC_DIR%') do (
  rmdir /s /q "%STATIC_DIR%\%%i" 2>nul
  del /q "%STATIC_DIR%\%%i" 2>nul
)

xcopy /e /i /y frontend\build\web %STATIC_DIR% >nul

echo Frontend built and copied to %STATIC_DIR%