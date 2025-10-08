# 🖥️ Windows Setup Guide for Fambri Farms System

## 📋 **Prerequisites**

### **Required Software:**
1. **Flutter SDK 3.16+** - https://docs.flutter.dev/get-started/install/windows
2. **Python 3.11+** - https://www.python.org/downloads/windows/
3. **Google Chrome (Latest)** - https://www.google.com/chrome/
4. **Git** - https://git-scm.com/download/win
5. **Visual Studio Code** (recommended) - https://code.visualstudio.com/

### **System Requirements:**
- **Windows 10/11** (64-bit)
- **RAM:** 8GB minimum, 16GB recommended
- **Storage:** 5GB free space
- **Internet:** Stable connection for API calls

## 🚀 **AUTOMATED SETUP (RECOMMENDED)**

### **Quick Start - Run Setup Script**
```powershell
# Download the project files
# Double-click setup_windows.bat OR run in PowerShell:
.\setup_windows.bat
```

**The setup script will:**
- ✅ Check Flutter and Python installation
- ✅ Install Flutter dependencies
- ✅ Create production environment files
- ✅ Setup WhatsApp scraper with virtual environment
- ✅ Install all required Python packages

## 🔧 **Manual Setup (Advanced Users)**

### **1. Install Flutter**
```powershell
# Download Flutter SDK and extract to C:\flutter
# Add C:\flutter\bin to your PATH environment variable

# Verify installation
flutter --version
flutter doctor
```

### **2. Setup Flutter Project**
```powershell
# Navigate to project directory
cd place-order-final

# Install dependencies
flutter pub get

# Create production environment file
echo DJANGO_URL=https://fambridevops.pythonanywhere.com/api > .env
echo FLUTTER_ENV=production >> .env
echo ENABLE_DEBUG_LOGGING=false >> .env

# Run the app
flutter run -d windows
```

### **3. Build Production Executable**
```powershell
# Build Windows executable (creates .exe file)
flutter build windows --release

# OR use automated build script
..\build_executables.bat
```

## 🕷️ **WhatsApp Scraper Setup**

### **Automated Setup (Included in setup_windows.bat)**
The WhatsApp scraper is automatically configured when you run `setup_windows.bat`. It creates:
- Python virtual environment in `whatsapp-scraper/`
- Installs all required packages
- Creates configuration files
- Sets up Chrome WebDriver management

### **Manual Setup (If Needed)**
```powershell
# Create and setup scraper directory
mkdir whatsapp-scraper
cd whatsapp-scraper

# Create virtual environment
python -m venv venv
venv\Scripts\activate

# Install dependencies
pip install --upgrade pip
pip install selenium beautifulsoup4 requests python-dotenv webdriver-manager

# Create configuration
echo BACKEND_URL=https://fambridevops.pythonanywhere.com/api > .env
echo CHROME_DRIVER_PATH=auto >> .env
echo HEADLESS=false >> .env
echo TARGET_GROUP_NAME=Your_WhatsApp_Group_Name >> .env
```

### **Chrome Driver - Automatic Management**
The scraper uses `webdriver-manager` to automatically:
- ✅ Download compatible ChromeDriver version
- ✅ Handle Chrome version updates
- ✅ Manage driver installation and updates
- ✅ No manual ChromeDriver setup required!

## 🎮 **Running the Applications**

### **Flutter App**
```powershell
# Method 1: Run in development mode
cd place-order-final
flutter run -d windows

# Method 2: Run built executable
cd builds\windows\PlaceOrderApp
.\place_order_final.exe
```

### **WhatsApp Scraper**
```powershell
# Navigate to scraper directory
cd whatsapp-scraper

# Activate virtual environment
venv\Scripts\activate

# Set your WhatsApp group name (REQUIRED)
set TARGET_GROUP_NAME=Your_Group_Name_Here

# Run the scraper
python ..\crawler_test\whatsapp_crawler.py
```

**Important:** Replace `Your_Group_Name_Here` with your actual WhatsApp group name.

## 🔧 **Available Automation Scripts**

The project includes several batch scripts for easy management:

### **Setup & Installation**
- `setup_windows.bat` - Complete automated setup
- `build_executables.bat` - Build Windows executables
- `install_fambri_farms.bat` - Create installation package

