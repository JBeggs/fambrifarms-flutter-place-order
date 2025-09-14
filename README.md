# Place Order Final - WhatsApp Order Processing System

A modern Flutter desktop application with Python backend for processing WhatsApp messages, managing orders, and inventory integration. The system combines automated WhatsApp scraping with intelligent message processing and a professional desktop interface.

## 📚 Documentation

**Complete documentation is available in the [`docs/`](docs/) folder.**

### Quick Links
- 🚀 **[Getting Started](docs/getting-started/installation.md)** - Installation and setup
- ⚡ **[Quick Start](docs/getting-started/quick-start.md)** - 5-minute setup guide
- 🏗️ **[System Overview](docs/architecture/system-overview.md)** - Architecture and components
- 🚨 **[Troubleshooting](docs/getting-started/troubleshooting.md)** - Common issues and solutions

### Documentation Structure
- **[Getting Started](docs/getting-started/)** - Installation, quick start, troubleshooting
- **[Architecture](docs/architecture/)** - System design and technical details
- **[Business Logic](docs/business-logic/)** - Order processing and message classification
- **[Development](docs/development/)** - Development guides and testing
- **[Deployment](docs/deployment/)** - Production deployment instructions

## ⚡ Quick Start

### 5-Minute Setup
```bash
# 1. Start Python WhatsApp Server
cd python/
echo "TARGET_GROUP_NAME=ORDERS Restaurants" > .env
python whatsapp_server.py

# 2. Start Flutter App (new terminal)
flutter run -d windows  # or macos/linux

# 3. Connect WhatsApp
# - Click "Process Messages" in Flutter app
# - Click "Start WhatsApp" 
# - Scan QR code with phone (first time only)
```

## 🏗️ System Components

- **Python WhatsApp Server** (`python/`) - Flask API with Selenium automation for WhatsApp Web scraping
- **Flutter Desktop App** (`lib/`) - Modern desktop interface for message processing and order management  
- **Django Backend Integration** - Full API integration with existing Django order management system

## 🎯 Key Features

- ✅ **Automated WhatsApp Scraping** - Extract messages from WhatsApp Web
- ✅ **Intelligent Classification** - Automatically categorize messages as orders/stock/instructions
- ✅ **Message Editing Interface** - Clean and edit messages before processing
- ✅ **Order Management** - Create and manage customer orders
- ✅ **Cross-Platform Desktop** - Native performance on Windows, macOS, and Linux
- ✅ **Django Integration** - Seamless backend API communication

## 💻 System Requirements

- **Flutter SDK**: 3.16+ with desktop support
- **Python**: 3.8+ with pip  
- **Chrome Browser**: Latest version + ChromeDriver
- **Django Backend**: Running on localhost:8000 (separate project)

## 🚨 Need Help?

- **Installation Issues**: See [Installation Guide](docs/getting-started/installation.md)
- **Common Problems**: Check [Troubleshooting Guide](docs/getting-started/troubleshooting.md)
- **System Details**: Read [System Overview](docs/architecture/system-overview.md)
- **Development**: Visit [Development Guide](docs/development/development-guide.md)

## 📝 Project Status

### What's Working ✅
- Python WhatsApp server with robust Selenium automation
- Flutter desktop app with modern Material Design 3 UI
- Message scraping, classification, and editing
- Order creation and management
- Django backend integration
- Cross-platform desktop deployment

### Current Limitations ⚠️
- Single WhatsApp group focus
- Requires Chrome browser and manual QR code scanning
- Some advanced features still in development
- WhatsApp Web interface dependency (can break with updates)

---

**For complete documentation, visit the [`docs/`](docs/) folder.**