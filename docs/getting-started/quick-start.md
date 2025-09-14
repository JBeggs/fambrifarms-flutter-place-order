# Quick Start Guide

Get the Place Order Final system running in 5 minutes.

## ⚡ 5-Minute Setup

### Step 1: Start Python Server (2 minutes)
```bash
cd place-order-final/python/
echo "TARGET_GROUP_NAME=ORDERS Restaurants" > .env
python whatsapp_server.py
```

### Step 2: Start Flutter App (2 minutes)
```bash
# New terminal window
cd place-order-final/
flutter run -d windows  # or macos/linux
```

### Step 3: Connect WhatsApp (1 minute)
1. Click "Process Messages" in Flutter app
2. Click "Start WhatsApp"
3. Scan QR code with your phone (first time only)
4. Done! 🎉

## 🎯 Using the System

### Processing Messages
1. **Start WhatsApp**: Click "Start WhatsApp" button
2. **Scrape Messages**: Click "Refresh Messages" 
3. **Edit Messages**: Clean up unwanted text
4. **Process Orders**: Select messages and click "Process"

### Typical Workflow
```
WhatsApp Messages → Python Scraper → Django Backend → Flutter UI
```

1. Messages are scraped from your WhatsApp group
2. Python server classifies them (order/stock/instruction)
3. Django backend stores and processes them
4. Flutter app displays them for editing and processing

## 🔧 Alternative: Startup Script

Use the automated startup script:
```bash
python start_system.py
```

This will:
- Check dependencies
- Start Python server
- Show Flutter instructions
- Handle common setup issues

## 📱 First Time WhatsApp Setup

### QR Code Login
1. WhatsApp Web will open in Chrome
2. Scan QR code with your phone
3. Session is saved for future use
4. Group selection happens automatically

### Group Configuration
Ensure your `.env` file has the correct group name:
```bash
TARGET_GROUP_NAME=ORDERS Restaurants
```

The name must match your WhatsApp group exactly.

## 🎮 Using the Flutter App

### Landing Page
- **Process Messages**: Main message processing interface
- **Dashboard**: Order analytics and overview
- **Orders**: View and manage processed orders
- **Settings**: System configuration

### Message Processing
- **Message List**: Shows scraped WhatsApp messages
- **Message Editor**: Edit content before processing
- **Type Classification**: Order/Stock/Instruction detection
- **Bulk Actions**: Process multiple messages at once

## 🔍 Verification Checklist

### ✅ System Health
- [ ] Python server running on `localhost:5001`
- [ ] Django backend accessible on `localhost:8000`
- [ ] Flutter app opens without errors
- [ ] WhatsApp Web loads in Chrome

### ✅ WhatsApp Integration
- [ ] QR code scanned successfully
- [ ] Target group found and selected
- [ ] Messages can be scraped
- [ ] Message classification working

### ✅ Order Processing
- [ ] Messages display in Flutter app
- [ ] Message editing works
- [ ] Orders can be created
- [ ] Django backend receives data

## 🚨 Quick Troubleshooting

### Python Server Won't Start
```bash
# Check port availability
lsof -i :5001

# Install dependencies
pip install -r requirements.txt

# Check Python version
python --version  # Should be 3.8+
```

### Flutter App Issues
```bash
# Clean and rebuild
flutter clean && flutter pub get

# Check Flutter setup
flutter doctor
```

### WhatsApp Connection Issues
- Clear Chrome cache for WhatsApp Web
- Delete `python/whatsapp-session/` folder
- Restart Chrome browser
- Check internet connection

### No Messages Appearing
- Verify `TARGET_GROUP_NAME` is correct
- Check if group has recent messages
- Ensure you have access to the group
- Try refreshing WhatsApp Web manually

## 🎯 Next Steps

Once everything is working:

1. **Explore Features**: Try different message types and processing options
2. **Read Architecture**: Understand how the system works ([System Overview](../architecture/system-overview.md))
3. **Customize Settings**: Adjust environment variables for your needs
4. **Production Setup**: See [Production Deployment](../deployment/production-deployment.md)

## 📞 Need Help?

- **Common Issues**: Check [Troubleshooting Guide](troubleshooting.md)
- **System Details**: Read [System Overview](../architecture/system-overview.md)
- **Development**: See [Development Guide](../development/development-guide.md)

---

**Tip**: Keep both terminal windows open - one for Python server, one for Flutter development. The Python server needs to stay running for the system to work.
