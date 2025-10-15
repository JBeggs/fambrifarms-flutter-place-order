#!/usr/bin/env python3
"""
Test the new quantity extraction logic without Flask dependencies
"""
import re

def extract_quantity(text):
    """Extract quantity from text - understanding multipliers vs packaging"""
    
    # Clean the text
    text = text.strip().lower()
    
    # Pattern 1: "2 x 10kg" - multiplier pattern
    multiplier_match = re.search(r'^(\d+)\s*[x×*]\s*\d+\s*(kg|box|bags?|pcs?|pieces?|pkts?|packets?|heads?|bunches?)', text)
    if multiplier_match:
        return multiplier_match.group(1)
    
    # Pattern 2: "3 bags", "5 boxes" - quantity + container
    container_match = re.search(r'^(\d+)\s+(bags?|boxes?|pcs?|pieces?|pkts?|packets?|heads?|bunches?)', text)
    if container_match:
        return container_match.group(1)
    
    # Pattern 3: "2 x" at start - multiplier without packaging
    simple_multiplier = re.search(r'^(\d+)\s*[x×*]', text)
    if simple_multiplier:
        return simple_multiplier.group(1)
    
    # Pattern 3b: "x12" at end - multiplier at end
    end_multiplier = re.search(r'\s+[x×*](\d+)$', text)
    if end_multiplier:
        return end_multiplier.group(1)
    
    # Pattern 4: Just packaging size like "5kg tomatoes" - quantity is 1
    packaging_only = re.search(r'^\d+\s*(kg|g|ml|l)\s+\w+', text)
    if packaging_only:
        return "1"
    
    # Pattern 5: Leading number that's clearly a quantity
    leading_number = re.search(r'^(\d+)\s+', text)
    if leading_number:
        return leading_number.group(1)
    
    # Default: assume quantity is 1
    return "1"

def extract_product_name(text):
    """Extract product name while preserving packaging information"""
    
    # Clean the text
    text = text.strip()
    
    # Remove multiplier patterns but keep packaging
    # "2 x 10kg tomatoes" -> "10kg tomatoes"
    text = re.sub(r'^\d+\s*[x×*]\s*', '', text)
    
    # Remove leading quantity + container words but keep packaging sizes
    # "3 bags 5kg potatoes" -> "5kg potatoes"
    # "3 bags potatoes" -> "potatoes"
    text = re.sub(r'^\d+\s+(bags?|boxes?|pcs?|pieces?|pkts?|packets?|heads?|bunches?)\s*', '', text)
    
    # Remove "bags" or "box" that appears after packaging size
    # "10kg bags red onions" -> "10kg red onions"
    text = re.sub(r'(\d+\s*(kg|g|ml|l))\s+(bags?|boxes?)\s*', r'\1 ', text)
    
    # Remove standalone quantity at start if followed by space
    # "5 tomatoes" -> "tomatoes" (but keep "5kg tomatoes")
    text = re.sub(r'^\d+\s+(?!\d*(kg|g|ml|l|box|bag))', '', text)
    
    # Clean up extra spaces
    text = re.sub(r'\s+', ' ', text).strip()
    
    return text

if __name__ == "__main__":
    print('🧪 TESTING QUANTITY EXTRACTION:')
    print('=' * 50)

    test_cases = [
        '2 x 10kg bags red onions',
        '2 x 10kg bags butternut', 
        '5kg tomatoes',
        '3 bags potatoes',
        '10 boxes lettuce',
        '1 x 5kg carrots',
        '15 heads cauliflower',
        '2×5kgTomato',
        '3 x veg box',
        'Baby spinach x12',
        '5 box lettuce',
        '20kg potato'
    ]

    for test in test_cases:
        qty = extract_quantity(test)
        product = extract_product_name(test)
        print(f'Input: "{test}"')
        print(f'  → Qty: {qty}, Product: "{product}"')
        print()
        
    print('🎯 EXPECTED RESULTS:')
    print('- "2 x 10kg bags red onions" → Qty: 2, Product: "10kg red onions"')
    print('- "5kg tomatoes" → Qty: 1, Product: "5kg tomatoes"')
    print('- "3 bags potatoes" → Qty: 3, Product: "potatoes"')
