#!/usr/bin/env python3
"""
Test script for the MessageParser to validate parsing logic
Tests the examples from @ai_sucks.md to ensure correct company-order assignment
"""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))

from app.core.message_parser import MessageParser

def create_test_message(content, msg_id=None, timestamp="2025-09-14T10:00:00Z"):
    """Create a test message object"""
    return {
        "id": msg_id or f"test_{hash(content)}",
        "content": content,
        "timestamp": timestamp,
        "sender": "Test User"
    }

def test_parsing_examples():
    """Test parsing with examples from @ai_sucks.md"""
    parser = MessageParser()
    
    print("🧪 Testing MessageParser with examples from @ai_sucks.md")
    print("=" * 60)
    
    # Test Case 1: Items-before-company pattern (Venue)
    print("\n📋 Test Case 1: Venue Order (Items-before-company pattern)")
    messages = [
        create_test_message("Good morning may I please order \n2×5kgTomato \n2×5kgMushroom \n10kgOnions \nTnx that's all", "msg_8"),
        create_test_message("Venue", "msg_9")
    ]
    
    orders = parser.parse_messages_to_orders(messages)
    print(f"📊 Result: {len(orders)} orders found")
    
    if orders:
        venue_order = orders[0]
        print(f"✅ Company: {venue_order['company_name']}")
        print(f"✅ Items: {venue_order['items_text']}")
        print(f"✅ Instructions: {venue_order['instructions']}")
        
        # Validate expected results
        expected_items = ["2×5kgTomato", "2×5kgMushroom", "10kgOnions"]
        expected_instructions = ["Good morning may I please order", "Tnx that's all"]
        
        if venue_order['company_name'] == "Venue" and set(venue_order['items_text']) == set(expected_items):
            print("✅ PASS: Venue order parsed correctly")
        else:
            print("❌ FAIL: Venue order parsing incorrect")
    else:
        print("❌ FAIL: No orders found for Venue")
    
    # Test Case 2: Large order (Debonairs)
    print("\n📋 Test Case 2: Debonairs Order (Large multi-line)")
    messages = [
        create_test_message("Morning, Here's my order\nTomatoes x3box\nOnions 10kg \nBaby spinach x12\nRocket x2 \nLemon x3\nRed cabage x2\nCarrots 3kg \nMushrooms x 20\nMix lettuce x3\nCherry tomatoes x15 200g\nBanana 2kg \nOrange 2kg\nParsley x1 \nMicro greens x2\nCoriander x1 \nGrapesx1 \nThanks", "msg_10"),
        create_test_message("Debonairs", "msg_11")
    ]
    
    orders = parser.parse_messages_to_orders(messages)
    print(f"📊 Result: {len(orders)} orders found")
    
    if orders:
        debonairs_order = orders[0]
        print(f"✅ Company: {debonairs_order['company_name']}")
        print(f"✅ Items count: {len(debonairs_order['items_text'])}")
        print(f"✅ Sample items: {debonairs_order['items_text'][:3]}")
        print(f"✅ Instructions: {debonairs_order['instructions']}")
        
        if debonairs_order['company_name'] == "Debonairs" and len(debonairs_order['items_text']) >= 15:
            print("✅ PASS: Debonairs order parsed correctly")
        else:
            print("❌ FAIL: Debonairs order parsing incorrect")
    else:
        print("❌ FAIL: No orders found for Debonairs")
    
    # Test Case 3: Marco sequence (multiple messages)
    print("\n📋 Test Case 3: Marco Order (Multiple messages)")
    messages = [
        create_test_message("3x veg box for Thursday", "msg_13"),
        create_test_message("Marco", "msg_14"),
        create_test_message("Please add eggs to Marco boxes", "msg_15")
    ]
    
    orders = parser.parse_messages_to_orders(messages)
    print(f"📊 Result: {len(orders)} orders found")
    
    if orders:
        marco_order = orders[0]
        print(f"✅ Company: {marco_order['company_name']}")
        print(f"✅ Items: {marco_order['items_text']}")
        print(f"✅ Instructions: {marco_order['instructions']}")
        
        # Should consolidate into one order with both items
        expected_items = ["3x veg box for Thursday", "eggs"]
        if marco_order['company_name'] == "Marco" and len(orders) == 1:
            print("✅ PASS: Marco order consolidated correctly")
        else:
            print("❌ FAIL: Marco order should be consolidated into 1 order")
    else:
        print("❌ FAIL: No orders found for Marco")
    
    # Test Case 4: Casa Bella (large order)
    print("\n📋 Test Case 4: Casa Bella Order")
    messages = [
        create_test_message("20kg potato\n3kg butternut\n7kg sweet potato\n10kg red onion\n4kg semi tomato\n7kg brown mushroom\n7kg porta mushroom\n3kg red pepper\n4kg carrots\n2kg red chilli\n2kg green chilli\n7kg baby marrow\n10×cucumber\n15kg lemon\n5kg spinach\n750g wild rocket\n750g basil leaves\n750g rosemary\n5×baby corn\n5×mixed lettuce\n750g strawberry\n1kg lime\n1kg banana\n3 box avos\n750g parsley", "msg_23"),
        create_test_message("Casa Bella", "msg_24")
    ]
    
    orders = parser.parse_messages_to_orders(messages)
    print(f"📊 Result: {len(orders)} orders found")
    
    if orders:
        casa_order = orders[0]
        print(f"✅ Company: {casa_order['company_name']}")
        print(f"✅ Items count: {len(casa_order['items_text'])}")
        print(f"✅ Sample items: {casa_order['items_text'][:5]}")
        
        if casa_order['company_name'] == "Casa Bella" and len(casa_order['items_text']) >= 20:
            print("✅ PASS: Casa Bella order parsed correctly")
        else:
            print("❌ FAIL: Casa Bella order parsing incorrect")
    else:
        print("❌ FAIL: No orders found for Casa Bella")
    
    # Test Case 5: Mixed content (Luma)
    print("\n📋 Test Case 5: Luma Order (Mixed content)")
    messages = [
        create_test_message("Hie, pliz send for Luma\n3* punnets strawberries\n1* bag red onions\n1* bag oranges", "msg_25"),
        create_test_message("Luma", "msg_26")
    ]
    
    orders = parser.parse_messages_to_orders(messages)
    print(f"📊 Result: {len(orders)} orders found")
    
    if orders:
        luma_order = orders[0]
        print(f"✅ Company: {luma_order['company_name']}")
        print(f"✅ Items: {luma_order['items_text']}")
        print(f"✅ Instructions: {luma_order['instructions']}")
        
        # Should have items and "Hie, pliz send for Luma" as instruction
        expected_items = ["3* punnets strawberries", "1* bag red onions", "1* bag oranges"]
        if (luma_order['company_name'] == "Luma" and 
            set(luma_order['items_text']) == set(expected_items) and
            len(orders) == 1):
            print("✅ PASS: Luma order parsed correctly")
        else:
            print("❌ FAIL: Luma order parsing incorrect")
    else:
        print("❌ FAIL: No orders found for Luma")
    
    print("\n" + "=" * 60)
    print("🎯 Test Summary Complete")

