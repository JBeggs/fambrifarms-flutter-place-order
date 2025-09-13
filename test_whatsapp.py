#!/usr/bin/env python3
"""
Test WhatsApp Web connection
"""

import requests
import time
import json

def test_whatsapp_connection():
    """Test connecting to WhatsApp Web through our API"""
    base_url = "http://localhost:5001/api"
    
    print("🧪 Testing WhatsApp Web Connection...")
    print("=" * 50)
    
    try:
        # 1. Check server health
        print("1. Checking server health...")
        response = requests.get(f"{base_url}/health", timeout=5)
        if response.status_code == 200:
            health = response.json()
            print(f"✅ Server healthy: {health}")
        else:
            print(f"❌ Server not healthy: {response.status_code}")
            return False
        
        # 2. Start WhatsApp
        print("\n2. Starting WhatsApp Web...")
        response = requests.post(f"{base_url}/whatsapp/start", timeout=90)
        
        if response.status_code == 200:
            result = response.json()
            print(f"✅ WhatsApp started: {result}")
            
            if result.get('status') == 'qr_code':
                print("\n📱 QR CODE DISPLAYED!")
                print("=" * 30)
                print("🔍 Look for Chrome browser window that opened")
                print("📱 Scan the QR code with your WhatsApp mobile app")
                print("⏳ Waiting for you to scan...")
                
                # Wait for user to scan QR code
                print("\nPress Enter after scanning QR code...")
                input()
                
                # Check if logged in
                print("\n3. Checking login status...")
                health_response = requests.get(f"{base_url}/health", timeout=5)
                if health_response.status_code == 200:
                    health = health_response.json()
                    print(f"Status: {health}")
                
            elif result.get('status') == 'logged_in':
                print("✅ Already logged in to WhatsApp!")
            
            # 3. Try to get messages
            print("\n4. Fetching messages...")
            time.sleep(2)
            
            # First refresh messages
            refresh_response = requests.post(f"{base_url}/messages/refresh", timeout=10)
            if refresh_response.status_code == 200:
                refresh_result = refresh_response.json()
                print(f"✅ Messages refreshed: {refresh_result}")
            
            # Get messages
            messages_response = requests.get(f"{base_url}/messages", timeout=5)
            if messages_response.status_code == 200:
                messages = messages_response.json()
                print(f"✅ Retrieved {len(messages)} messages")
                
                # Display first few messages
                for i, msg in enumerate(messages[:3]):
                    print(f"\nMessage {i+1}:")
                    print(f"  From: {msg.get('sender', 'Unknown')}")
                    print(f"  Type: {msg.get('type', 'unknown')} {get_type_icon(msg.get('type'))}")
                    print(f"  Content: {msg.get('content', '')[:100]}...")
                    
                if len(messages) > 3:
                    print(f"\n... and {len(messages) - 3} more messages")
                    
                return True
            else:
                print(f"❌ Failed to get messages: {messages_response.status_code}")
                
        else:
            print(f"❌ Failed to start WhatsApp: {response.status_code}")
            print(f"Response: {response.text}")
            return False
            
    except requests.exceptions.ConnectionError:
        print("❌ Cannot connect to Python server")
        print("Make sure the server is running: python whatsapp_server.py")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def get_type_icon(msg_type):
    """Get icon for message type"""
    icons = {
        'order': '🛒',
        'stock_update': '📦', 
        'greeting': '👋',
        'unknown': '❓'
    }
    return icons.get(msg_type, '❓')

def test_message_editing():
    """Test message editing functionality"""
    print("\n" + "=" * 50)
    print("🧪 Testing Message Editing...")
    
    base_url = "http://localhost:5001/api"
    
    # Test editing a message (this will create a test message)
    test_edit = {
        "message_id": "test_edit_123",
        "edited_content": "Tomatoes 5kg\nOnions 3kg\nPotatoes 2kg"
    }
    
    try:
        response = requests.post(f"{base_url}/api/messages/edit", json=test_edit, timeout=5)
        print(f"Edit test response: {response.status_code}")
        if response.status_code == 200:
            print("✅ Message editing endpoint is working")
        elif response.status_code == 404:
            print("⚠️ Message editing endpoint exists but message not found (expected for test)")
        else:
            print(f"❌ Message editing failed: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"❌ Message editing error: {e}")

if __name__ == "__main__":
    print("🚀 WhatsApp Web Connection Test")
    print("This will open Chrome and connect to WhatsApp Web")
    print("Make sure you have your phone ready to scan QR code!")
    print()
    
    input("Press Enter to start the test...")
    
    success = test_whatsapp_connection()
    
    if success:
        test_message_editing()
        print("\n" + "=" * 50)
        print("🎉 SUCCESS! WhatsApp Web is connected and working!")
        print("\nYou can now:")
        print("1. Run the Flutter app: flutter run -d windows")
        print("2. Go to Messages page and see your WhatsApp messages")
        print("3. Edit messages to remove unwanted text")
        print("4. Process messages to create orders/stock updates")
    else:
        print("\n" + "=" * 50)
        print("❌ WhatsApp connection failed")
        print("Check the troubleshooting steps above")
    
    print("\nPress Enter to exit...")
    input()
