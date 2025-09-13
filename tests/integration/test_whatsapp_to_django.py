#!/usr/bin/env python3
"""
Integration tests for WhatsApp scraper to Django backend flow.
Tests the complete pipeline from message extraction to database storage.
"""

import unittest
import json
import os
import sys
import requests
import time
from datetime import datetime

# Add the python directory to the path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'python'))

# Import from the new modular structure
from app.core.webdriver_manager import WebDriverManager

class WhatsAppCrawler:
    """Test wrapper for the modular WhatsApp system."""
    def __init__(self):
        self.webdriver_manager = WebDriverManager()


class TestWhatsAppToDjangoIntegration(unittest.TestCase):
    """Test complete integration from WhatsApp scraper to Django backend."""
    
    @classmethod
    def setUpClass(cls):
        """Set up test environment."""
        cls.scraper = WhatsAppCrawler()
        cls.django_base_url = "http://localhost:8000"  # Adjust as needed
        cls.whatsapp_server_url = "http://localhost:5000"  # Adjust as needed
        
        # Load test data
        fixtures_path = os.path.join(os.path.dirname(__file__), '..', 'fixtures', 'sample_messages.json')
        with open(fixtures_path, 'r') as f:
            cls.test_data = json.load(f)
    
    def setUp(self):
        """Set up each test."""
        # Check if services are running
        self.django_available = self._check_service_health(self.django_base_url)
        self.whatsapp_server_available = self._check_service_health(self.whatsapp_server_url)
    
    def _check_service_health(self, url):
        """Check if a service is available."""
        try:
            response = requests.get(f"{url}/health", timeout=5)
            return response.status_code == 200
        except:
            return False
    
    @unittest.skipUnless(os.getenv('INTEGRATION_TESTS') == 'true', "Integration tests disabled")
    def test_message_scraping_to_api(self):
        """Test that scraped messages are sent to Django API."""
        if not self.whatsapp_server_available:
            self.skipTest("WhatsApp server not available")
        
        # Get messages from WhatsApp server
        try:
            response = requests.get(f"{self.whatsapp_server_url}/api/messages")
            self.assertEqual(response.status_code, 200)
            
            messages = response.json()
            self.assertIsInstance(messages, list, "Should return list of messages")
            
            # If we have messages, test their structure
            if messages:
                message = messages[0]
                required_fields = ['id', 'chat', 'sender', 'content', 'timestamp', 'message_type']
                for field in required_fields:
                    self.assertIn(field, message, f"Message should have '{field}' field")
                    
        except requests.RequestException as e:
            self.fail(f"Failed to connect to WhatsApp server: {e}")
    
    @unittest.skipUnless(os.getenv('INTEGRATION_TESTS') == 'true', "Integration tests disabled")
    def test_django_message_storage(self):
        """Test that messages are properly stored in Django backend."""
        if not self.django_available:
            self.skipTest("Django backend not available")
        
        # Create a test message
        test_message = {
            "id": f"test_msg_{int(time.time())}",
            "chat": "ORDERS Restaurants",
            "sender": "Test User",
            "content": "Test order: Tomatoes x3, Bananas 2kg",
            "timestamp": datetime.now().isoformat(),
            "message_type": "order",
            "media_url": "",
            "media_type": "",
            "media_info": "",
            "is_forwarded": False,
            "forwarded_info": "",
            "is_reply": False,
            "reply_content": ""
        }
        
        try:
            # Send message to Django
            response = requests.post(
                f"{self.django_base_url}/api/whatsapp/receive-messages/",
                json={"messages": [test_message]},
                headers={"Content-Type": "application/json"}
            )
            
            self.assertEqual(response.status_code, 200, 
                f"Django should accept message, got status {response.status_code}")
            
            # Verify message was stored
            time.sleep(1)  # Allow time for processing
            
            # Try to retrieve the message
            get_response = requests.get(f"{self.django_base_url}/api/whatsapp/messages/")
            self.assertEqual(get_response.status_code, 200)
            
            stored_messages = get_response.json()
            test_message_found = any(msg.get('message_id') == test_message['id'] 
                                   for msg in stored_messages.get('results', []))
            
            self.assertTrue(test_message_found, "Test message should be found in Django backend")
            
        except requests.RequestException as e:
            self.fail(f"Failed to connect to Django backend: {e}")
    
    @unittest.skipUnless(os.getenv('INTEGRATION_TESTS') == 'true', "Integration tests disabled")
    def test_media_message_handling(self):
        """Test that media messages are properly handled end-to-end."""
        if not self.django_available or not self.whatsapp_server_available:
            self.skipTest("Required services not available")
        
        # Test with a media message from fixtures
        media_message = self.test_data['test_media_messages'][0]
        
        test_message = {
            "id": f"test_media_{int(time.time())}",
            "chat": "ORDERS Restaurants",
            "sender": media_message['sender'],
            "content": media_message['content'],
            "timestamp": media_message['timestamp'],
            "message_type": media_message['type'],
            "media_url": media_message.get('media_url', ''),
            "media_type": media_message.get('media_type', ''),
            "media_info": media_message.get('media_info', ''),
            "is_forwarded": False,
            "forwarded_info": "",
            "is_reply": False,
            "reply_content": ""
        }
        
        try:
            # Send media message to Django
            response = requests.post(
                f"{self.django_base_url}/api/whatsapp/receive-messages/",
                json={"messages": [test_message]},
                headers={"Content-Type": "application/json"}
            )
            
            self.assertEqual(response.status_code, 200)
            
            # Verify media fields are preserved
            time.sleep(1)
            
            get_response = requests.get(f"{self.django_base_url}/api/whatsapp/messages/")
            stored_messages = get_response.json()
            
            stored_message = next((msg for msg in stored_messages.get('results', []) 
                                 if msg.get('message_id') == test_message['id']), None)
            
            self.assertIsNotNone(stored_message, "Media message should be stored")
            self.assertEqual(stored_message.get('message_type'), 'image')
            self.assertIsNotNone(stored_message.get('media_url'))
            
        except requests.RequestException as e:
            self.fail(f"Failed to test media message handling: {e}")
    
    def test_duplicate_prevention(self):
        """Test that duplicate messages are not created."""
        if not self.django_available:
            self.skipTest("Django backend not available")
        
        # Create identical test messages
        test_message = {
            "id": f"duplicate_test_{int(time.time())}",
            "chat": "ORDERS Restaurants", 
            "sender": "Test User",
            "content": "Duplicate test message",
            "timestamp": datetime.now().isoformat(),
            "message_type": "other"
        }
        
        try:
            # Send the same message twice
            for i in range(2):
                response = requests.post(
                    f"{self.django_base_url}/api/whatsapp/receive-messages/",
                    json={"messages": [test_message]},
                    headers={"Content-Type": "application/json"}
                )
                self.assertEqual(response.status_code, 200)
            
            time.sleep(1)
            
            # Check that only one message was stored
            get_response = requests.get(f"{self.django_base_url}/api/whatsapp/messages/")
            stored_messages = get_response.json()
            
            duplicate_count = sum(1 for msg in stored_messages.get('results', [])
                                if msg.get('message_id') == test_message['id'])
            
            self.assertEqual(duplicate_count, 1, "Should only store one copy of duplicate message")
            
        except requests.RequestException as e:
            self.fail(f"Failed to test duplicate prevention: {e}")