### **Create Custom Launchers (Optional)**
```batch
# Flutter App Launcher - save as run_flutter_app.bat
@echo off
echo Starting Fambri Farms Flutter App...
cd /d "%~dp0place-order-final"
flutter run -d windows
pause

# WhatsApp Scraper Launcher - save as run_scraper.bat
@echo off
echo Starting WhatsApp Scraper...
cd /d "%~dp0whatsapp-scraper"
call venv\Scripts\activate
set TARGET_GROUP_NAME=Your_Group_Name_Here
python ..\crawler_test\whatsapp_crawler.py
pause
```

## 🚨 **Troubleshooting**

### **Common Issues:**

1. **Flutter not found**
   - Add `C:\flutter\bin` to PATH environment variable
   - Restart command prompt/PowerShell
   - Run `flutter doctor` to check installation

2. **Chrome driver version mismatch**
   - ✅ **SOLVED:** Uses `webdriver-manager` for automatic compatibility
   - Update Chrome browser if issues persist
   - Clear Chrome user data if login problems occur

3. **Python virtual environment issues**
   - Always activate venv: `venv\Scripts\activate`
   - Reinstall if corrupted: `rmdir /s venv` then re-run setup

4. **WhatsApp scraper not finding group**
   - Verify `TARGET_GROUP_NAME` matches exactly (case-sensitive)
   - Ensure you're logged into WhatsApp Web
   - Check group is visible in WhatsApp Web interface

5. **Network/API connection issues**
   - Verify internet connection
   - Check `https://fambridevops.pythonanywhere.com/api` is accessible
   - Disable VPN if causing connection issues

6. **Flutter app crashes on startup**
   - Check Windows Defender isn't blocking the executable
   - Run as administrator if permission issues
   - Check `.env` file exists with correct configuration

## 📱 **Mobile Development (Optional)**

### **Android Setup:**
```powershell
# Install Android Studio
# Download from: https://developer.android.com/studio

# Setup Android SDK
flutter doctor --android-licenses

# Run on Android device/emulator
flutter run -d android
```

## 🎯 **Quick Start Commands**

### **Complete Setup (Recommended)**
```powershell
# 1. Download project files to your desired location
# 2. Run automated setup
.\setup_windows.bat

# 3. Run Flutter app
cd place-order-final
flutter run -d windows

# 4. Run WhatsApp scraper (in new terminal)
cd whatsapp-scraper
venv\Scripts\activate
set TARGET_GROUP_NAME=Your_WhatsApp_Group_Name
python ..\crawler_test\whatsapp_crawler.py
```

### **Build Executables**
```powershell
# Create Windows executables for distribution
.\build_executables.bat
```

## 📊 **System Features**

### **Flutter App Capabilities:**
- ✅ **Order Processing** with always-suggestions dialog
- ✅ **Stock Management** with intelligent matching
- ✅ **Inventory Management** with search and filtering
- ✅ **Real-time WhatsApp Integration**
- ✅ **Desktop-optimized UI** with window management
- ✅ **Production-ready** with PythonAnywhere backend

### **WhatsApp Scraper Features:**
- ✅ **Automatic Chrome management** (no manual driver setup)
- ✅ **Session persistence** (stays logged in)
- ✅ **Group-specific targeting** via environment variables
- ✅ **Robust error handling** and reconnection
- ✅ **Real-time message processing** and API integration

## 📞 **Support & Next Steps**

### **Verification Checklist:**
- [ ] Flutter app launches and connects to backend
- [ ] WhatsApp scraper logs into WhatsApp Web successfully
- [ ] Target WhatsApp group is found and selected
- [ ] Messages are being processed and sent to backend
- [ ] Orders can be created through the Flutter interface

### **If you encounter issues:**
1. Run `flutter doctor` and resolve any issues
2. Verify all prerequisites are installed correctly
3. Check Windows Defender/Antivirus isn't blocking executables
4. Ensure Chrome browser is up to date
5. Verify internet connection and backend accessibility

### **Production Deployment:**
- Use `build_executables.bat` to create distributable executables
- Use `install_fambri_farms.bat` to create installation packages
- Deploy to multiple Windows machines as needed

**🎉 You're ready to run the complete Fambri Farms system on Windows!**

---
*Last updated: October 2025 - Includes latest automation scripts and Chrome driver compatibility fixes*

