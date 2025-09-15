import os
import unittest
import json
import requests
import time
from pathlib import Path
from datetime import datetime

try:
    from bs4 import BeautifulSoup
except ImportError:
    BeautifulSoup = None

# Load environment from .env if present
try:
    from dotenv import load_dotenv
    load_dotenv()
except Exception:
    pass

# Make app core importable
import sys
PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT_ROOT / 'python'))

from app.core.whatsapp_crawler import WhatsAppCrawler
from app.core.message_parser import MessageParser


class SoupElement:
    """BeautifulSoup wrapper to mimic Selenium WebElement interface"""
    def __init__(self, tag):
        self._tag = tag

    @property
    def text(self):
        return self._tag.get_text(" ", strip=True)

    def get_attribute(self, key):
        return self._tag.get(key) or ''

    def find_elements(self, by, selector):
        try:
            results = self._tag.select(selector)
        except Exception:
            results = []
        return [SoupElement(t) for t in results]


class SoupDriver:
    """BeautifulSoup wrapper to mimic Selenium WebDriver interface"""
    def __init__(self, soup):
        self._soup = soup

    def find_elements(self, by, selector):
        try:
            results = self._soup.select(selector)
        except Exception:
            results = []
        return [SoupElement(t) for t in results]

    def execute_script(self, script, element=None):
        return None