class TestSystemHealthChecks(unittest.TestCase):
    """Test system health and connectivity."""
    
    def test_whatsapp_server_health(self):
        """Test WhatsApp server health endpoint."""
        try:
            response = requests.get("http://localhost:5000/health", timeout=10)
            self.assertIn(response.status_code, [200, 404], 
                "WhatsApp server should be reachable (200) or endpoint not found (404)")
        except requests.RequestException:
            self.skipTest("WhatsApp server not reachable")
    
    def test_django_backend_health(self):
        """Test Django backend health."""
        try:
            response = requests.get("http://localhost:8000/admin/", timeout=10)
            self.assertIn(response.status_code, [200, 302], 
                "Django backend should be reachable")
        except requests.RequestException:
            self.skipTest("Django backend not reachable")
    
    def test_chrome_webdriver_availability(self):
        """Test that Chrome WebDriver can be initialized."""
        try:
            scraper = WhatsAppCrawler()
            # Test that the modular WebDriver manager can be instantiated
            self.assertIsNotNone(scraper.webdriver_manager)
            
            # Test health check
            health = scraper.webdriver_manager.health_check()
            self.assertIsInstance(health, dict)
        except Exception as e:
            self.fail(f"Failed to initialize WhatsApp scraper: {e}")


if __name__ == '__main__':
    # Set environment variable to enable integration tests
    if len(sys.argv) > 1 and sys.argv[1] == '--integration':
        os.environ['INTEGRATION_TESTS'] = 'true'
        sys.argv.remove('--integration')
    
    unittest.main(verbosity=2)
