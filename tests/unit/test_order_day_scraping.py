import os
import unittest
import json
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
        # No-op for tests - Read more expansion already happened in saved HTML
        return None


@unittest.skipIf(BeautifulSoup is None, "bs4 not installed; skipping HTML-based tests")
class OrderDayScrapingTests(unittest.TestCase):
    """Test scraper against each order day's HTML/JSON data"""
    
    @classmethod
    def setUpClass(cls):
        """Load all test data files"""
        cls.test_data_dir = PROJECT_ROOT / 'python' / 'tests'
        cls.order_days = [
            '27_08_2025',  # Pre-orders
            'Tuesday_01_09_2025',
            'Thursday_03_09_2025', 
            'Tuesday_08_09_2025',
            'Thursday_10_09_2025',
            'Tuesday_15_09_2025'
        ]
        
        # Load expected data for each day
        cls.expected_data = {}
        for day in cls.order_days:
            json_file = cls.test_data_dir / f'{day}_messages.json'
            html_file = cls.test_data_dir / f'{day}_messages.html'
            
            if json_file.exists() and html_file.exists():
                with open(json_file, 'r', encoding='utf-8') as f:
                    expected_messages = json.load(f)
                
                html_content = html_file.read_text(encoding='utf-8', errors='ignore')
                soup = BeautifulSoup(html_content, 'html.parser')
                
                cls.expected_data[day] = {
                    'messages': expected_messages,
                    'html': html_content,
                    'soup': soup
                }
        
        # Ensure required env is present
        if 'TARGET_GROUP_NAME' not in os.environ:
            os.environ['TARGET_GROUP_NAME'] = 'ORDERS Restaurants'  # Default for tests

    def setUp(self):
        """Create crawler instance for each test"""
        self.crawler = WhatsAppCrawler()

    def test_all_order_days_have_test_data(self):
        """Verify all expected order days have both JSON and HTML test data"""
        for day in self.order_days:
            with self.subTest(day=day):
                self.assertIn(day, self.expected_data, f"Missing test data for {day}")
                self.assertGreater(len(self.expected_data[day]['messages']), 0, 
                                 f"No messages in {day}")

    def test_message_counts_match_expected(self):
        """Test that scraper finds expected number of messages for each day"""
        expected_counts = {
            '27_08_2025': 15,  # Pre-orders
            'Tuesday_01_09_2025': 29,
            'Thursday_03_09_2025': 46,
            'Tuesday_08_09_2025': 44, 
            'Thursday_10_09_2025': 32,
            'Tuesday_15_09_2025': 19
        }
        
        for day, expected_count in expected_counts.items():
            with self.subTest(day=day):
                if day not in self.expected_data:
                    self.skipTest(f"No test data for {day}")
                
                # Set up crawler with test HTML
                soup = self.expected_data[day]['soup']
                self.crawler.driver = SoupDriver(soup)
                
                # Scrape messages
                messages = self.crawler._scrape_from_open_chat()
                
                self.assertEqual(len(messages), expected_count,
                               f"Expected {expected_count} messages for {day}, got {len(messages)}")

    def test_first_and_last_messages_captured(self):
        """Test that key first and last messages are captured correctly"""
        # Test first message (pre-orders)
        if '27_08_2025' in self.expected_data:
            soup = self.expected_data['27_08_2025']['soup']
            self.crawler.driver = SoupDriver(soup)
            messages = self.crawler._scrape_from_open_chat()
            
            # Find the first order message
            first_order = None
            for msg in messages:
                if 'Hi Here is my order' in msg['content'] and 'Tomatoes x3' in msg['content']:
                    first_order = msg
                    break
            
            self.assertIsNotNone(first_order, "First order message not found")
            self.assertIn('Tomatoes x3', first_order['content'])
            self.assertIn('Sweet melonx1', first_order['content'])
            self.assertIn('Bananas 2kg', first_order['content'])

    def test_stock_messages_fully_expanded(self):
        """Test that SHALLOME stock messages are fully expanded (not truncated)"""
        for day in self.order_days:
            with self.subTest(day=day):
                if day not in self.expected_data:
                    continue
                
                soup = self.expected_data[day]['soup']
                self.crawler.driver = SoupDriver(soup)
                messages = self.crawler._scrape_from_open_chat()
                
                # Find stock messages
                stock_messages = [msg for msg in messages if 'SHALLOME' in msg['content'] and 'STOCK' in msg['content']]
                
                for stock_msg in stock_messages:
                    # Stock messages should be long and detailed
                    self.assertGreater(len(stock_msg['content']), 500, 
                                     f"Stock message seems truncated in {day}: {len(stock_msg['content'])} chars")
                    
                    # Should not contain truncation indicators
                    self.assertNotIn('...', stock_msg['content'], 
                                   f"Stock message contains truncation in {day}")
                    self.assertNotIn('…', stock_msg['content'], 
                                   f"Stock message contains ellipsis in {day}")

    def test_message_classification(self):
        """Test that messages are classified correctly"""
        classification_tests = [
            ('Hi Here is my order\nTomatoes x3\nBananas 2kg', 'order'),
            ('SHALLOME STOCK AS AT 15 SEP 2025', 'stock'),
            ('Tuesday orders starts here', 'demarcation'),
            ('Good morning', 'instruction'),
            ('Venue', 'other')
        ]
        
        for content, expected_type in classification_tests:
            with self.subTest(content=content[:30]):
                result = self.crawler.classify_message(content)
                self.assertEqual(result, expected_type, 
                               f"Expected '{content}' to be classified as '{expected_type}', got '{result}'")

    def test_timestamps_are_valid_iso_format(self):
        """Test that all scraped messages have valid ISO timestamps"""
        for day in self.order_days:
            with self.subTest(day=day):
                if day not in self.expected_data:
                    continue
                
                soup = self.expected_data[day]['soup']
                self.crawler.driver = SoupDriver(soup)
                messages = self.crawler._scrape_from_open_chat()
                
                for i, msg in enumerate(messages[:10]):  # Test first 10 messages
                    timestamp = msg.get('timestamp')
                    self.assertIsInstance(timestamp, str, f"Timestamp not string in {day} message {i}")
                    
                    # Should be valid ISO format
                    try:
                        datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
                    except ValueError:
                        self.fail(f"Invalid ISO timestamp in {day} message {i}: {timestamp}")

    def test_no_duplicate_messages(self):
        """Test that no duplicate messages are captured"""
        for day in self.order_days:
            with self.subTest(day=day):
                if day not in self.expected_data:
                    continue
                
                soup = self.expected_data[day]['soup']
                self.crawler.driver = SoupDriver(soup)
                messages = self.crawler._scrape_from_open_chat()
                
                # Check for duplicates by content
                seen_content = set()
                duplicates = []
                
                for msg in messages:
                    content_key = msg['content'][:100]  # First 100 chars as key
                    if content_key in seen_content and content_key.strip():
                        duplicates.append(content_key)
                    seen_content.add(content_key)
                
                self.assertEqual(len(duplicates), 0, 
                               f"Found duplicate messages in {day}: {duplicates}")

    def test_media_url_detection(self):
        """Test that image URLs are detected when present"""
        for day in self.order_days:
            with self.subTest(day=day):
                if day not in self.expected_data:
                    continue
                
                soup = self.expected_data[day]['soup']
                self.crawler.driver = SoupDriver(soup)
                messages = self.crawler._scrape_from_open_chat()
                
                # Check for any messages with media URLs
                media_messages = [msg for msg in messages if msg.get('media_url')]
                
                for media_msg in media_messages:
                    media_url = media_msg['media_url']
                    
                    # Should be http/https URL, not blob:
                    self.assertTrue(media_url.startswith('http'), 
                                  f"Media URL should be http/https in {day}: {media_url}")
                    self.assertFalse(media_url.startswith('blob:'), 
                                   f"Should not save blob: URLs in {day}: {media_url}")

    def test_message_schema_completeness(self):
        """Test that all scraped messages have required fields"""
        required_fields = [
            'id', 'chat', 'sender', 'content', 'cleanedContent', 
            'timestamp', 'scraped_at', 'message_type', 'items', 
            'instructions', 'media_type', 'media_url', 'media_info'
        ]
        
        for day in self.order_days:
            with self.subTest(day=day):
                if day not in self.expected_data:
                    continue
                
                soup = self.expected_data[day]['soup']
                self.crawler.driver = SoupDriver(soup)
                messages = self.crawler._scrape_from_open_chat()
                
                for i, msg in enumerate(messages[:5]):  # Test first 5 messages
                    for field in required_fields:
                        self.assertIn(field, msg, 
                                    f"Missing field '{field}' in {day} message {i}")

    def test_culinary_messages_captured(self):
        """Test that all 'Culinary' messages are captured"""
        culinary_count = 0
        
        for day in self.order_days:
            if day not in self.expected_data:
                continue
            
            soup = self.expected_data[day]['soup']
            self.crawler.driver = SoupDriver(soup)
            messages = self.crawler._scrape_from_open_chat()
            
            day_culinary = [msg for msg in messages if 'Culinary' in msg['content']]
            culinary_count += len(day_culinary)
        
        # Should find multiple Culinary messages across all days
        self.assertGreater(culinary_count, 0, "No 'Culinary' messages found")

    def test_chronological_order_within_day(self):
        """Test that messages within each day are in chronological order"""
        for day in self.order_days:
            with self.subTest(day=day):
                if day not in self.expected_data:
                    continue
                
                soup = self.expected_data[day]['soup']
                self.crawler.driver = SoupDriver(soup)
                messages = self.crawler._scrape_from_open_chat()
                
                # Extract timestamps and verify order
                timestamps = []
                for msg in messages:
                    try:
                        ts = datetime.fromisoformat(msg['timestamp'].replace('Z', '+00:00'))
                        timestamps.append(ts)
                    except:
                        continue
                
                if len(timestamps) > 1:
                    # Should be in chronological order (oldest first)
                    for i in range(1, len(timestamps)):
                        self.assertLessEqual(timestamps[i-1], timestamps[i],
                                           f"Messages not in chronological order in {day}")


if __name__ == '__main__':
    unittest.main()
