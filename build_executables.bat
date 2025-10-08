@echo off
echo ========================================
echo  Building Fambri Farms Executables
echo ========================================
echo.

REM Check if Flutter is installed
flutter --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Flutter is not installed or not in PATH
    echo Please install Flutter from: https://docs.flutter.dev/get-started/install/windows
    pause
    exit /b 1
)

REM Check if Python is installed
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python from: https://www.python.org/downloads/windows/
    pause
    exit /b 1
)

echo ✅ Prerequisites check passed!
echo.

REM Create build directory
if not exist "builds" mkdir builds
if not exist "builds\windows" mkdir builds\windows

echo ========================================
echo  Building Flutter Windows App
echo ========================================
cd place-order-final

REM Install Flutter dependencies
echo Installing Flutter dependencies...
flutter pub get

REM Build Windows executable
echo Building Windows executable...
flutter build windows --release

REM Copy built app to builds directory
echo Copying Flutter app to builds directory...
xcopy /E /I /Y "build\windows\x64\runner\Release" "..\builds\windows\PlaceOrderApp"

cd ..
echo ✅ Flutter app built successfully!
echo.

echo ========================================
echo  Building WhatsApp Crawler Executable
echo ========================================

REM Setup Python environment for building
cd place-order-final\python
if not exist "build_venv" (
    echo Creating build virtual environment...
    python -m venv build_venv
)

echo Activating build environment...
call build_venv\Scripts\activate

echo Installing build dependencies...
pip install --upgrade pip
pip install -r requirements.txt
pip install pyinstaller

echo Building WhatsApp Crawler executable...
pyinstaller --onefile --windowed --name "WhatsAppCrawler" ^
    --add-data "config;config" ^
    --add-data "app;app" ^
    --hidden-import selenium ^
    --hidden-import selenium.webdriver ^
    --hidden-import selenium.webdriver.chrome ^
    --hidden-import selenium.webdriver.chrome.service ^
    --hidden-import webdriver_manager ^
    --hidden-import webdriver_manager.chrome ^
    --hidden-import flask ^
    --hidden-import flask_cors ^
    --hidden-import requests ^
    --hidden-import beautifulsoup4 ^
    main.py

echo Copying WhatsApp Crawler to builds directory...
copy "dist\WhatsAppCrawler.exe" "..\..\builds\windows\"

cd ..\..
echo ✅ WhatsApp Crawler built successfully!
echo.

echo ========================================
echo  Creating Installation Package
echo ========================================

REM Create installer directory structure
if not exist "builds\windows\installer" mkdir builds\windows\installer
if not exist "builds\windows\installer\PlaceOrderApp" mkdir builds\windows\installer\PlaceOrderApp
if not exist "builds\windows\installer\WhatsAppCrawler" mkdir builds\windows\installer\WhatsAppCrawler

REM Copy executables to installer
xcopy /E /I /Y "builds\windows\PlaceOrderApp" "builds\windows\installer\PlaceOrderApp"
copy "builds\windows\WhatsAppCrawler.exe" "builds\windows\installer\WhatsAppCrawler\"

REM Create configuration files
echo DJANGO_URL=https://fambridevops.pythonanywhere.com/api > builds\windows\installer\PlaceOrderApp\.env
echo FLUTTER_ENV=production >> builds\windows\installer\PlaceOrderApp\.env
echo ENABLE_DEBUG_LOGGING=false >> builds\windows\installer\PlaceOrderApp\.env

echo BACKEND_URL=https://fambridevops.pythonanywhere.com/api > builds\windows\installer\WhatsAppCrawler\.env
echo CHROME_DRIVER_PATH=auto >> builds\windows\installer\WhatsAppCrawler\.env
echo HEADLESS=false >> builds\windows\installer\WhatsAppCrawler\.env

echo ✅ Installation package created!
echo.

echo ========================================
echo  Build Complete!
echo ========================================
echo.
echo Files created:
echo   builds\windows\installer\PlaceOrderApp\place_order_final.exe
echo   builds\windows\installer\WhatsAppCrawler\WhatsAppCrawler.exe
echo.
echo Next steps:
echo 1. Test the executables
echo 2. Create installer with install_fambri_farms.bat
echo 3. Distribute to users
echo.
pause
