"""
Django Views for WhatsApp Product Suggestions
Fix for word-order-independent product search
"""

from django.db.models import Q
from django.http import JsonResponse
from rest_framework.decorators import api_view
from rest_framework import status
from products.models import Product  # Adjust import based on your app structure


@api_view(['POST'])
def get_product_suggestions(request):
    """
    Get product suggestions matching all words in the search query.
    Words can appear in any order in the product name.
    
    Request body: {'product_name': '3 avocado hard'}
    Response: {
        'status': 'success',
        'suggestions': [
            {
                'product': {...},
                'confidence_score': 1.0,
                'product_name': 'Avocado Hard',
                ...
            }
        ]
    }
    """
    product_name = request.data.get('product_name', '').strip()
    
    if not product_name:
        return JsonResponse({
            'status': 'error',
            'message': 'product_name is required'
        }, status=status.HTTP_400_BAD_REQUEST)
    
    # Remove common quantity/unit words that aren't part of product names
    quantity_words = {
        '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10',
        '11', '12', '13', '14', '15', '16', '17', '18', '19', '20',
        'kg', 'g', 'ml', 'l', 'box', 'bag', 'bunch', 'head', 
        'each', 'packet', 'punnet', 'x', '×', '*', 'pcs', 'pieces'
    }
    
    # Split into words and filter out quantity/unit words
    query_words = [
        word.lower().strip() 
        for word in product_name.split() 
        if word.lower().strip() not in quantity_words and len(word.strip()) > 1
    ]
    
    if not query_words:
        # If only quantity words, try searching with the original query
        query_words = [word.lower().strip() for word in product_name.split() if len(word.strip()) > 0]
    
    if not query_words:
        return JsonResponse({
            'status': 'success',
            'suggestions': []
        })
    
    # Build query: ALL words must be in product name (in any order)
    query = Q()
    for word in query_words:
        query &= Q(name__icontains=word)
    
    # Get matching products
    products = Product.objects.filter(query).distinct()
    
    # Calculate confidence scores and build results
    results = []
    product_name_lower = product_name.lower()
    
    for product in products:
        product_name_lower_match = product.name.lower()
        
        # Calculate confidence
        # 1. Exact or substring match (highest confidence)
        if product_name_lower in product_name_lower_match or product_name_lower_match in product_name_lower:
            confidence = 1.0
        else:
            # 2. Count matching words (word-order independent)
            matched_words = sum(1 for word in query_words if word in product_name_lower_match)
            confidence = matched_words / len(query_words) if query_words else 0.0
            
            # Boost confidence if product name starts with one of the query words
            first_query_word = query_words[0] if query_words else ''
            if product_name_lower_match.startswith(first_query_word):
                confidence = min(1.0, confidence + 0.1)
        
        # Get stock information
        stock_data = {}
        if hasattr(product, 'stock'):
            stock = product.stock
            stock_data = {
                'available_quantity': getattr(stock, 'available_quantity', 0),
                'available_quantity_count': getattr(stock, 'available_quantity_count', 0),
                'available_quantity_kg': getattr(stock, 'available_quantity_kg', 0.0),
                'in_stock': getattr(stock, 'available_quantity', 0) > 0,
            }
        elif hasattr(product, 'current_inventory'):
            stock_data = {
                'available_quantity': product.current_inventory or 0,
                'available_quantity_count': product.current_inventory or 0,
                'available_quantity_kg': product.current_inventory or 0.0,
                'in_stock': (product.current_inventory or 0) > 0,
            }
        else:
            stock_data = {
                'available_quantity': 0,
                'available_quantity_count': 0,
                'available_quantity_kg': 0.0,
                'in_stock': False,
            }
        
        # Build suggestion object
        suggestion = {
            'product': {
                'id': product.id,
                'name': product.name,
                'unit': getattr(product, 'unit', 'each'),
                'price': float(getattr(product, 'price', 0.0)),
                'department': getattr(product, 'department', ''),
                'sku': getattr(product, 'sku', ''),
            },
            'product_name': product.name,
            'confidence_score': confidence,
            'stock': stock_data,
            'in_stock': stock_data.get('in_stock', False),
            'unlimited_stock': getattr(product, 'unlimited_stock', False),
        }
        
        results.append(suggestion)
    
    # Sort by confidence (highest first), then by stock availability
    results.sort(key=lambda x: (
        -x['confidence_score'],  # Negative for descending
        -x['in_stock']  # In-stock items first
    ))
    
    return JsonResponse({
        'status': 'success',
        'suggestions': results
    })

