@echo off
echo Starting Fambri Farms...
echo.

REM Change to the script's directory
cd /d "%~dp0"

REM Launch the Flutter app normally (with authentication)
REM For built executable:
start "" "build\windows\x64\runner\Release\place_order_final.exe"

REM Alternative: If you want to run from source (requires Flutter SDK)
REM flutter run -d windows --release

echo Fambri Farms launched.
echo Close this window if the app opened successfully.
pause
