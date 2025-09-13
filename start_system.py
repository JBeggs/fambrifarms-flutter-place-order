#!/usr/bin/env python3
"""
Startup script for Place Order Final system
Starts Python server and provides instructions for Flutter
"""

import subprocess
import sys
import os
import time
import requests
from pathlib import Path

def check_dependencies():
    """Check if required dependencies are installed"""
    print("🔍 Checking dependencies...")
    
    # Check Python packages
    required_packages = ['flask', 'flask-cors', 'selenium', 'requests']
    missing_packages = []
    
    for package in required_packages:
        try:
            __import__(package.replace('-', '_'))
            print(f"✅ {package}")
        except ImportError:
            missing_packages.append(package)
            print(f"❌ {package} - missing")
    
    if missing_packages:
        print(f"\n📦 Installing missing packages: {', '.join(missing_packages)}")
        subprocess.run([sys.executable, '-m', 'pip', 'install'] + missing_packages)
    
    # Check if ChromeDriver is available
    try:
        from selenium import webdriver
        from selenium.webdriver.chrome.options import Options
        options = Options()
        options.add_argument('--headless')
        driver = webdriver.Chrome(options=options)
        driver.quit()
        print("✅ ChromeDriver")
    except Exception as e:
        print("❌ ChromeDriver - not found or not working")
        print("   Please install ChromeDriver: https://chromedriver.chromium.org/")
        print(f"   Error: {e}")

def start_python_server():
    """Start the Python Flask server"""
    print("\n🚀 Starting Python WhatsApp Server...")
    
    # Change to python directory
    python_dir = Path(__file__).parent / 'python'
    os.chdir(python_dir)
    
    # Start server
    try:
        process = subprocess.Popen([
            sys.executable, 'whatsapp_server.py'
        ], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        
        # Wait a moment for server to start
        time.sleep(3)
        
        # Check if server is running
        try:
            response = requests.get('http://localhost:5000/api/health', timeout=5)
            if response.status_code == 200:
                print("✅ Python server started successfully!")
                print("📡 Server running on http://localhost:5000")
                return process
            else:
                print("❌ Server started but not responding correctly")
                return None
        except requests.exceptions.ConnectionError:
            print("❌ Server failed to start or not accessible")
            return None
            
    except Exception as e:
        print(f"❌ Failed to start server: {e}")
        return None

def show_flutter_instructions():
    """Show instructions for running Flutter app"""
    print("\n" + "="*60)
    print("🎯 NEXT STEPS - Start Flutter App")
    print("="*60)
    print()
    print("1. Open a new terminal window")
    print("2. Navigate to the project directory:")
    print(f"   cd {Path(__file__).parent}")
    print()
    print("3. Install Flutter dependencies:")
    print("   flutter pub get")
    print()
    print("4. Run the Flutter app:")
    print("   flutter run -d windows    # For Windows")
    print("   flutter run -d macos      # For macOS") 
    print("   flutter run -d linux      # For Linux")
    print()
    print("5. The Flutter app will open and connect to the Python server")
    print()
    print("🔧 TESTING THE SYSTEM:")
    print("• Click 'Process Messages' on the landing page")
    print("• Click 'Start WhatsApp' to begin crawling")
    print("• Edit messages to remove unwanted text")
    print("• Process messages to create orders/stock updates")
    print()
    print("📱 WHATSAPP SETUP:")
    print("• First time: Scan QR code with your phone")
    print("• Session will be saved for future use")
    print()
    print("🛑 TO STOP:")
    print("• Close Flutter app")
    print("• Press Ctrl+C here to stop Python server")
    print()
    print("="*60)

def main():
    print("🏁 Place Order Final - System Startup")
    print("="*50)
    
    # Check dependencies
    check_dependencies()
    
    # Start Python server
    server_process = start_python_server()
    
    if server_process:
        # Show Flutter instructions
        show_flutter_instructions()
        
        try:
            # Keep server running
            print("⏳ Python server is running... Press Ctrl+C to stop")
            server_process.wait()
        except KeyboardInterrupt:
            print("\n🛑 Stopping Python server...")
            server_process.terminate()
            server_process.wait()
            print("✅ Server stopped")
    else:
        print("\n❌ Failed to start Python server")
        print("\nTroubleshooting:")
        print("1. Check if port 5000 is available")
        print("2. Install missing dependencies manually")
        print("3. Check Python and pip versions")

if __name__ == "__main__":
    main()
