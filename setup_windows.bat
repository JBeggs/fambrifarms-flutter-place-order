@echo off
echo ========================================
echo  Fambri Farms Windows Setup Script
echo ========================================
echo.

REM Check if Flutter is installed
flutter --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Flutter is not installed or not in PATH
    echo Please install Flutter from: https://docs.flutter.dev/get-started/install/windows
    echo Add C:\flutter\bin to your PATH environment variable
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

echo ✅ Flutter and Python are installed!
echo.

REM Setup Flutter app
echo Setting up Flutter app...
if exist "place-order-final" (
    cd place-order-final
    echo Installing Flutter dependencies...
    flutter pub get
    
    echo Creating production environment file...
    echo DJANGO_URL=https://fambridevops.pythonanywhere.com/api > .env
    echo FLUTTER_ENV=production >> .env
    echo ENABLE_DEBUG_LOGGING=false >> .env
    
    cd ..
    echo ✅ Flutter app setup complete!
) else (
    echo ⚠️  place-order-final directory not found
    echo Please make sure the Flutter project is in the current directory
)

echo.

REM Setup WhatsApp scraper
echo Setting up WhatsApp scraper...
if not exist "whatsapp-scraper" mkdir whatsapp-scraper
cd whatsapp-scraper

echo Creating Python virtual environment...
python -m venv venv

echo Activating virtual environment...
call venv\Scripts\activate

echo Installing Python dependencies...
pip install --upgrade pip
pip install selenium beautifulsoup4 requests python-dotenv webdriver-manager

echo Creating configuration file...
echo BACKEND_URL=https://fambridevops.pythonanywhere.com/api > .env
echo CHROME_DRIVER_PATH=auto >> .env
echo HEADLESS=false >> .env

cd ..
echo ✅ WhatsApp scraper setup complete!

echo.
echo ========================================
echo  Setup Complete!
echo ========================================
echo.
echo To run the Flutter app:
echo   cd place-order-final
echo   flutter run -d windows
echo.
echo To run the WhatsApp scraper:
echo   cd whatsapp-scraper
echo   venv\Scripts\activate
echo   python whatsapp_scraper_windows.py
echo.
echo See WINDOWS_SETUP_GUIDE.md for detailed instructions.
echo.
pause

