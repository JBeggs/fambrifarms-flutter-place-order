# Troubleshooting Guide

## 🚨 Common Issues & Solutions

### System Status Issues

#### "Feature Not Working as Expected"
**Issue**: Some documented features may not work exactly as described
**Solution**: 
- Check the [Implementation Status](../../README.md#-implementation-status) section
- Features marked as "🔄 Partially Implemented" may need additional configuration
- Report specific issues with detailed steps to reproduce

#### "WhatsApp Integration Inconsistent"
**Issue**: WhatsApp scraping works sometimes but fails other times
**Solution**:
- WhatsApp Web interface changes can affect scraping
- Try restarting the Python server: `python main.py`
- Clear Chrome session: Delete `whatsapp-session/` folder and re-authenticate
- Check Chrome version compatibility

### Development & Testing Issues

#### "Testing Documentation Doesn't Match Code"
**Issue**: Some test specifications reference missing components
**Solution**:
- Focus on testing implemented features first
- Use the actual code in `python/app/core/whatsapp_crawler.py` as reference
- Test basic message scraping before advanced features

#### "Pricing System Not Responding"
**Issue**: Intelligent pricing features show errors
**Solution**:
- UI is complete but backend integration is being validated
- Use basic product management features while pricing system is refined
- Check Django backend logs for specific errors

Common issues and solutions for the Place Order Final system.

## 🚨 Quick Diagnostics

### System Health Check
```bash
# 1. Check Python server
curl http://localhost:5001/api/health

# 2. Check Django backend  
curl http://localhost:8000/api/whatsapp/health/

# 3. Check Flutter app
flutter doctor -v
```

### Log Locations
- **Python Server**: Console output with `[PY]` prefix
- **Flutter App**: Debug console with `[DJANGO]` and `[WHATSAPP]` prefixes
- **Django Backend**: `backend/django_logs` file
- **Chrome Debug**: `python/whatsapp-session/chrome_debug.log`

## 🐍 Python Server Issues

### Server Won't Start

**Error**: `Address already in use`
```bash
# Find process using port 5001
lsof -i :5001  # macOS/Linux
netstat -ano | findstr :5001  # Windows

# Kill the process
kill -9 <PID>  # macOS/Linux
taskkill /PID <PID> /F  # Windows
```

**Error**: `ModuleNotFoundError: No module named 'flask'`
```bash
# Install dependencies
pip install -r python/requirements.txt

# Or use virtual environment (recommended)
python -m venv venv
source venv/bin/activate  # macOS/Linux
venv\Scripts\activate     # Windows
pip install -r requirements.txt
```

**Error**: `TARGET_GROUP_NAME environment variable is required`
```bash
# Create .env file in python/ directory
echo "TARGET_GROUP_NAME=ORDERS Restaurants" > python/.env

# Or export directly
export TARGET_GROUP_NAME="ORDERS Restaurants"
```

### ChromeDriver Issues

**Error**: `ChromeDriver not found`
```bash
# macOS with Homebrew
brew install chromedriver

# Manual installation
# 1. Check Chrome version: chrome://version/
# 2. Download matching ChromeDriver from: https://chromedriver.chromium.org/
# 3. Add to PATH or place in project directory
```

**Error**: `Chrome binary not found`
```bash
# Verify Chrome installation
which google-chrome  # Linux
ls "/Applications/Google Chrome.app"  # macOS
where chrome  # Windows

# Install Chrome if missing
# Download from: https://www.google.com/chrome/
```

**Error**: `Session not created: This version of ChromeDriver only supports Chrome version X`
```bash
# Update Chrome browser to latest version
# Download matching ChromeDriver version
# Or use webdriver-manager (auto-updates):
pip install webdriver-manager
```

## 🦋 Flutter App Issues

### App Won't Start

**Error**: `Flutter SDK not found`
```bash
# Install Flutter SDK
# Download from: https://docs.flutter.dev/get-started/install

# Add to PATH
export PATH="$PATH:/path/to/flutter/bin"

# Verify installation
flutter doctor
```

**Error**: `Desktop support not enabled`
```bash
# Enable desktop support
flutter config --enable-windows-desktop  # Windows
flutter config --enable-macos-desktop    # macOS
flutter config --enable-linux-desktop    # Linux

# Verify
flutter devices
```

**Error**: `Package dependencies not resolved`
```bash
# Clean and reinstall dependencies
flutter clean
flutter pub get

# If still failing, delete pubspec.lock and retry
rm pubspec.lock
flutter pub get
```

### Build Issues

**Error**: `Build failed with exception`
```bash
# Clean build cache
flutter clean
flutter pub get

# Rebuild
flutter run -d windows  # or your platform

# For detailed error info
flutter run -v
```

**Error**: `No connected devices`
```bash
# Check available devices
flutter devices

# For desktop development, should show:
# Windows (desktop) • windows • windows-x64
# macOS (desktop) • macos • darwin-x64
# Linux (desktop) • linux • linux-x64
```

## 📱 WhatsApp Integration Issues

### QR Code Problems

**Issue**: QR code not appearing
```bash
# Check Chrome browser opens
# Verify WhatsApp Web loads: https://web.whatsapp.com
# Clear Chrome cache and cookies for WhatsApp Web
# Try incognito mode
```

**Issue**: QR code expired
```bash
# Delete session data
rm -rf python/whatsapp-session/

# Restart Python server
python python/whatsapp_server.py

# Scan new QR code
```

### Group Selection Issues

**Issue**: Target group not found
```bash
# Verify group name exactly matches
echo $TARGET_GROUP_NAME

# Check you have access to the group
# Verify group exists and has recent messages
# Try manual search in WhatsApp Web
```

**Issue**: Group selected but no messages
```bash
# Check group has recent messages
# Verify you have permission to view messages
# Try scrolling up in WhatsApp Web to load more messages
# Check if group is archived or muted
```

### Message Scraping Problems

**Issue**: No messages scraped
```bash
# Check WhatsApp Web interface loaded properly
# Verify group is selected (header shows group name)
# Check for JavaScript errors in Chrome console (F12)
# Try refreshing WhatsApp Web page
```

**Issue**: Messages appear but content is empty
```bash
# WhatsApp Web selectors may have changed
# Check Chrome console for errors
# Verify messages are visible in WhatsApp Web
# Try different message types (text vs media)
```

## 🔗 API Connection Issues

### Django Backend Connection

**Error**: `Connection refused to localhost:8000`
```bash
# Verify Django server is running
curl http://localhost:8000/api/whatsapp/health/

# Start Django server if needed
cd backend/
python manage.py runserver

# Check for port conflicts
lsof -i :8000
```

**Error**: `CORS errors in Flutter app`
```bash
# Verify django-cors-headers is installed
pip install django-cors-headers

# Check CORS settings in Django settings.py
CORS_ALLOW_ALL_ORIGINS = True  # Development only
CORS_ALLOWED_ORIGINS = [
    "http://localhost:3000",  # Flutter web
]
```

### Python Server Connection

**Error**: `Failed to connect to Python server`
```bash
# Verify Python server is running
curl http://localhost:5001/api/health

# Check Flutter API service configuration
# Verify baseUrl in lib/services/api_service.dart:
# static const String whatsappBaseUrl = 'http://127.0.0.1:5001/api';
```

## 🔧 Performance Issues

### Slow Message Scraping

**Symptoms**: Scraping takes >30 seconds
```bash
# Reduce message load by scrolling less
# Check Chrome memory usage
# Close other Chrome tabs
# Restart Chrome browser
# Check internet connection speed
```

### High Memory Usage

**Symptoms**: System becomes slow, >1GB RAM usage
```bash
# Restart Python server periodically
# Close unused Chrome tabs
# Monitor Chrome processes:
ps aux | grep chrome  # macOS/Linux
tasklist | findstr chrome  # Windows

# Kill excess Chrome processes if needed
```

### Flutter App Lag

**Symptoms**: UI becomes unresponsive
```bash
# Run in release mode for better performance
flutter run --release -d windows

# Check for memory leaks in debug console
# Reduce message list size
# Restart Flutter app
```

## 🔍 Debugging Tips

### Enable Debug Logging

**Python Server**:
```python
# In whatsapp_server.py, add:
import logging
logging.basicConfig(level=logging.DEBUG)
```

**Flutter App**:
```dart
// In main.dart, add:
import 'package:flutter/foundation.dart';

void main() {
  if (kDebugMode) {
    print('Debug mode enabled');
  }
  // ... rest of main
}
```

### Chrome DevTools

1. Open Chrome DevTools (F12) while WhatsApp Web is open
2. Check Console tab for JavaScript errors
3. Check Network tab for failed requests
4. Use Elements tab to inspect WhatsApp Web structure

### API Testing

```bash
# Test Python server endpoints
curl -X POST http://localhost:5001/api/whatsapp/start
curl http://localhost:5001/api/messages
curl http://localhost:5001/api/health

# Test Django backend endpoints  
curl http://localhost:8000/api/whatsapp/messages/
curl http://localhost:8000/api/whatsapp/health/
```

## 📞 Getting Help

### Before Asking for Help

1. **Check this troubleshooting guide** for your specific issue
2. **Review system logs** for error messages
3. **Verify prerequisites** are installed and configured
4. **Test with minimal setup** (fresh session, simple messages)

### Information to Provide

When reporting issues, include:
- **Operating System**: Windows 10, macOS 12.0, Ubuntu 20.04, etc.
- **Software Versions**: Python 3.9, Flutter 3.16, Chrome 120, etc.
- **Error Messages**: Full error text and stack traces
- **Steps to Reproduce**: Exact sequence that causes the issue
- **System Logs**: Relevant log output from Python server and Flutter app

### Common Solutions Summary

| Issue | Quick Fix |
|-------|-----------|
| Port in use | Kill process: `lsof -i :5001` then `kill -9 <PID>` |
| Missing dependencies | `pip install -r requirements.txt` |
| ChromeDriver issues | Update Chrome and ChromeDriver to matching versions |
| Flutter build fails | `flutter clean && flutter pub get` |
| QR code expired | Delete `whatsapp-session/` folder and restart |
| No messages scraped | Verify group name and permissions |
| API connection fails | Check server is running and ports are correct |

---

Most issues can be resolved by restarting the components in order: Chrome browser → Python server → Flutter app. If problems persist, check the logs for specific error messages.
