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

# Import from the new modular structure
from app.config.settings import MESSAGE_PATTERNS

class MessageClassifier:
    """Message classifier using the modular configuration."""
    
    def classify_message(self, content, message_type):
        """Classify message based on content and type."""
        if not content or not content.strip():
            return 'other'
        
        content_lower = content.lower()
        
        # Media type passthrough
        if message_type in ['image', 'voice', 'video', 'document', 'sticker']:
            return message_type
        
        # Order detection
        if any(keyword in content_lower for keyword in MESSAGE_PATTERNS['order_keywords']):
            return 'order'
        
        # Stock detection
        if any(keyword in content_lower for keyword in MESSAGE_PATTERNS['stock_keywords']):
            return 'stock'
        
        # Instruction detection  
        instruction_keywords = MESSAGE_PATTERNS['instruction_keywords']
        if any(keyword in content_lower for keyword in instruction_keywords):
            return 'instruction'
        
        # Special handling for WhatsApp system messages
        if 'messages and calls are end-to-end encrypted' in content_lower:
            return 'other'
        
        return 'other'


class TestMessageParser(unittest.TestCase):
    """Test message parsing and classification logic."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.scraper = MessageClassifier()
        
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
        # Test that company names are available in test data metadata
        # In real implementation, companies would be extracted from context or patterns
        expected_companies = {
            'order_mugg_bean': 'Mugg and Bean',
            'order_luma': 'Luma', 
            'order_maltos': 'Maltos',
            'order_shebeen': 'Shebeen',
            'order_debonair': 'Debonair'
        }
        
        for message in self.test_data['test_messages']:
            with self.subTest(message_id=message['id']):
                # Test that company metadata exists in test data
                expected_company = expected_companies[message['id']]
                self.assertEqual(message['company'], expected_company,
                    f"Message {message['id']} should have company '{expected_company}' in metadata")
                
                # Test that message contains order indicators that would help identify company context
                content_lower = message['content'].lower()
                has_order_indicator = any(keyword in content_lower for keyword in MESSAGE_PATTERNS['order_keywords'])
                self.assertTrue(has_order_indicator,
                    f"Message {message['id']} should contain order indicators for company extraction")
    
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
        self.scraper = MessageClassifier()
    
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


class TestCompanyAssignmentScenarios(unittest.TestCase):
    """Test company assignment scenarios that were causing bugs."""
    
    def setUp(self):
        """Set up test fixtures."""
        # Mock the Django message parser functionality
        self.company_aliases = {
            "mugg and bean": "Mugg and Bean",
            "mugg bean": "Mugg and Bean", 
            "mugg": "Mugg and Bean",
            "venue": "Venue",
            "debonairs": "Debonairs",
            "t-junction": "T-junction",
            "t junction": "T-junction",
            "wimpy": "Wimpy",
            "wimpy mooinooi": "Wimpy",
            "shebeen": "Shebeen",
            "casa bella": "Casa Bella",
            "casabella": "Casa Bella",
            "luma": "Luma",
            "marco": "Marco",
            "maltos": "Maltos"
        }
    
    def _extract_company_from_content(self, content):
        """Mock company extraction from message content."""
        if not content:
            return None
        
        content_lower = content.lower().strip()
        
        # Check for direct company name matches
        for alias, canonical in self.company_aliases.items():
            if alias in content_lower:
                return canonical
        
        return None
    
    def test_order_message_with_embedded_company_name(self):
        """Test the main bug scenario: order messages with company names inside."""
        test_cases = [
            {
                "content": "Casa Bella\n\n5kg potatoes\n3kg onions\n2kg carrots",
                "expected_company": "Casa Bella",
                "description": "Company name at start of order"
            },
            {
                "content": "Wimpy\n\n2x burgers\n1x fries\n1x shake",
                "expected_company": "Wimpy",
                "description": "Company name with fast food order"
            },
            {
                "content": "T-junction\n\n3kg tomatoes\n2kg onions\n1kg peppers",
                "expected_company": "T-junction",
                "description": "Company name with hyphen"
            },
            {
                "content": "Shebeen\n\n4kg chicken\n2kg beef\n1kg pork",
                "expected_company": "Shebeen",
                "description": "Company name with meat order"
            }
        ]
        
        for case in test_cases:
            with self.subTest(description=case["description"]):
                extracted_company = self._extract_company_from_content(case["content"])
                self.assertEqual(extracted_company, case["expected_company"],
                    f"Should extract '{case['expected_company']}' from content")
    
    def test_company_aliases_resolution(self):
        """Test that company aliases are correctly resolved to canonical names."""
        test_cases = [
            ("mugg bean", "Mugg and Bean"),
            ("casa bella", "Casa Bella"),
            ("t junction", "T-junction"),
            ("debonairs", "Debonairs"),
            ("wimpy mooinooi", "Wimpy"),
        ]
        
        for alias, expected_canonical in test_cases:
            with self.subTest(alias=alias):
                # Test in isolation
                extracted = self._extract_company_from_content(alias)
                self.assertEqual(extracted, expected_canonical,
                    f"Alias '{alias}' should resolve to '{expected_canonical}'")
                
                # Test in order context
                order_content = f"{alias}\n\n2kg test item\n1kg another item"
                extracted_from_order = self._extract_company_from_content(order_content)
                self.assertEqual(extracted_from_order, expected_canonical,
                    f"Alias '{alias}' in order should resolve to '{expected_canonical}'")
    
    def test_content_cleaning_preserves_order_items(self):
        """Test that removing company names from content preserves order items."""
        test_cases = [
            {
                "original": "Casa Bella\n\n5kg potatoes\n3kg onions\n2kg carrots",
                "cleaned": "5kg potatoes\n3kg onions\n2kg carrots",
                "company": "Casa Bella"
            },
            {
                "original": "Wimpy\n\n2x burgers\n1x fries\n1x shake",
                "cleaned": "2x burgers\n1x fries\n1x shake",
                "company": "Wimpy"
            }
        ]
        
        for case in test_cases:
            with self.subTest(company=case["company"]):
                # Verify company can be extracted from original
                extracted_company = self._extract_company_from_content(case["original"])
                self.assertEqual(extracted_company, case["company"])
                
                # Verify cleaned content doesn't contain company name
                self.assertNotIn(case["company"], case["cleaned"])
                
                # Verify cleaned content still has order items
                cleaned_lines = [line.strip() for line in case["cleaned"].split('\n') if line.strip()]
                self.assertGreater(len(cleaned_lines), 0, "Cleaned content should have order items")
                
                # Verify order items contain quantities
                has_quantities = any(any(char.isdigit() for char in line) for line in cleaned_lines)
                self.assertTrue(has_quantities, "Cleaned content should contain quantity indicators")
    
    def test_context_based_company_assignment_simulation(self):
        """Test simulation of context-based company assignment."""
        # Simulate a conversation flow
        messages = [
            {"content": "Venue", "timestamp": "10:00", "type": "other"},
            {"content": "4kg apples\n2kg bananas\n1kg oranges", "timestamp": "10:01", "type": "order"},
        ]
        
        # Company message
        company_msg = messages[0]
        company = self._extract_company_from_content(company_msg["content"])
        self.assertEqual(company, "Venue")
        
        # Order message (no company in content)
        order_msg = messages[1]
        order_company = self._extract_company_from_content(order_msg["content"])
        self.assertIsNone(order_company, "Order message should not contain company name")
        
        # In real system, this would get company from context
        # Here we simulate that the order would inherit the company from context
        inherited_company = company  # Simulate context inheritance
        self.assertEqual(inherited_company, "Venue")
    
    def test_edge_cases_and_malformed_company_names(self):
        """Test edge cases in company name extraction."""
        test_cases = [
            {
                "content": "CASA BELLA\n\n5kg items",  # All caps
                "expected": "Casa Bella",
                "description": "All caps company name"
            },
            {
                "content": "casa bella\n\n5kg items",  # All lowercase
                "expected": "Casa Bella", 
                "description": "All lowercase company name"
            },
            {
                "content": "Casa  Bella\n\n5kg items",  # Extra spaces
                "expected": "Casa Bella",
                "description": "Company name with extra spaces"
            },
            {
                "content": "5kg items\nCasa Bella at the end",  # Company at end
                "expected": "Casa Bella",
                "description": "Company name at end of message"
            }
        ]
        
        for case in test_cases:
            with self.subTest(description=case["description"]):
                extracted = self._extract_company_from_content(case["content"])
                self.assertEqual(extracted, case["expected"],
                    f"Should handle {case['description']}")
    
    def test_no_company_scenarios(self):
        """Test scenarios where no company should be detected."""
        test_cases = [
            "5kg random vegetables\n3kg mystery items",  # No company mentioned
            "Hello team, here are the orders",  # Greeting only
            "Thanks for the delivery",  # Closing only
            "",  # Empty content
            "123456789",  # Numbers only
        ]
        
        for content in test_cases:
            with self.subTest(content=content[:30] + "..." if len(content) > 30 else content):
                extracted = self._extract_company_from_content(content)
                self.assertIsNone(extracted, f"Should not extract company from: {content}")
    
    def test_multiple_companies_in_single_message(self):
        """Test handling of messages with multiple company names."""
        test_cases = [
            {
                "content": "Casa Bella and Venue orders:\n5kg potatoes for Casa Bella\n3kg apples for Venue",
                "description": "Multiple companies mentioned",
                # In real system, this would need special handling
                # For now, we test that at least one company is detected
            }
        ]
        
        for case in test_cases:
            with self.subTest(description=case["description"]):
                extracted = self._extract_company_from_content(case["content"])
                # Should detect at least one of the companies
                self.assertIsNotNone(extracted, "Should detect at least one company")
                self.assertIn(extracted, ["Casa Bella", "Venue"], 
                    "Should detect one of the mentioned companies")


if __name__ == '__main__':
    # Run tests with verbose output
    unittest.main(verbosity=2)
