# Backend Search Fix Required - Product Suggestions Endpoint

## Issue
When searching for "3 avocado hard" in the confirm order items dialog, no results are returned. However, if "hard" is removed, results are found. The user confirms that both "hard" and "avocado" are present in the product name.

## Endpoint
`POST /whatsapp/products/get-suggestions/`
- Request body: `{'product_name': '3 avocado hard'}`
- Expected: Should return products matching "avocado" and "hard" even if they appear in different order or with other words

## Root Cause Analysis

The backend Django view is likely using one of these problematic search patterns:

### Problem 1: Exact Phrase Matching
```python
# Current (WRONG):
Product.objects.filter(name__icontains="avocado hard")
# This requires "avocado hard" to appear as an exact substring
# Won't match: "Avocado Hard" (different case/spacing)
# Won't match: "Hard Avocado" (different word order)
```

### Problem 2: Word Order Dependency
```python
# Current (WRONG):
query_words = product_name.split()
for word in query_words:
    products = products.filter(name__icontains=word)
# This might be filtering too strictly
```

### Problem 3: AND Logic Without Word Order Flexibility
```python
# Current (WRONG):
from django.db.models import Q
query = Q()
for word in product_name.split():
    query &= Q(name__icontains=word)
Product.objects.filter(query)
# This requires ALL words but might be too strict about matching
```

## Required Fix

The backend should implement **word-based matching** that:
1. Splits the search query into individual words
2. Matches products where ALL words appear in the product name (in any order)
3. Is case-insensitive
4. Handles extra words in the query (like "3" which is a quantity)

### Recommended Implementation

```python
from django.db.models import Q
from django.db.models.functions import Lower

def get_product_suggestions(product_name):
    """
    Get product suggestions matching all words in the search query.
    Words can appear in any order in the product name.
    """
    # Remove common quantity/unit words that aren't part of product names
    quantity_words = {'3', '2', '1', '4', '5', '6', '7', '8', '9', '10',
                     'kg', 'g', 'ml', 'l', 'box', 'bag', 'bunch', 'head', 
                     'each', 'packet', 'punnet', 'x', '×', '*'}
    
    # Split into words and filter out quantity/unit words
    query_words = [
        word.lower().strip() 
        for word in product_name.split() 
        if word.lower().strip() not in quantity_words and len(word.strip()) > 1
    ]
    
    if not query_words:
        return Product.objects.none()
    
    # Build query: ALL words must be in product name (in any order)
    query = Q()
    for word in query_words:
        query &= Q(name__icontains=word)
    
    # Get matching products
    products = Product.objects.filter(query).distinct()
    
    # Calculate confidence scores based on:
    # 1. Exact phrase match (highest)
    # 2. All words match (high)
    # 3. Most words match (medium)
    
    results = []
    product_name_lower = product_name.lower()
    
    for product in products:
        product_name_lower_match = product.name.lower()
        
        # Calculate confidence
        if product_name_lower in product_name_lower_match or product_name_lower_match in product_name_lower:
            confidence = 1.0  # Exact or substring match
        else:
            # Count matching words
            matched_words = sum(1 for word in query_words if word in product_name_lower_match)
            confidence = matched_words / len(query_words) if query_words else 0.0
        
        results.append({
            'product': product,
            'confidence_score': confidence,
            # ... other fields
        })
    
    # Sort by confidence (highest first)
    results.sort(key=lambda x: x['confidence_score'], reverse=True)
    
    return results
```

### Alternative: Using Django's Full-Text Search (PostgreSQL)

If using PostgreSQL, consider using full-text search:

```python
from django.contrib.postgres.search import SearchVector, SearchQuery, SearchRank

def get_product_suggestions(product_name):
    # Remove quantity/unit words
    query_words = [w for w in product_name.split() 
                   if w.lower() not in quantity_words and len(w) > 1]
    search_query = ' '.join(query_words)
    
    # Use full-text search
    vector = SearchVector('name', weight='A')
    query = SearchQuery(search_query, search_type='websearch')
    
    products = Product.objects.annotate(
        search=vector,
        rank=SearchRank(vector, query)
    ).filter(search=query).order_by('-rank')
    
    return products
```

## Testing

Test cases that should work after the fix:

1. **"3 avocado hard"** → Should match "Avocado Hard" or "Hard Avocado"
2. **"avocado hard"** → Should match "Avocado Hard" or "Hard Avocado"  
3. **"hard avocado"** → Should match "Avocado Hard" or "Hard Avocado"
4. **"2kg tomatoes red"** → Should match "Red Tomatoes" or "Tomatoes Red"
5. **"5 soft bananas"** → Should match "Soft Bananas" or "Bananas Soft"

## Current Workaround

The Flutter app currently has a client-side workaround that removes descriptors if no results are found, but this is not ideal. The proper fix should be in the backend to handle word-order-independent matching.

## Location in Backend

The fix needs to be applied in the Django view/API endpoint that handles:
- Route: `/whatsapp/products/get-suggestions/`
- Likely file: `whatsapp/views.py` or `whatsapp/api/views.py`
- Method: `get_product_suggestions` or similar

## Priority

**HIGH** - This affects user experience when confirming order items. Users expect to find products even when descriptors are in different order or when quantities are included in the search.

