# Installation Guide

Complete setup instructions for the Place Order Final WhatsApp order processing system.

## 📋 Prerequisites

### Required Software
- **Flutter SDK**: 3.16+ with desktop support
- **Python**: 3.8+ with pip
- **Chrome Browser**: Latest version
- **Django Backend**: Running on localhost:8000 (separate project)

### System Requirements
- **Windows**: 10+ (64-bit)
- **macOS**: 10.15+ (Catalina or later)  
- **Linux**: Ubuntu 18.04+ or equivalent
- **RAM**: 4GB minimum, 8GB recommended
- **Storage**: 2GB free space

## 🚀 Quick Installation

### 1. Install Flutter
```bash
# Check if Flutter is installed
flutter doctor

# If not installed, download from: https://docs.flutter.dev/get-started/install

# Enable desktop support
flutter config --enable-windows-desktop  # Windows
flutter config --enable-macos-desktop    # macOS
flutter config --enable-linux-desktop    # Linux
```

### 2. Install Python Dependencies
```bash
cd place-order-final/python/
pip install -r requirements.txt
```

### 3. Setup Environment Variables
Create `.env` file in `python/` directory:
```bash
# Required
TARGET_GROUP_NAME=ORDERS Restaurants

# Optional
DJANGO_API_URL=http://localhost:8000/api
WHATSAPP_TIMEOUT=60
```

### 4. Install Flutter Dependencies
```bash
cd place-order-final/
flutter pub get
```

### 5. Verify Installation
```bash
# Test Python server
cd python/
python whatsapp_server.py

# Test Flutter app (in new terminal)
flutter run -d windows  # or macos/linux
```

## 🔧 Detailed Setup

### Chrome Browser Setup
1. **Install Chrome**: Download from [chrome.google.com](https://chrome.google.com)
2. **ChromeDriver**: Usually auto-detected, but if issues occur:
   ```bash
   # macOS with Homebrew
   brew install chromedriver
   
   # Manual download from: https://chromedriver.chromium.org/
   ```

### Django Backend Setup
The system requires a Django backend running on `localhost:8000`. Ensure:
1. Django server is running
2. WhatsApp app is installed and migrated
3. API endpoints are accessible

### Environment Configuration
Create production `.env` file with:
```bash
# WhatsApp Configuration
TARGET_GROUP_NAME=Your WhatsApp Group Name
WHATSAPP_TIMEOUT=60
HEADLESS=false

# API Configuration  
DJANGO_API_URL=http://localhost:8000/api
PYTHON_SERVER_PORT=5001

# Logging
LOG_LEVEL=INFO
DEBUG=false
```

## 🧪 Verification Steps

### 1. Test Python Server
```bash
cd python/
python whatsapp_server.py

# Should show:
# 🚀 Starting WhatsApp Server...
# 📱 Make sure Chrome is installed
# 🌐 Server will run on http://localhost:5001
```

### 2. Test API Endpoints
```bash
# Health check
curl http://localhost:5001/api/health

# Should return:
# {"status": "ok", "crawler_running": false, "driver_active": false}
```

### 3. Test Flutter App
```bash
flutter run -d windows  # or your platform

# Should open desktop app with landing page
```

### 4. Test WhatsApp Integration
1. Click "Process Messages" in Flutter app
2. Click "Start WhatsApp" 
3. First time: Scan QR code with phone
4. Verify group selection works

## 🚨 Common Installation Issues

### Python Issues
```bash
# Permission errors
sudo pip install -r requirements.txt

# Virtual environment (recommended)
python -m venv venv
source venv/bin/activate  # Linux/macOS
venv\Scripts\activate     # Windows
pip install -r requirements.txt
```

### Flutter Issues
```bash
# Clean build cache
flutter clean
flutter pub get

# Check for issues
flutter doctor -v

# Platform-specific issues
flutter config --enable-windows-desktop
```

### Chrome/ChromeDriver Issues
```bash
# Check Chrome version
google-chrome --version  # Linux
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --version  # macOS

# Install matching ChromeDriver version
# Download from: https://chromedriver.chromium.org/downloads
```

### Port Conflicts
```bash
# Check if ports are in use
lsof -i :5001  # Python server
lsof -i :8000  # Django backend

# Kill processes if needed
kill -9 <PID>
```

## 🎯 Next Steps

After successful installation:
1. Read [Quick Start Guide](quick-start.md)
2. Review [System Overview](../architecture/system-overview.md)
3. Check [Troubleshooting Guide](troubleshooting.md) for common issues

## 📞 Getting Help

If you encounter issues:
1. Check [Troubleshooting Guide](troubleshooting.md)
2. Verify all prerequisites are met
3. Check system logs for error messages
4. Ensure Django backend is running and accessible
