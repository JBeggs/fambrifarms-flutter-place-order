@echo off
echo ========================================
echo  Creating Fambri Farms Distribution
echo ========================================
echo.

REM Check if builds exist
if not exist "builds\windows\installer" (
    echo ERROR: No builds found. Please run build_executables.bat first
    pause
    exit /b 1
)

REM Create distribution directory
if not exist "distribution" mkdir distribution
if exist "distribution\FambriFarms_Windows_Installer" rmdir /s /q "distribution\FambriFarms_Windows_Installer"
mkdir "distribution\FambriFarms_Windows_Installer"

echo Copying installation files...

REM Copy installer script
copy "install_fambri_farms.bat" "distribution\FambriFarms_Windows_Installer\"

REM Copy builds
xcopy /E /I /Y "builds\windows\installer" "distribution\FambriFarms_Windows_Installer\builds\windows\installer"

REM Create README for distribution
echo # Fambri Farms Windows Installation Package > "distribution\FambriFarms_Windows_Installer\README.md"
echo. >> "distribution\FambriFarms_Windows_Installer\README.md"
echo ## Installation Instructions >> "distribution\FambriFarms_Windows_Installer\README.md"
echo. >> "distribution\FambriFarms_Windows_Installer\README.md"
echo 1. Right-click on `install_fambri_farms.bat` >> "distribution\FambriFarms_Windows_Installer\README.md"
echo 2. Select "Run as administrator" >> "distribution\FambriFarms_Windows_Installer\README.md"
echo 3. Follow the installation prompts >> "distribution\FambriFarms_Windows_Installer\README.md"
echo. >> "distribution\FambriFarms_Windows_Installer\README.md"
echo ## What Gets Installed >> "distribution\FambriFarms_Windows_Installer\README.md"
echo. >> "distribution\FambriFarms_Windows_Installer\README.md"
echo - Place Order App (Flutter application) >> "distribution\FambriFarms_Windows_Installer\README.md"
echo - WhatsApp Crawler (Python application) >> "distribution\FambriFarms_Windows_Installer\README.md"
echo - Desktop shortcuts >> "distribution\FambriFarms_Windows_Installer\README.md"
echo - Start menu entries >> "distribution\FambriFarms_Windows_Installer\README.md"
echo. >> "distribution\FambriFarms_Windows_Installer\README.md"
echo ## First Time Setup >> "distribution\FambriFarms_Windows_Installer\README.md"
echo. >> "distribution\FambriFarms_Windows_Installer\README.md"
echo 1. Launch "Fambri Farms - Place Order" from desktop >> "distribution\FambriFarms_Windows_Installer\README.md"
echo 2. Login with your credentials >> "distribution\FambriFarms_Windows_Installer\README.md"
echo 3. Launch "Fambri Farms - WhatsApp Crawler" from desktop >> "distribution\FambriFarms_Windows_Installer\README.md"
echo 4. Scan QR code with your phone on first use >> "distribution\FambriFarms_Windows_Installer\README.md"
echo 5. Use "Process Messages" in the Place Order App >> "distribution\FambriFarms_Windows_Installer\README.md"
echo. >> "distribution\FambriFarms_Windows_Installer\README.md"
echo ## System Requirements >> "distribution\FambriFarms_Windows_Installer\README.md"
echo. >> "distribution\FambriFarms_Windows_Installer\README.md"
echo - Windows 10 or later >> "distribution\FambriFarms_Windows_Installer\README.md"
echo - Google Chrome browser >> "distribution\FambriFarms_Windows_Installer\README.md"
echo - Internet connection >> "distribution\FambriFarms_Windows_Installer\README.md"
echo - Administrator privileges for installation >> "distribution\FambriFarms_Windows_Installer\README.md"

REM Create quick start guide
echo @echo off > "distribution\FambriFarms_Windows_Installer\INSTALL.bat"
echo echo ======================================== >> "distribution\FambriFarms_Windows_Installer\INSTALL.bat"
echo echo  Fambri Farms Quick Installer >> "distribution\FambriFarms_Windows_Installer\INSTALL.bat"
echo echo ======================================== >> "distribution\FambriFarms_Windows_Installer\INSTALL.bat"
echo echo. >> "distribution\FambriFarms_Windows_Installer\INSTALL.bat"
echo echo This will install Fambri Farms system on your computer. >> "distribution\FambriFarms_Windows_Installer\INSTALL.bat"
echo echo You need administrator privileges to continue. >> "distribution\FambriFarms_Windows_Installer\INSTALL.bat"
echo echo. >> "distribution\FambriFarms_Windows_Installer\INSTALL.bat"
echo pause >> "distribution\FambriFarms_Windows_Installer\INSTALL.bat"
echo call install_fambri_farms.bat >> "distribution\FambriFarms_Windows_Installer\INSTALL.bat"

REM Create ZIP package
echo Creating ZIP package...
powershell -Command "Compress-Archive -Path 'distribution\FambriFarms_Windows_Installer\*' -DestinationPath 'distribution\FambriFarms_Windows_Setup.zip' -Force"

echo ========================================
echo  Distribution Package Created!
echo ========================================
echo.
echo Files created:
echo   distribution\FambriFarms_Windows_Setup.zip
echo   distribution\FambriFarms_Windows_Installer\ (folder)
echo.
echo To distribute:
echo 1. Send the ZIP file to users
echo 2. Users extract and run INSTALL.bat as administrator
echo 3. Applications will be installed with shortcuts
echo.
echo Package contents:
dir "distribution\FambriFarms_Windows_Installer"
echo.
pause