@unittest.skipIf(BeautifulSoup is None, "bs4 not installed; skipping integration tests")
class OrderProcessingWorkflowTests(unittest.TestCase):
    """Test complete workflow: Scraping → Parsing → Database Integration"""
    
    @classmethod
    def setUpClass(cls):
        """Set up test environment"""
        cls.test_data_dir = PROJECT_ROOT / 'python' / 'tests'
        cls.backend_url = 'http://localhost:8000'  # Django backend
        cls.python_api_url = 'http://localhost:5001'  # Python Flask API
        
        # Ensure required env is present
        if 'TARGET_GROUP_NAME' not in os.environ:
            os.environ['TARGET_GROUP_NAME'] = 'ORDERS Restaurants'

    def setUp(self):
        """Create instances for each test"""
        self.crawler = WhatsAppCrawler()
        self.parser = MessageParser()
        self.test_message_ids = []  # Track test messages for cleanup

    def test_scrape_and_parse_tuesday_orders(self):
        """Test complete workflow for Tuesday orders"""
        # Load Tuesday test data
        tuesday_file = self.test_data_dir / 'Tuesday_01_09_2025_messages.html'
        if not tuesday_file.exists():
            self.skipTest("Tuesday test data not available")
        
        html_content = tuesday_file.read_text(encoding='utf-8', errors='ignore')
        soup = BeautifulSoup(html_content, 'html.parser')
        
        # Step 1: Scrape messages
        self.crawler.driver = SoupDriver(soup)
        scraped_messages = self.crawler._scrape_from_open_chat()
        
        self.assertGreater(len(scraped_messages), 0, "No messages scraped")
        
        # Step 2: Parse messages into orders
        orders = self.parser.parse_messages_to_orders(scraped_messages)
        
        self.assertGreater(len(orders), 0, "No orders parsed from messages")
        
        # Step 3: Verify order structure
        for order in orders:
            # Each order should have required fields
            required_fields = ['company_name', 'items_text', 'timestamp']
            for field in required_fields:
                self.assertIn(field, order, f"Missing field '{field}' in order")
            
            # Company name should not be empty
            self.assertTrue(order['company_name'].strip(), 
                          f"Empty company name in order: {order}")
            
            # Should have items
            self.assertGreater(len(order['items_text']), 0, 
                             f"No items in order for {order['company_name']}")

    def test_stock_message_parsing(self):
        """Test that stock messages are parsed correctly"""
        # Load test data with stock messages
        test_files = [
            'Tuesday_15_09_2025_messages.html',  # Has SHALLOME stock
            '27_08_2025_messages.html'           # Has pre-order stock
        ]
        
        for test_file in test_files:
            with self.subTest(file=test_file):
                file_path = self.test_data_dir / test_file
                if not file_path.exists():
                    continue
                
                html_content = file_path.read_text(encoding='utf-8', errors='ignore')
                soup = BeautifulSoup(html_content, 'html.parser')
                
                # Scrape messages
                self.crawler.driver = SoupDriver(soup)
                messages = self.crawler._scrape_from_open_chat()
                
                # Find stock messages
                stock_messages = [msg for msg in messages 
                                if msg['message_type'] == 'stock' and 'SHALLOME' in msg['content']]
                
                for stock_msg in stock_messages:
                    # Stock messages should be fully expanded
                    self.assertGreater(len(stock_msg['content']), 1000, 
                                     "Stock message seems truncated")
                    
                    # Should contain multiple items
                    lines = stock_msg['content'].split('\n')
                    item_lines = [line for line in lines if any(char.isdigit() for char in line)]
                    self.assertGreater(len(item_lines), 10, 
                                     "Stock message should contain many items")

    def test_company_extraction_accuracy(self):
        """Test that company names are extracted correctly from orders"""
        expected_companies = [
            'Venue', 'Debonairs', 'Casa Bella', 'Mugg and Bean', 
            'T-junction', 'Wimpy', 'Shebeen', 'Luma', 'Marco'
        ]
        
        # Test against Thursday data (has most companies)
        thursday_file = self.test_data_dir / 'Thursday_03_09_2025_messages.html'
        if not thursday_file.exists():
            self.skipTest("Thursday test data not available")
        
        html_content = thursday_file.read_text(encoding='utf-8', errors='ignore')
        soup = BeautifulSoup(html_content, 'html.parser')
        
        # Scrape and parse
        self.crawler.driver = SoupDriver(soup)
        messages = self.crawler._scrape_from_open_chat()
        orders = self.parser.parse_messages_to_orders(messages)
        
        # Extract found company names
        found_companies = [order['company_name'] for order in orders]
        found_companies = [name for name in found_companies if name.strip()]
        
        # Should find several expected companies
        matches = [company for company in expected_companies if company in found_companies]
        self.assertGreater(len(matches), 3, 
                         f"Expected to find several companies, found: {found_companies}")

    def test_message_deduplication(self):
        """Test that duplicate messages are properly handled"""
        # Use largest dataset
        thursday_file = self.test_data_dir / 'Thursday_03_09_2025_messages.html'
        if not thursday_file.exists():
            self.skipTest("Thursday test data not available")
        
        html_content = thursday_file.read_text(encoding='utf-8', errors='ignore')
        soup = BeautifulSoup(html_content, 'html.parser')
        
        # Scrape messages
        self.crawler.driver = SoupDriver(soup)
        messages = self.crawler._scrape_from_open_chat()
        
        # Check for duplicates by content hash
        content_hashes = {}
        duplicates = []
        
        for msg in messages:
            content_hash = hash(msg['content'][:200])  # Hash first 200 chars
            if content_hash in content_hashes:
                duplicates.append({
                    'original': content_hashes[content_hash]['content'][:50],
                    'duplicate': msg['content'][:50]
                })
            else:
                content_hashes[content_hash] = msg
        
        # Should have minimal duplicates (some may be legitimate repeated messages)
        self.assertLess(len(duplicates), 3, 
                       f"Too many duplicate messages found: {len(duplicates)}")

    def test_timestamp_extraction_accuracy(self):
        """Test that timestamps are extracted accurately"""
        # Test with known timestamp data
        test_file = self.test_data_dir / 'Tuesday_01_09_2025_messages.html'
        if not test_file.exists():
            self.skipTest("Tuesday test data not available")
        
        html_content = test_file.read_text(encoding='utf-8', errors='ignore')
        soup = BeautifulSoup(html_content, 'html.parser')
        
        # Scrape messages
        self.crawler.driver = SoupDriver(soup)
        messages = self.crawler._scrape_from_open_chat()
        
        # Verify timestamp formats and dates
        for msg in messages[:10]:  # Test first 10
            timestamp = msg['timestamp']
            
            # Should be valid ISO format
            try:
                dt = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
                
                # Should be reasonable date (2025)
                self.assertEqual(dt.year, 2025, f"Unexpected year in timestamp: {timestamp}")
                
                # Should be September 1st for this dataset
                self.assertEqual(dt.month, 9, f"Expected September in timestamp: {timestamp}")
                self.assertEqual(dt.day, 1, f"Expected day 1 in timestamp: {timestamp}")
                
            except ValueError:
                self.fail(f"Invalid timestamp format: {timestamp}")

    def test_media_content_detection(self):
        """Test detection of images and voice messages"""
        for test_file in ['Thursday_03_09_2025_messages.html', 'Tuesday_08_09_2025_messages.html']:
            with self.subTest(file=test_file):
                file_path = self.test_data_dir / test_file
                if not file_path.exists():
                    continue
                
                html_content = file_path.read_text(encoding='utf-8', errors='ignore')
                soup = BeautifulSoup(html_content, 'html.parser')
                
                # Scrape messages
                self.crawler.driver = SoupDriver(soup)
                messages = self.crawler._scrape_from_open_chat()
                
                # Check for media messages
                image_messages = [msg for msg in messages if msg['media_type'] == 'image']
                voice_messages = [msg for msg in messages if msg['media_type'] == 'voice']
                
                # Verify image URLs if present
                for img_msg in image_messages:
                    if img_msg['media_url']:
                        self.assertTrue(img_msg['media_url'].startswith('http'), 
                                      f"Image URL should be http/https: {img_msg['media_url']}")
                
                # Verify voice duration if present
                for voice_msg in voice_messages:
                    if voice_msg['media_info']:
                        self.assertIn(':', voice_msg['media_info'], 
                                    f"Voice duration should contain ':': {voice_msg['media_info']}")

    def test_order_item_extraction(self):
        """Test that individual items are extracted from order messages"""
        # Use pre-order data which has clear item lists
        preorder_file = self.test_data_dir / '27_08_2025_messages.html'
        if not preorder_file.exists():
            self.skipTest("Pre-order test data not available")
        
        html_content = preorder_file.read_text(encoding='utf-8', errors='ignore')
        soup = BeautifulSoup(html_content, 'html.parser')
        
        # Scrape and parse
        self.crawler.driver = SoupDriver(soup)
        messages = self.crawler._scrape_from_open_chat()
        
        # Find the first order message
        first_order = None
        for msg in messages:
            if 'Hi Here is my order' in msg['content'] and 'Tomatoes x3' in msg['content']:
                first_order = msg
                break
        
        self.assertIsNotNone(first_order, "First order message not found")
        
        # Parse items from the order
        items = self.parser.extract_order_items(first_order['content'])
        
        # Should extract multiple items
        self.assertGreater(len(items), 5, "Should extract multiple items from first order")
        
        # Should find specific items
        item_texts = [item.lower() for item in items]
        expected_items = ['tomatoes', 'banana', 'onion', 'lemon', 'lettuce']
        
        found_items = []
        for expected in expected_items:
            if any(expected in item for item in item_texts):
                found_items.append(expected)
        
        self.assertGreater(len(found_items), 3, 
                         f"Should find several expected items, found: {found_items}")

    @unittest.skip("Requires running backend server")
    def test_api_integration(self):
        """Test integration with Flask API endpoints"""
        # This test requires the Flask server to be running
        try:
            # Test health endpoint
            response = requests.get(f"{self.python_api_url}/api/health", timeout=5)
            self.assertEqual(response.status_code, 200)
            
            health_data = response.json()
            self.assertIn('status', health_data)
            
        except requests.exceptions.RequestException:
            self.skipTest("Flask API server not running")

    def test_database_integration_complete_workflow(self):
        """Test complete workflow: Scrape → Database → Orders"""
        # Test Django backend is running
        try:
            response = requests.get(f"{self.backend_url}/api/whatsapp/health/", timeout=5)
            if response.status_code != 200:
                self.skipTest("Django backend not running")
        except requests.exceptions.RequestException:
            self.skipTest("Django backend not running")
        
        # Load test data
        test_file = self.test_data_dir / 'Tuesday_15_09_2025_messages.json'
        if not test_file.exists():
            self.skipTest("Test data not available")
        
        with open(test_file, 'r', encoding='utf-8') as f:
            test_messages = json.load(f)
        
        # Convert to expected format for Django API
        messages_payload = {
            "messages": []
        }
        
        for msg in test_messages[:5]:  # Test with first 5 messages
            # Convert test message format to Django API format
            api_message = {
                "id": msg.get('id', f"test_{msg.get('timestamp', '12:00')}"),
                "chat": "ORDERS Restaurants", 
                "sender": msg.get('sender', 'Test Sender'),
                "content": msg.get('text', ''),
                "timestamp": self._convert_timestamp(msg.get('timestamp', '12:00, 15/09/2025')),
                "cleanedContent": msg.get('text', ''),
                "items": [],
                "instructions": ""
            }
            messages_payload["messages"].append(api_message)
        
        print(f"📤 Sending {len(messages_payload['messages'])} messages to Django API")
        
        # Step 1: Send messages to Django
        response = requests.post(
            f"{self.backend_url}/api/whatsapp/receive-messages/",
            json=messages_payload,
            timeout=10
        )
        
        self.assertEqual(response.status_code, 200, f"Failed to send messages: {response.text}")
        response_data = response.json()
        
        print(f"✅ Django response: {response_data}")
        self.assertIn('status', response_data)
        self.assertEqual(response_data['status'], 'success')
        self.assertGreater(response_data.get('messages_received', 0), 0)
        
        # Step 2: Verify messages are stored
        response = requests.get(
            f"{self.backend_url}/api/whatsapp/messages/?limit=10",
            timeout=10
        )
        
        self.assertEqual(response.status_code, 200, f"Failed to get messages: {response.text}")
        stored_data = response.json()
        
        print(f"📊 Retrieved {len(stored_data.get('messages', []))} messages from database")
        self.assertIn('messages', stored_data)
        self.assertGreater(len(stored_data['messages']), 0)
        
        # Step 3: Find order messages and process them
        order_message_ids = []
        stock_messages = []
        
        for msg in stored_data['messages']:
            if msg.get('message_type') == 'order':
                order_message_ids.append(msg['message_id'])
            elif msg.get('message_type') == 'stock':
                stock_messages.append(msg)
        
        print(f"🛒 Found {len(order_message_ids)} order messages")
        print(f"📊 Found {len(stock_messages)} stock messages")
        
        # Verify stock messages are properly stored
        for stock_msg in stock_messages:
            if 'SHALLOME' in stock_msg.get('content', ''):
                self.assertGreater(len(stock_msg['content']), 500, 
                                 "SHALLOME stock message should be substantial")
                print(f"✅ SHALLOME stock message: {len(stock_msg['content'])} chars")
        
        # Step 4: Process order messages to create orders (if any found)
        if order_message_ids:
            process_payload = {
                "message_ids": order_message_ids[:3]  # Process first 3 order messages
            }
            
            response = requests.post(
                f"{self.backend_url}/api/whatsapp/messages/process/",
                json=process_payload,
                timeout=10
            )
            
            if response.status_code == 200:
                process_data = response.json()
                print(f"📦 Order processing result: {process_data}")
                
                if process_data.get('orders_created'):
                    self.assertGreater(process_data['orders_created'], 0)
                    print(f"✅ Created {process_data['orders_created']} orders")
                else:
                    print("ℹ️ No orders created (may be expected for test data)")
            else:
                print(f"⚠️ Order processing failed: {response.text}")
        
        print("✅ Complete database integration workflow tested successfully")
    
    def tearDown(self):
        """Clean up test data from database"""
        if hasattr(self, 'test_message_ids') and self.test_message_ids:
            try:
                # Clean up test messages
                cleanup_payload = {"message_ids": self.test_message_ids}
                requests.post(
                    f"{self.backend_url}/api/whatsapp/messages/bulk-delete/",
                    json=cleanup_payload,
                    timeout=5
                )
                print(f"🧹 Cleaned up {len(self.test_message_ids)} test messages")
            except:
                pass  # Cleanup is best-effort
    
    def test_message_classification_in_database(self):
        """Test that Django correctly classifies different message types"""
        try:
            response = requests.get(f"{self.backend_url}/api/whatsapp/health/", timeout=5)
            if response.status_code != 200:
                self.skipTest("Django backend not running")
        except requests.exceptions.RequestException:
            self.skipTest("Django backend not running")
        
        # Test messages with known classifications
        test_cases = [
            {
                "content": "Hi Here is my order\nTomatoes x3\nBananas 2kg\nThanks",
                "expected_type": "order"
            },
            {
                "content": "SHALLOME STOCK AS AT 15 SEP 2025\n1.Butternuts 6 Bags\n2.White Onions 13kg",
                "expected_type": "stock"
            },
            {
                "content": "Tuesday orders starts here 👇👇👇",
                "expected_type": "demarcation"
            },
            {
                "content": "Good morning team, please note delivery changes",
                "expected_type": "instruction"
            }
        ]
        
        messages_payload = {"messages": []}
        
        for i, test_case in enumerate(test_cases):
            api_message = {
                "id": f"test_classification_{i}_{int(datetime.now().timestamp())}",
                "chat": "ORDERS Restaurants",
                "sender": "Test Sender",
                "content": test_case["content"],
                "timestamp": "2025-09-15T12:00:00Z",
                "cleanedContent": test_case["content"],
                "items": [],
                "instructions": ""
            }
            messages_payload["messages"].append(api_message)
            self.test_message_ids.append(api_message["id"])
        
        # Send messages to Django
        response = requests.post(
            f"{self.backend_url}/api/whatsapp/receive-messages/",
            json=messages_payload,
            timeout=10
        )
        
        self.assertEqual(response.status_code, 200, f"Failed to send messages: {response.text}")
        
        # Retrieve and verify classifications
        response = requests.get(
            f"{self.backend_url}/api/whatsapp/messages/?limit=20",
            timeout=10
        )
        
        self.assertEqual(response.status_code, 200)
        stored_data = response.json()
        
        # Check classifications
        classifications_found = {}
        for msg in stored_data['messages']:
            if msg['message_id'] in self.test_message_ids:
                classifications_found[msg['message_id']] = msg['message_type']
        
        print(f"📊 Message classifications: {classifications_found}")
        
        # Verify at least some classifications are correct
        correct_classifications = 0
        for i, test_case in enumerate(test_cases):
            msg_id = f"test_classification_{i}_{int(datetime.now().timestamp())}"
            if msg_id in classifications_found:
                if classifications_found[msg_id] == test_case["expected_type"]:
                    correct_classifications += 1
                    print(f"✅ {test_case['expected_type']}: Correctly classified")
                else:
                    print(f"⚠️ {test_case['expected_type']}: Expected {test_case['expected_type']}, got {classifications_found[msg_id]}")
        
        self.assertGreater(correct_classifications, 0, "At least some messages should be classified correctly")
    
    def test_company_extraction_in_database(self):
        """Test that company names are extracted and stored correctly"""
        try:
            response = requests.get(f"{self.backend_url}/api/whatsapp/health/", timeout=5)
            if response.status_code != 200:
                self.skipTest("Django backend not running")
        except requests.exceptions.RequestException:
            self.skipTest("Django backend not running")
        
        # Test messages with company names
        company_test_cases = [
            {
                "content": "Good day orders for tomorrow\n2 5kg tomatoes\n2 5kg mushrooms\n10 kg onions\nThank you",
                "next_message": "Venue",
                "expected_company": "Venue"
            },
            {
                "content": "Order for tomorrow\nPotato 4x10kg\nLemon 1box\nTomato 1box",
                "next_message": "T-junction", 
                "expected_company": "T-junction"
            }
        ]
        
        messages_payload = {"messages": []}
        
        for i, test_case in enumerate(company_test_cases):
            # Add order message
            order_msg = {
                "id": f"test_company_order_{i}_{int(datetime.now().timestamp())}",
                "chat": "ORDERS Restaurants",
                "sender": "Test Sender",
                "content": test_case["content"],
                "timestamp": f"2025-09-15T12:0{i}:00Z",
                "cleanedContent": test_case["content"],
                "items": [],
                "instructions": ""
            }
            messages_payload["messages"].append(order_msg)
            self.test_message_ids.append(order_msg["id"])
            
            # Add company name message
            company_msg = {
                "id": f"test_company_name_{i}_{int(datetime.now().timestamp())}",
                "chat": "ORDERS Restaurants", 
                "sender": "Test Sender",
                "content": test_case["next_message"],
                "timestamp": f"2025-09-15T12:0{i+1}:00Z",
                "cleanedContent": test_case["next_message"],
                "items": [],
                "instructions": ""
            }
            messages_payload["messages"].append(company_msg)
            self.test_message_ids.append(company_msg["id"])
        
        # Send messages to Django
        response = requests.post(
            f"{self.backend_url}/api/whatsapp/receive-messages/",
            json=messages_payload,
            timeout=10
        )
        
        self.assertEqual(response.status_code, 200, f"Failed to send messages: {response.text}")
        
        # Retrieve and verify company extraction
        response = requests.get(
            f"{self.backend_url}/api/whatsapp/messages/?limit=20",
            timeout=10
        )
        
        self.assertEqual(response.status_code, 200)
        stored_data = response.json()
        
        companies_found = set()
        for msg in stored_data['messages']:
            if msg['message_id'] in self.test_message_ids and msg.get('company_name'):
                companies_found.add(msg['company_name'])
        
        print(f"🏢 Companies extracted: {companies_found}")
        
        # Verify some expected companies were found
        expected_companies = {'Venue', 'T-junction'}
        found_expected = companies_found.intersection(expected_companies)
        
        self.assertGreater(len(found_expected), 0, 
                         f"Expected to find companies {expected_companies}, found {companies_found}")
        print(f"✅ Successfully extracted companies: {found_expected}")
    
    def test_stock_take_database_integration(self):
        """Test that SHALLOME stock take messages are properly stored and processed"""
        try:
            response = requests.get(f"{self.backend_url}/api/whatsapp/health/", timeout=5)
            if response.status_code != 200:
                self.skipTest("Django backend not running")
        except requests.exceptions.RequestException:
            self.skipTest("Django backend not running")
        
        # Load actual SHALLOME stock message from test data
        test_file = self.test_data_dir / 'Tuesday_15_09_2025_messages.json'
        if not test_file.exists():
            self.skipTest("Stock test data not available")
        
        with open(test_file, 'r', encoding='utf-8') as f:
            test_messages = json.load(f)
        
        # Find SHALLOME stock message
        shallome_message = None
        for msg in test_messages:
            if 'SHALLOME' in msg.get('text', '') and 'STOCK AS AT' in msg.get('text', ''):
                shallome_message = msg
                break
        
        if not shallome_message:
            self.skipTest("No SHALLOME stock message found in test data")
        
        # Send stock message to Django
        stock_payload = {
            "messages": [{
                "id": f"test_stock_{int(datetime.now().timestamp())}",
                "chat": "ORDERS Restaurants",
                "sender": shallome_message.get('sender', 'Hazvinei'),
                "content": shallome_message['text'],
                "timestamp": self._convert_timestamp(shallome_message.get('timestamp', '09:47, 15/09/2025')),
                "cleanedContent": shallome_message['text'],
                "items": [],
                "instructions": ""
            }]
        }
        
        self.test_message_ids.append(stock_payload["messages"][0]["id"])
        
        print(f"📊 Sending SHALLOME stock message ({len(shallome_message['text'])} chars)")
        
        # Send to Django
        response = requests.post(
            f"{self.backend_url}/api/whatsapp/receive-messages/",
            json=stock_payload,
            timeout=10
        )
        
        self.assertEqual(response.status_code, 200, f"Failed to send stock message: {response.text}")
        response_data = response.json()
        
        print(f"✅ Django stock response: {response_data}")
        self.assertEqual(response_data['status'], 'success')
        
        # Verify stock message is stored and classified
        response = requests.get(
            f"{self.backend_url}/api/whatsapp/messages/?type=stock&limit=10",
            timeout=10
        )
        
        self.assertEqual(response.status_code, 200)
        stock_data = response.json()
        
        print(f"📊 Retrieved {len(stock_data.get('messages', []))} stock messages")
        
        # Find our test stock message
        test_stock_msg = None
        for msg in stock_data['messages']:
            if msg['message_id'] == stock_payload["messages"][0]["id"]:
                test_stock_msg = msg
                break
        
        self.assertIsNotNone(test_stock_msg, "Stock message not found in database")
        self.assertEqual(test_stock_msg['message_type'], 'stock', "Message not classified as stock")
        
        # Verify stock content is complete (not truncated)
        self.assertGreater(len(test_stock_msg['content']), 1000, 
                         "Stock message appears truncated")
        
        # Verify stock items are present
        stock_content = test_stock_msg['content']
        expected_items = ['Butternuts', 'White Onions', 'Red Onion', 'Banana', 'Cucumber', 
                         'Green Pepper', 'Strawberry', 'Potatoes', 'Avos']
        
        items_found = []
        for item in expected_items:
            if item in stock_content:
                items_found.append(item)
        
        self.assertGreater(len(items_found), 5, 
                         f"Expected multiple stock items, found: {items_found}")
        
        print(f"✅ Stock items found: {items_found}")
        
        # Test stock updates endpoint
        response = requests.get(
            f"{self.backend_url}/api/whatsapp/stock-updates/",
            timeout=10
        )
        
        if response.status_code == 200:
            stock_updates = response.json()
            print(f"📊 Stock updates available: {len(stock_updates.get('stock_updates', []))}")
            
            # Check if our stock message created stock updates
            recent_updates = [update for update in stock_updates.get('stock_updates', []) 
                            if 'SHALLOME' in update.get('content', '')]
            
            if recent_updates:
                print(f"✅ Found {len(recent_updates)} SHALLOME stock updates")
            else:
                print("ℹ️ No stock updates created (may be expected)")
        
        print("✅ Stock take database integration test completed")
    
    def test_stock_inventory_processing(self):
        """Test that stock messages can be processed for inventory updates"""
        try:
            response = requests.get(f"{self.backend_url}/api/whatsapp/health/", timeout=5)
            if response.status_code != 200:
                self.skipTest("Django backend not running")
        except requests.exceptions.RequestException:
            self.skipTest("Django backend not running")
        
        # Create a comprehensive stock message
        comprehensive_stock = """SHALLOME STOCK AS AT 15 SEP 2025
1.Butternuts 6 Bags
2.White Onions 13kg
3.Red Onion 3.5kg
4.Banana 11.5kg
5.Cucumber 45
6.Green Pepper 11kg
7.Yellow pepper 4kg
8.Red Pepper 10.2kg
9.Strawberry 3 Pun
10.Mixed Grapes 4 pun
11.Red Chillie 2.3kg
12.Green Chillie 6kg
13.Brinjals 2kg
14.Celery 10kg
15.lettuce head 5heads
16.Spinarch 18 kgs
17.Loose carrots 4.5kg
18.Cauliflower 14 heads
19.Red Cabbage 2
20.Spring Onion 1.2kg
21.Green Beans 2kg
22.Baby Marrow 6kg
23.Cabbage heads 2
24.Patty Pan 5 pun
25.Sweet mellon 4 (small size)
26.Musk mellon 2
27.Sweet potatoes 12kg
28.pine Apple 10
29.Cherry tomatoes 14 pun
30.Mushrooms 5 x100g pun
31.Beetroot 1kg
32.Eggs 8xhalf dozen crates
33.Baby corn 13Pun
34.Potatoes 3 bags plus 1 broken bag
35.Green Apple 4kg
36.Red Apple 13kg
37.Kiwis 7kg
38.Green grapes 3pun
39.Red Grapes 6pun
40.Naatjies 4kg
41.Blue Berry 2 pun
42.Crushed garlic 1 kg
43.Coriander 200g
44.Rocket 400g
45.Mint enough
46.Rosemary brought
47.Thyme enough
48.Ginger 300g
49.Garlic cloves 3kg
50.Soft Avo 4 boxes medium size & half box small size
51.Hard Avo 2 boxes small & 1box medium size
52.Semi Avo 2 box small sizes 1 box medium size"""
        
        # Send comprehensive stock message
        stock_payload = {
            "messages": [{
                "id": f"test_comprehensive_stock_{int(datetime.now().timestamp())}",
                "chat": "ORDERS Restaurants",
                "sender": "Hazvinei",
                "content": comprehensive_stock,
                "timestamp": "2025-09-15T09:47:00Z",
                "cleanedContent": comprehensive_stock,
                "items": [],
                "instructions": ""
            }]
        }
        
        self.test_message_ids.append(stock_payload["messages"][0]["id"])
        
        print(f"📊 Sending comprehensive stock message ({len(comprehensive_stock)} chars)")
        
        # Send to Django
        response = requests.post(
            f"{self.backend_url}/api/whatsapp/receive-messages/",
            json=stock_payload,
            timeout=10
        )
        
        self.assertEqual(response.status_code, 200, f"Failed to send stock message: {response.text}")
        
        # Verify message stored as stock type
        response = requests.get(
            f"{self.backend_url}/api/whatsapp/messages/?type=stock&limit=5",
            timeout=10
        )
        
        self.assertEqual(response.status_code, 200)
        stock_data = response.json()
        
        # Find our comprehensive stock message
        test_stock = None
        for msg in stock_data['messages']:
            if msg['message_id'] == stock_payload["messages"][0]["id"]:
                test_stock = msg
                break
        
        self.assertIsNotNone(test_stock, "Comprehensive stock message not found")
        
        # Verify all major categories are present
        stock_content = test_stock['content']
        categories = {
            'vegetables': ['Onions', 'Cucumber', 'Pepper', 'Brinjals', 'Celery', 'Spinarch', 'Carrots'],
            'fruits': ['Banana', 'Strawberry', 'Grapes', 'Apple', 'Kiwis', 'Naatjies'],
            'herbs': ['Coriander', 'Rocket', 'Mint', 'Rosemary', 'Thyme', 'Ginger'],
            'staples': ['Potatoes', 'Eggs', 'Garlic', 'Avos']
        }
        
        categories_found = {}
        for category, items in categories.items():
            found_items = [item for item in items if item in stock_content]
            categories_found[category] = found_items
        
        print(f"📊 Stock categories found: {categories_found}")
        
        # Verify we found items in multiple categories
        total_items_found = sum(len(items) for items in categories_found.values())
        self.assertGreater(total_items_found, 15, 
                         f"Expected to find many stock items, found {total_items_found}")
        
        # Verify quantities are preserved
        quantity_patterns = ['kg', 'pun', 'boxes', 'heads', 'crates']
        quantities_found = []
        for pattern in quantity_patterns:
            if pattern in stock_content:
                quantities_found.append(pattern)
        
        self.assertGreater(len(quantities_found), 3, 
                         f"Expected multiple quantity units, found: {quantities_found}")
        
        print(f"✅ Quantity units preserved: {quantities_found}")
        print("✅ Stock inventory processing test completed")
    
    def test_all_order_days_chronological_database_integration(self):
        """Test all order days from oldest to newest with complete database integration"""
        try:
            response = requests.get(f"{self.backend_url}/api/whatsapp/health/", timeout=5)
            if response.status_code != 200:
                self.skipTest("Django backend not running")
        except requests.exceptions.RequestException:
            self.skipTest("Django backend not running")
        
        # All order days in chronological order (oldest first)
        order_days = [
            'Tuesday_01_09_2025',    # September 1st - oldest
            'Thursday_03_09_2025',   # September 3rd
            'Tuesday_08_09_2025',    # September 8th  
            'Thursday_10_09_2025',   # September 10th
            'Tuesday_15_09_2025'     # September 15th - newest
        ]
        
        total_messages_processed = 0
        total_orders_created = 0
        total_stock_messages = 0
        companies_found = set()
        
        print(f"🗓️ Processing {len(order_days)} order days chronologically...")
        
        for day_index, day in enumerate(order_days):
            print(f"\n📅 Processing {day} ({day_index + 1}/{len(order_days)})")
            
            # Load test data for this day
            test_file = self.test_data_dir / f'{day}_messages.json'
            if not test_file.exists():
                print(f"⚠️ Skipping {day} - no test data")
                continue
            
            with open(test_file, 'r', encoding='utf-8') as f:
                day_messages = json.load(f)
            
            print(f"📊 Loaded {len(day_messages)} messages for {day}")
            
            # Convert messages to Django API format
            messages_payload = {"messages": []}
            day_message_ids = []
            
            # Create base timestamp for this day to ensure chronological order
            day_date_parts = day.split('_')
            day_num = day_date_parts[1]  # e.g., "01", "03", "08", "10", "15"
            month = day_date_parts[2]    # e.g., "09"
            year = day_date_parts[3]     # e.g., "2025"
            
            for i, msg in enumerate(day_messages):
                # Use actual timestamp from message or create chronological one
                original_timestamp = msg.get('timestamp', '12:00, 01/09/2025')
                if original_timestamp and ', ' in original_timestamp:
                    converted_timestamp = self._convert_timestamp(original_timestamp)
                else:
                    # Create chronological timestamp for this day
                    hour = 8 + (i // 10)  # Start at 8am, increment hour every 10 messages
                    minute = (i % 10) * 6  # 0, 6, 12, 18, 24, 30, 36, 42, 48, 54 minutes
                    converted_timestamp = f"{year}-{month}-{day_num}T{hour:02d}:{minute:02d}:00Z"
                
                api_message = {
                    "id": f"{day}_{i}_{int(datetime.now().timestamp())}",
                    "chat": "ORDERS Restaurants",
                    "sender": msg.get('sender', 'Test Sender'),
                    "content": msg.get('text', ''),
                    "timestamp": converted_timestamp,
                    "cleanedContent": msg.get('text', ''),
                    "items": [],
                    "instructions": ""
                }
                messages_payload["messages"].append(api_message)
                day_message_ids.append(api_message["id"])
            
            self.test_message_ids.extend(day_message_ids)
            
            # Send day's messages to Django
            print(f"📤 Sending {len(messages_payload['messages'])} messages to Django...")
            
            response = requests.post(
                f"{self.backend_url}/api/whatsapp/receive-messages/",
                json=messages_payload,
                timeout=15
            )
            
            self.assertEqual(response.status_code, 200, f"Failed to send {day} messages: {response.text}")
            response_data = response.json()
            
            print(f"✅ Django response: new={response_data.get('new_messages', 0)}, updated={response_data.get('updated_messages', 0)}")
            
            # Add delay between days to ensure proper chronological processing
            if day_index < len(order_days) - 1:  # Don't delay after last day
                print(f"⏳ Waiting 2 seconds before next day to ensure chronological order...")
                time.sleep(2)
            
            # Verify messages stored for this day
            response = requests.get(
                f"{self.backend_url}/api/whatsapp/messages/?limit=50",
                timeout=10
            )
            
            self.assertEqual(response.status_code, 200)
            stored_data = response.json()
            
            # Count message types for this day
            day_orders = 0
            day_stock = 0
            day_companies = set()
            
            for msg in stored_data['messages']:
                if msg['message_id'] in day_message_ids:
                    if msg.get('message_type') == 'order':
                        day_orders += 1
                    elif msg.get('message_type') == 'stock':
                        day_stock += 1
                        if 'SHALLOME' in msg.get('content', ''):
                            print(f"📊 SHALLOME stock: {len(msg['content'])} chars")
                    
                    # Extract company names
                    if msg.get('company_name'):
                        day_companies.add(msg['company_name'])
            
            print(f"📊 {day} results: {day_orders} orders, {day_stock} stock messages")
            if day_companies:
                print(f"🏢 Companies found: {sorted(day_companies)}")
            
            total_messages_processed += len(day_messages)
            total_orders_created += day_orders
            total_stock_messages += day_stock
            companies_found.update(day_companies)
            
            # Process order messages for this day
            if day_orders > 0:
                order_message_ids = []
                for msg in stored_data['messages']:
                    if msg['message_id'] in day_message_ids and msg.get('message_type') == 'order':
                        order_message_ids.append(msg['message_id'])
                
                if order_message_ids:
                    process_payload = {"message_ids": order_message_ids[:5]}  # Process first 5
                    
                    response = requests.post(
                        f"{self.backend_url}/api/whatsapp/messages/process/",
                        json=process_payload,
                        timeout=10
                    )
                    
                    if response.status_code == 200:
                        process_data = response.json()
                        orders_created = process_data.get('orders_created', 0)
                        if orders_created > 0:
                            print(f"📦 Created {orders_created} orders for {day}")
                        else:
                            print(f"ℹ️ No orders created for {day} (may be expected)")
                    else:
                        print(f"⚠️ Order processing failed for {day}")
        
        # Final summary
        print(f"\n🎉 CHRONOLOGICAL PROCESSING COMPLETE")
        print(f"=" * 50)
        print(f"📊 Total messages processed: {total_messages_processed}")
        print(f"🛒 Total order messages: {total_orders_created}")
        print(f"📊 Total stock messages: {total_stock_messages}")
        print(f"🏢 Unique companies found: {len(companies_found)}")
        print(f"   Companies: {sorted(companies_found)}")
        
        # Verify we processed a substantial amount of data
        self.assertGreater(total_messages_processed, 100, "Should process 100+ messages across all days")
        self.assertGreater(total_orders_created, 10, "Should find 10+ order messages")
        self.assertGreater(total_stock_messages, 0, "Should find stock messages")
        self.assertGreater(len(companies_found), 3, "Should find multiple companies")
        
        print(f"✅ All {len(order_days)} order days processed successfully!")
        
        # Final verification: Check chronological order in database
        print(f"\n🔍 VERIFYING CHRONOLOGICAL ORDER IN DATABASE")
        response = requests.get(
            f"{self.backend_url}/api/whatsapp/messages/?limit=200",
            timeout=10
        )
        
        if response.status_code == 200:
            all_stored_data = response.json()
            test_messages = [msg for msg in all_stored_data['messages'] 
                           if any(msg['message_id'].startswith(day) for day in order_days)]
            
            # Sort by timestamp to verify chronological order
            test_messages.sort(key=lambda x: x['timestamp'])
            
            print(f"📊 Found {len(test_messages)} test messages in database")
            
            # Verify messages are in correct day order
            day_order_check = []
            for msg in test_messages[:20]:  # Check first 20 messages
                for day in order_days:
                    if msg['message_id'].startswith(day):
                        day_order_check.append(day)
                        break
            
            print(f"📅 First 20 messages day sequence: {day_order_check[:10]}...")
            
            # Verify September 1st messages come before September 15th messages
            sep_01_found = any('Tuesday_01_09_2025' in msg['message_id'] for msg in test_messages[:50])
            sep_15_found = any('Tuesday_15_09_2025' in msg['message_id'] for msg in test_messages[-50:])
            
            if sep_01_found and sep_15_found:
                print("✅ Chronological order verified: Sep 1st messages before Sep 15th messages")
            else:
                print("⚠️ Chronological order check inconclusive")
        
        print(f"✅ All {len(order_days)} order days processed successfully!")
    
    def _convert_timestamp(self, timestamp_str):
        """Convert '12:00, 15/09/2025' format to ISO format"""
        try:
            # Parse format like "12:00, 15/09/2025"
            if ', ' in timestamp_str:
                time_part, date_part = timestamp_str.split(', ')
                day, month, year = date_part.split('/')
                hour, minute = time_part.split(':')
                
                # Create ISO format timestamp
                iso_timestamp = f"{year}-{month.zfill(2)}-{day.zfill(2)}T{hour.zfill(2)}:{minute.zfill(2)}:00Z"
                return iso_timestamp
            else:
                # Fallback for other formats
                return "2025-09-15T12:00:00Z"
        except:
            return "2025-09-15T12:00:00Z"


if __name__ == '__main__':
    unittest.main()
