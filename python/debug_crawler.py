#!/usr/bin/env python3
"""
Debug script to test WhatsApp crawler functionality
This script will help identify why the crawler is not finding or processing messages
"""

import os
import sys
import time
from pathlib import Path

# Add the app directory to the path
sys.path.insert(0, str(Path(__file__).parent))

# Set environment variable if not set
if 'TARGET_GROUP_NAME' not in os.environ:
    os.environ['TARGET_GROUP_NAME'] = 'ORDERS Restaurants'
    print(f"🔧 Set TARGET_GROUP_NAME to: {os.environ['TARGET_GROUP_NAME']}")

from app.simplified_whatsapp_crawler import SimplifiedWhatsAppCrawler
from selenium.webdriver.common.by import By

def test_crawler():
    """Test the simplified WhatsApp crawler"""
    print("🚀 Starting WhatsApp Crawler Debug Session")
    print("=" * 50)
    
    crawler = SimplifiedWhatsAppCrawler(django_url="http://localhost:8000")
    
    try:
        print("\n1️⃣ Testing WebDriver initialization...")
        if not crawler.initialize_driver():
            print("❌ Failed to initialize WebDriver")
            return False
        print("✅ WebDriver initialized successfully")
        
        print("\n2️⃣ Testing WhatsApp session start...")
        if not crawler.start_whatsapp_session():
            print("❌ Failed to start WhatsApp session")
            return False
        print("✅ WhatsApp session started successfully")
        
        print("\n3️⃣ Testing message extraction...")
        print("📝 Attempting to get current messages...")
        
        # Try to get messages with scrolling
        messages = crawler.get_current_messages(scroll_to_load_more=True)
        print(f"📊 Found {len(messages)} messages with scrolling")
        
        if messages:
            print("\n📋 Sample messages:")
            for i, msg in enumerate(messages[:3]):  # Show first 3 messages
                content_preview = msg['message_data']['content'][:100] + "..." if len(msg['message_data']['content']) > 100 else msg['message_data']['content']
                print(f"  {i+1}. {content_preview}")
                if msg['message_data'].get('was_expanded'):
                    print(f"     [EXPANDED from: {msg['message_data'].get('original_preview', 'N/A')}]")
        else:
            print("❌ No messages found")
            
            # Try to debug the issue
            print("\n🔍 Debugging message extraction...")
            
            # Check if we can find the message container
            try:
                container = crawler.driver.find_element(By.CSS_SELECTOR, '[data-testid="conversation-panel-messages"]')
                print(f"✅ Found message container: {container.tag_name}")
                
                # Check for message elements
                msg_elements = container.find_elements(By.CSS_SELECTOR, '[data-testid="msg-container"]')
                print(f"📝 Found {len(msg_elements)} message elements")
                
                if msg_elements:
                    print("🔍 Analyzing first message element...")
                    first_msg = msg_elements[0]
                    
                    # Try different text selectors
                    selectors = ['.copyable-text', 'div._akbu ._ao3e.selectable-text', 'span._ao3e.selectable-text', 'span.x1lliihq']
                    for selector in selectors:
                        elements = first_msg.find_elements(By.CSS_SELECTOR, selector)
                        if elements:
                            text = elements[0].get_attribute('textContent') or elements[0].text or ''
                            print(f"  {selector}: {len(elements)} elements, text: '{text[:50]}...'")
                        else:
                            print(f"  {selector}: 0 elements")
                else:
                    print("❌ No message elements found with current selectors")
                    
                    # Try alternative selectors
                    alt_selectors = ['[role="row"]', '.message', '[data-testid*="msg"]', '[class*="message"]']
                    for selector in alt_selectors:
                        elements = container.find_elements(By.CSS_SELECTOR, selector)
                        print(f"  Alternative {selector}: {len(elements)} elements")
                        
            except Exception as e:
                print(f"❌ Error during debugging: {e}")
        
        print("\n4️⃣ Testing Django connection...")
        if messages:
            success = crawler.send_to_django(messages)
            if success:
                print("✅ Successfully sent messages to Django")
            else:
                print("❌ Failed to send messages to Django")
        else:
            print("⚠️ Skipping Django test - no messages to send")
        
        print("\n✅ Debug session completed")
        return True
        
    except Exception as e:
        print(f"❌ Error during debug session: {e}")
        import traceback
        print(f"Full traceback: {traceback.format_exc()}")
        return False
        
    finally:
        print("\n🛑 Cleaning up...")
        crawler.stop()

if __name__ == "__main__":
    print("WhatsApp Crawler Debug Tool")
    print("This will help identify issues with message finding/processing")
    print("\nMake sure:")
    print("1. Chrome browser is installed")
    print("2. You're logged into WhatsApp Web")
    print("3. The target group 'ORDERS Restaurants' exists")
    print("\nPress Enter to continue or Ctrl+C to cancel...")
    
    try:
        input()
        test_crawler()
    except KeyboardInterrupt:
        print("\n🛑 Debug session cancelled")
