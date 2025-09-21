#!/usr/bin/env python3
"""
Quick test script to debug WhatsApp login detection
"""

import os
import sys
from pathlib import Path

# Add the app directory to the path
sys.path.insert(0, str(Path(__file__).parent))

# Set environment variable if not set
if 'TARGET_GROUP_NAME' not in os.environ:
    os.environ['TARGET_GROUP_NAME'] = 'ORDERS Restaurants'

from app.simplified_whatsapp_crawler import SimplifiedWhatsAppCrawler

def test_login_detection():
    """Test just the login detection without full session start"""
    print("🔍 Testing WhatsApp Login Detection")
    print("=" * 40)
    
    crawler = SimplifiedWhatsAppCrawler(django_url="http://localhost:8000")
    
    try:
        print("\n1️⃣ Initializing WebDriver...")
        if not crawler.initialize_driver():
            print("❌ Failed to initialize WebDriver")
            return False
        
        print("\n2️⃣ Navigating to WhatsApp Web...")
        crawler.driver.get("https://web.whatsapp.com")
        
        print("\n3️⃣ Waiting for page to load...")
        import time
        time.sleep(10)  # Give it time to load
        
        print("\n4️⃣ Running debug to see page elements...")
        crawler.debug_page_elements()
        
        print("\n5️⃣ Testing login detection...")
        is_logged_in = crawler.is_logged_in()
        print(f"Login detection result: {is_logged_in}")
        
        if is_logged_in:
            print("✅ Login detected successfully!")
        else:
            print("❌ Login not detected - you may need to scan QR code")
            print("🔍 Waiting 30 seconds for manual login, then testing again...")
            time.sleep(30)
            
            print("\n6️⃣ Testing login detection after wait...")
            crawler.debug_page_elements()
            is_logged_in_after = crawler.is_logged_in()
            print(f"Login detection after wait: {is_logged_in_after}")
        
        # Keep browser open for manual inspection
        print("\n🔍 Browser will stay open for 60 seconds for manual inspection...")
        time.sleep(60)
        
    except Exception as e:
        print(f"❌ Error during test: {e}")
    finally:
        if crawler.driver:
            crawler.driver.quit()
            print("🧹 Browser closed")

if __name__ == "__main__":
    test_login_detection()