def test_company_aliases():
    """Test company alias resolution"""
    parser = MessageParser()
    
    print("\n🏢 Testing Company Aliases")
    print("-" * 30)
    
    test_cases = [
        ("mugg and bean", "Mugg and Bean"),
        ("mugg bean", "Mugg and Bean"),
        ("mugg", "Mugg and Bean"),
        ("venue", "Venue"),
        ("debonairs", "Debonairs"),
        ("casa bella", "Casa Bella"),
        ("casabella", "Casa Bella"),
        ("wimpy mooinooi", "Wimpy"),
        ("t-junction", "T-junction"),
        ("t junction", "T-junction"),
    ]
    
    for input_text, expected in test_cases:
        result = parser.to_canonical_company(input_text)
        if result == expected:
            print(f"✅ '{input_text}' → '{result}'")
        else:
            print(f"❌ '{input_text}' → '{result}' (expected '{expected}')")

def test_quantity_detection():
    """Test quantity pattern detection"""
    parser = MessageParser()
    
    print("\n🔢 Testing Quantity Detection")
    print("-" * 30)
    
    test_cases = [
        ("2×5kgTomato", True),
        ("10kgOnions", True),
        ("3x veg box", True),
        ("Baby spinach x12", True),
        ("Cherry tomatoes x15 200g", True),
        ("Good morning", False),
        ("Thanks", False),
        ("Please add eggs", False),
        ("5 box lettuce", True),
        ("20kg potato", True),
    ]
    
    for text, expected in test_cases:
        result = parser.has_quantity_indicators(text)
        if result == expected:
            print(f"✅ '{text}' → {result}")
        else:
            print(f"❌ '{text}' → {result} (expected {expected})")

if __name__ == "__main__":
    print("🚀 Starting MessageParser Tests")
    print("Testing parsing logic from @ai_sucks.md examples")
    
    test_company_aliases()
    test_quantity_detection()
    test_parsing_examples()
    
    print("\n✅ All tests completed!")
