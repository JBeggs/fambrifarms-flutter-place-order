@echo off
echo ========================================
echo  Fambri Farms System Installer
echo ========================================
echo.
echo This installer will set up:
echo   • Place Order App (Flutter)
echo   • WhatsApp Crawler
echo   • Desktop shortcuts
echo   • Start menu entries
echo.
pause

REM Get installation directory
set "INSTALL_DIR=%PROGRAMFILES%\FambriFarms"
echo Installing to: %INSTALL_DIR%
echo.

REM Check for admin privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: This installer requires administrator privileges
    echo Please right-click and select "Run as administrator"
    pause
    exit /b 1
)

REM Create installation directory
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"
if not exist "%INSTALL_DIR%\PlaceOrderApp" mkdir "%INSTALL_DIR%\PlaceOrderApp"
if not exist "%INSTALL_DIR%\WhatsAppCrawler" mkdir "%INSTALL_DIR%\WhatsAppCrawler"

echo ========================================
echo  Installing Place Order App
echo ========================================

REM Copy Place Order App
echo Copying Place Order App files...
xcopy /E /I /Y "builds\windows\installer\PlaceOrderApp\*" "%INSTALL_DIR%\PlaceOrderApp\"

REM Create Place Order App launcher
echo @echo off > "%INSTALL_DIR%\PlaceOrderApp\launch.bat"
echo cd /d "%%~dp0" >> "%INSTALL_DIR%\PlaceOrderApp\launch.bat"
echo start "" "place_order_final.exe" >> "%INSTALL_DIR%\PlaceOrderApp\launch.bat"

echo ========================================
echo  Installing WhatsApp Crawler
echo ========================================

REM Copy WhatsApp Crawler
echo Copying WhatsApp Crawler files...
copy "builds\windows\installer\WhatsAppCrawler\WhatsAppCrawler.exe" "%INSTALL_DIR%\WhatsAppCrawler\"
copy "builds\windows\installer\WhatsAppCrawler\.env" "%INSTALL_DIR%\WhatsAppCrawler\"

REM Create WhatsApp Crawler launcher
echo @echo off > "%INSTALL_DIR%\WhatsAppCrawler\launch.bat"
echo cd /d "%%~dp0" >> "%INSTALL_DIR%\WhatsAppCrawler\launch.bat"
echo start "" "WhatsAppCrawler.exe" >> "%INSTALL_DIR%\WhatsAppCrawler\launch.bat"

echo ========================================
echo  Creating Desktop Shortcuts
echo ========================================

REM Create desktop shortcuts
powershell -Command "$WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%USERPROFILE%\Desktop\Fambri Farms - Place Order.lnk'); $Shortcut.TargetPath = '%INSTALL_DIR%\PlaceOrderApp\place_order_final.exe'; $Shortcut.WorkingDirectory = '%INSTALL_DIR%\PlaceOrderApp'; $Shortcut.IconLocation = '%INSTALL_DIR%\PlaceOrderApp\place_order_final.exe'; $Shortcut.Description = 'Fambri Farms Place Order Application'; $Shortcut.Save()"

powershell -Command "$WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%USERPROFILE%\Desktop\Fambri Farms - WhatsApp Crawler.lnk'); $Shortcut.TargetPath = '%INSTALL_DIR%\WhatsAppCrawler\WhatsAppCrawler.exe'; $Shortcut.WorkingDirectory = '%INSTALL_DIR%\WhatsAppCrawler'; $Shortcut.IconLocation = '%INSTALL_DIR%\WhatsAppCrawler\WhatsAppCrawler.exe'; $Shortcut.Description = 'Fambri Farms WhatsApp Crawler'; $Shortcut.Save()"

echo ========================================
echo  Creating Start Menu Entries
echo ========================================

REM Create start menu folder
if not exist "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Fambri Farms" mkdir "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Fambri Farms"

REM Create start menu shortcuts
powershell -Command "$WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%APPDATA%\Microsoft\Windows\Start Menu\Programs\Fambri Farms\Place Order App.lnk'); $Shortcut.TargetPath = '%INSTALL_DIR%\PlaceOrderApp\place_order_final.exe'; $Shortcut.WorkingDirectory = '%INSTALL_DIR%\PlaceOrderApp'; $Shortcut.IconLocation = '%INSTALL_DIR%\PlaceOrderApp\place_order_final.exe'; $Shortcut.Description = 'Fambri Farms Place Order Application'; $Shortcut.Save()"

powershell -Command "$WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%APPDATA%\Microsoft\Windows\Start Menu\Programs\Fambri Farms\WhatsApp Crawler.lnk'); $Shortcut.TargetPath = '%INSTALL_DIR%\WhatsAppCrawler\WhatsAppCrawler.exe'; $Shortcut.WorkingDirectory = '%INSTALL_DIR%\WhatsAppCrawler'; $Shortcut.IconLocation = '%INSTALL_DIR%\WhatsAppCrawler\WhatsAppCrawler.exe'; $Shortcut.Description = 'Fambri Farms WhatsApp Crawler'; $Shortcut.Save()"

REM Create uninstaller
echo @echo off > "%INSTALL_DIR%\uninstall.bat"
echo echo Uninstalling Fambri Farms System... >> "%INSTALL_DIR%\uninstall.bat"
echo rmdir /s /q "%INSTALL_DIR%" >> "%INSTALL_DIR%\uninstall.bat"
echo del "%USERPROFILE%\Desktop\Fambri Farms - Place Order.lnk" >> "%INSTALL_DIR%\uninstall.bat"
echo del "%USERPROFILE%\Desktop\Fambri Farms - WhatsApp Crawler.lnk" >> "%INSTALL_DIR%\uninstall.bat"
echo rmdir /s /q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Fambri Farms" >> "%INSTALL_DIR%\uninstall.bat"
echo echo Fambri Farms System uninstalled successfully! >> "%INSTALL_DIR%\uninstall.bat"
echo pause >> "%INSTALL_DIR%\uninstall.bat"

powershell -Command "$WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%APPDATA%\Microsoft\Windows\Start Menu\Programs\Fambri Farms\Uninstall Fambri Farms.lnk'); $Shortcut.TargetPath = '%INSTALL_DIR%\uninstall.bat'; $Shortcut.WorkingDirectory = '%INSTALL_DIR%'; $Shortcut.Description = 'Uninstall Fambri Farms System'; $Shortcut.Save()"

echo ========================================
echo  Installation Complete!
echo ========================================
echo.
echo Fambri Farms System has been installed successfully!
echo.
echo You can now access the applications from:
echo   • Desktop shortcuts
echo   • Start Menu ^> Fambri Farms
echo.
echo Applications installed:
echo   • Place Order App: %INSTALL_DIR%\PlaceOrderApp\
echo   • WhatsApp Crawler: %INSTALL_DIR%\WhatsAppCrawler\
echo.
echo To uninstall, use: Start Menu ^> Fambri Farms ^> Uninstall
echo.
echo First time setup:
echo 1. Run "Place Order App" - login with your credentials
echo 2. Run "WhatsApp Crawler" - scan QR code on first use
echo 3. Use "Process Messages" in Place Order App to connect both
echo.
pause
