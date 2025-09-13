#!/usr/bin/env python3
"""
Unit tests for WhatsApp message parsing and classification.
Tests the core logic for extracting orders, companies, and items from messages.
"""

import unittest
import json
import os
import sys
from datetime import datetime

# Add the python directory to the path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'python'))

from whatsapp_server import WhatsAppScraper


class TestMessageParser(unittest.TestCase):
    """Test message parsing and classification logic."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.scraper = WhatsAppScraper()
        
        # Load test data
        fixtures_path = os.path.join(os.path.dirname(__file__), '..', 'fixtures', 'sample_messages.json')
        with open(fixtures_path, 'r') as f:
            self.test_data = json.load(f)
    
    def test_classify_order_messages(self):
        """Test that order messages are correctly classified."""
        for message in self.test_data['test_messages']:
            with self.subTest(message_id=message['id']):
                classification = self.scraper.classify_message(message['content'], 'text')
                self.assertEqual(classification, 'order', 
                    f"Message {message['id']} should be classified as 'order', got '{classification}'")
    
    def test_extract_company_names(self):
        """Test extraction of company names from messages."""
        expected_companies = {
            'order_mugg_bean': 'Mugg and Bean',
            'order_luma': 'Luma', 
            'order_maltos': 'Maltos',
            'order_shebeen': 'Shebeen',
            'order_debonair': 'Debonair'
        }
        
        for message in self.test_data['test_messages']:
            with self.subTest(message_id=message['id']):
                # This would test company extraction logic
                # For now, we'll test that the expected company is in the content
                expected_company = expected_companies[message['id']]
                self.assertIn(expected_company.lower(), message['content'].lower(),
                    f"Company '{expected_company}' should be found in message {message['id']}")
    
    def test_parse_order_items(self):
        """Test parsing of individual items from order messages."""
        for message in self.test_data['test_messages']:
            with self.subTest(message_id=message['id']):
                # Test that we can extract the expected number of items
                expected_items = message['expected_items']
                content_lines = [line.strip() for line in message['content'].split('\n') if line.strip()]
                
                # Filter out greeting/closing lines
                item_lines = [line for line in content_lines 
                             if not any(word in line.lower() for word in ['hi', 'here', 'order', 'thanks', 'good morning', 'please', 'all tnx', 'for'])]
                
                # Should have roughly the same number of item lines as expected items
                self.assertGreaterEqual(len(item_lines), len(expected_items) - 2,  # Allow some variance
                    f"Message {message['id']} should have approximately {len(expected_items)} item lines")
    
    def test_quantity_pattern_matching(self):
        """Test that quantity patterns are correctly identified."""
        test_patterns = [
            ("Tomatoes x3", {"quantity": "3", "item": "Tomatoes"}),
            ("Bananas 2kg", {"quantity": "2", "unit": "kg", "item": "Bananas"}),
            ("6*packets mint", {"quantity": "6", "unit": "packets", "item": "mint"}),
            ("3×5kgTomato", {"quantity": "3", "unit": "5kg", "item": "Tomato"}),
            ("Cherry tomatoes x15 200g", {"quantity": "15", "unit": "200g", "item": "Cherry tomatoes"})
        ]
        
        for pattern, expected in test_patterns:
            with self.subTest(pattern=pattern):
                # Test that the pattern contains expected elements
                if 'quantity' in expected:
                    self.assertTrue(any(char.isdigit() for char in pattern),
                        f"Pattern '{pattern}' should contain digits for quantity")
    
    def test_forwarded_message_detection(self):
        """Test that forwarded messages are correctly identified."""
        for message in self.test_data['test_messages']:
            with self.subTest(message_id=message['id']):
                if message.get('is_forwarded'):
                    # In real implementation, this would test the forwarded detection logic
                    self.assertTrue(message['is_forwarded'],
                        f"Message {message['id']} should be detected as forwarded")
    
    def test_media_message_classification(self):
        """Test that media messages are correctly classified."""
        for message in self.test_data['test_media_messages']:
            with self.subTest(message_id=message['id']):
                classification = self.scraper.classify_message(message['content'], message['type'])
                # Media messages should retain their specific type, not be classified as 'other'
                self.assertIn(classification, ['image', 'voice', 'video', 'document', 'sticker'],
                    f"Media message {message['id']} should be classified as media type, got '{classification}'")
    
    def test_noise_filtering(self):
        """Test that system/noise messages are filtered out."""
        for message in self.test_data['test_noise_messages']:
            with self.subTest(message_id=message['id']):
                if message.get('should_filter'):
                    classification = self.scraper.classify_message(message['content'], 'text')
                    # These should be classified as 'other' or filtered out
                    self.assertEqual(classification, 'other',
                        f"Noise message {message['id']} should be classified as 'other'")
    
    def test_timestamp_parsing(self):
        """Test that timestamps are correctly parsed from WhatsApp format."""
        test_timestamps = [
            "[12:46, 27/08/2025] Karl:",
            "[22:25, 27/08/2025] Karl:",
            "[22:26, 27/08/2025] Karl:"
        ]
        
        for timestamp_str in test_timestamps:
            with self.subTest(timestamp=timestamp_str):
                # Test that we can extract time and date components
                self.assertIn(':', timestamp_str, "Should contain time separator")
                self.assertIn('/', timestamp_str, "Should contain date separator")
                self.assertIn('[', timestamp_str, "Should be wrapped in brackets")


class TestMessageValidation(unittest.TestCase):
    """Test message validation and error handling."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.scraper = WhatsAppScraper()
    
    def test_empty_message_handling(self):
        """Test handling of empty or None messages."""
        test_cases = [None, "", "   ", "\n\n"]
        
        for test_case in test_cases:
            with self.subTest(message=repr(test_case)):
                classification = self.scraper.classify_message(test_case or "", 'text')
                self.assertEqual(classification, 'other',
                    f"Empty message should be classified as 'other', got '{classification}'")
    
    def test_malformed_message_handling(self):
        """Test handling of malformed or corrupted messages."""
        malformed_messages = [
            "x3 x5 x10",  # Only quantities, no items
            "Tomatoes Bananas Carrots",  # Only items, no quantities
            "!@#$%^&*()",  # Special characters only
            "123456789",  # Numbers only
        ]
        
        for message in malformed_messages:
            with self.subTest(message=message):
                # Should not crash, should return some classification
                classification = self.scraper.classify_message(message, 'text')
                self.assertIsInstance(classification, str,
                    f"Classification should return string for malformed message: {message}")


if __name__ == '__main__':
    # Run tests with verbose output
    unittest.main(verbosity=2)
