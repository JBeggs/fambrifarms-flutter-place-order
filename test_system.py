#!/usr/bin/env python3
"""
Quick test script to verify the Flutter + Python system works
"""

import requests
import json
import time

def test_python_server():
    """Test if Python server is running and responsive"""
    base_url = "http://localhost:5000/api"
    
    print("🧪 Testing Python WhatsApp Server...")
    
    try:
        # Test health endpoint
        response = requests.get(f"{base_url}/health", timeout=5)
        if response.status_code == 200:
            health_data = response.json()
            print(f"✅ Server is healthy: {health_data}")
        else:
            print(f"❌ Health check failed: {response.status_code}")
            return False
            
        # Test messages endpoint
        response = requests.get(f"{base_url}/messages", timeout=5)
        if response.status_code == 200:
            messages = response.json()
            print(f"✅ Messages endpoint working: {len(messages)} messages")
        else:
            print(f"❌ Messages endpoint failed: {response.status_code}")
            return False
            
        # Test message editing
        test_edit_data = {
            "message_id": "test_123",
            "edited_content": "Test edited content"
        }
        response = requests.post(f"{base_url}/messages/edit", 
                               json=test_edit_data, timeout=5)
        # This should return 404 since message doesn't exist, but server should respond
        if response.status_code in [404, 200]:
            print("✅ Message edit endpoint responding")
        else:
            print(f"❌ Message edit endpoint failed: {response.status_code}")
            
        return True
        
    except requests.exceptions.ConnectionError:
        print("❌ Cannot connect to Python server")
        print("   Make sure to run: cd python && python whatsapp_server.py")
        return False
    except Exception as e:
        print(f"❌ Error testing server: {e}")
        return False

def create_test_messages():
    """Create some test messages for Flutter to display"""
    test_messages = [
        {
            "id": "test_1",
            "sender": "Hazvinei",
            "content": "SHALLOME🤝\nSTOCK\nTomatoes 50kg\nOnions 30kg\nPotatoes 25kg",
            "timestamp": "14:10",
            "scraped_at": "2024-01-15T14:10:00",
            "type": "stock_update"
        },
        {
            "id": "test_2", 
            "sender": "Debonairs",
            "content": "Good morning\n5kg Tomatoes\n3kg Onions\n2 boxes Lettuce\nThanks",
            "timestamp": "14:15",
            "scraped_at": "2024-01-15T14:15:00",
            "type": "order"
        },
        {
            "id": "test_3",
            "sender": "Mugg and Bean",
            "content": "Hi there\nCan we get:\n10kg Potatoes\n5kg Carrots\nDelivery tomorrow please",
            "timestamp": "14:20", 
            "scraped_at": "2024-01-15T14:20:00",
            "type": "order"
        }
    ]
    
    # Save test messages to a file that the server can read
    with open('python/test_messages.json', 'w') as f:
        json.dump(test_messages, f, indent=2)
    
    print(f"✅ Created {len(test_messages)} test messages")
    return test_messages

def main():
    print("🚀 Place Order Final - System Test")
    print("=" * 50)
    
    # Create test data
    create_test_messages()
    
    # Test Python server
    if test_python_server():
        print("\n✅ Python server is working correctly!")
        print("\nNext steps:")
        print("1. Start Python server: cd python && python whatsapp_server.py")
        print("2. Start Flutter app: flutter run -d windows (or -d macos)")
        print("3. Test the complete workflow in the Flutter UI")
    else:
        print("\n❌ Python server test failed")
        print("\nTroubleshooting:")
        print("1. Make sure Python dependencies are installed:")
        print("   cd python && pip install -r requirements.txt")
        print("2. Start the server manually:")
        print("   cd python && python whatsapp_server.py")
        print("3. Check if port 5000 is available")
    
    print("\n" + "=" * 50)

if __name__ == "__main__":
    main()
