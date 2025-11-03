@echo off
REM Bulk Stock Take Desktop Shortcut
REM This launches the app directly to bulk stock take mode

echo Starting Bulk Stock Take...
echo.

REM Change to the app directory
cd /d "%~dp0"

REM Launch the Flutter app with bulk stock take argument
start "" "build\windows\x64\runner\Release\place_order_final.exe" --bulk-stock-take

REM Alternative: If you want to run from source (requires Flutter SDK)
REM flutter run -d windows --release --dart-define=BULK_STOCK_TAKE=true

echo Bulk Stock Take launched.
echo Close this window if the app opened successfully.
pause
