#!/usr/bin/env python3
"""
WhatsApp Crawler Server - Flask API for Flutter app
Handles WhatsApp Web scraping with Selenium
"""

import os

# Load environment variables from .env file (fail fast if dotenv not available)
try:
    from dotenv import load_dotenv
    load_dotenv()
    print("✅ Environment variables loaded from .env")
except ImportError:
    raise ImportError("python-dotenv is required. Install with: pip install python-dotenv")

# Verify required environment variables (fail fast)
if 'TARGET_GROUP_NAME' not in os.environ:
    raise EnvironmentError("TARGET_GROUP_NAME environment variable is required. Set it in .env file.")

from flask import Flask
from flask_cors import CORS
from app.routes import whatsapp_bp

app = Flask(__name__)
CORS(app)
app.register_blueprint(whatsapp_bp)

if __name__ == '__main__':
    print("🚀 Starting WhatsApp Server...")
    print("📱 Make sure Chrome is installed")
    print("🌐 Server will run on http://localhost:5001")
    
    app.run(host='127.0.0.1', port=5001, debug=True)
