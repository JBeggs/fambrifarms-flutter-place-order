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
            available_quantity_count = getattr(stock, 'available_quantity_count', 0)
            available_quantity_kg = getattr(stock, 'available_quantity_kg', 0.0)
            
            # Calculate available_quantity_kg for box/packaged products if missing
            # This is needed for products like "1 lemon box" where we need kg stock
            if available_quantity_kg == 0.0 and available_quantity_count > 0:
                product_unit = getattr(product, 'unit', '').lower()
                packaging_size = getattr(product, 'packaging_size', None)
                
                # Check if this is a packaged product (box, bag, packet, punnet, etc.)
                is_packaged = product_unit in ['box', 'bag', 'packet', 'punnet', 'bunch', 'head', 'each']
                
                if is_packaged and packaging_size:
                    # Parse packaging size (e.g., "5kg", "2kg", "500g", "100g")
                    import re
                    packaging_size_lower = str(packaging_size).lower().strip().replace(' ', '')
                    
                    # Try to match kg pattern (e.g., "5kg", "2.5kg")
                    kg_match = re.match(r'^(\d+(?:\.\d+)?)\s*kg$', packaging_size_lower)
                    if kg_match:
                        weight_per_unit = float(kg_match.group(1))
                        available_quantity_kg = available_quantity_count * weight_per_unit
                    else:
                        # Try to match gram pattern (e.g., "500g", "100g")
                        g_match = re.match(r'^(\d+(?:\.\d+)?)\s*g$', packaging_size_lower)
                        if g_match:
                            weight_per_unit_grams = float(g_match.group(1))
                            weight_per_unit_kg = weight_per_unit_grams / 1000.0
                            available_quantity_kg = available_quantity_count * weight_per_unit_kg
            
            stock_data = {
                'available_quantity': getattr(stock, 'available_quantity', 0),
                'available_quantity_count': available_quantity_count,
                'available_quantity_kg': available_quantity_kg,
                'in_stock': getattr(stock, 'available_quantity', 0) > 0,
            }
        elif hasattr(product, 'current_inventory'):
            current_inventory = product.current_inventory or 0
            product_unit = getattr(product, 'unit', '').lower()
            packaging_size = getattr(product, 'packaging_size', None)
            
            # Calculate kg for packaged products
            available_quantity_kg = 0.0
            if current_inventory > 0:
                is_packaged = product_unit in ['box', 'bag', 'packet', 'punnet', 'bunch', 'head', 'each']
                if is_packaged and packaging_size:
                    import re
                    packaging_size_lower = str(packaging_size).lower().strip().replace(' ', '')
                    kg_match = re.match(r'^(\d+(?:\.\d+)?)\s*kg$', packaging_size_lower)
                    if kg_match:
                        weight_per_unit = float(kg_match.group(1))
                        available_quantity_kg = current_inventory * weight_per_unit
                    else:
                        g_match = re.match(r'^(\d+(?:\.\d+)?)\s*g$', packaging_size_lower)
                        if g_match:
                            weight_per_unit_grams = float(g_match.group(1))
                            weight_per_unit_kg = weight_per_unit_grams / 1000.0
                            available_quantity_kg = current_inventory * weight_per_unit_kg
                elif product_unit == 'kg':
                    available_quantity_kg = float(current_inventory)
            
            stock_data = {
                'available_quantity': current_inventory,
                'available_quantity_count': current_inventory,
                'available_quantity_kg': available_quantity_kg,
                'in_stock': current_inventory > 0,
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
            'product_id': product.id,
            'product': {
                'id': product.id,
                'name': product.name,
                'unit': getattr(product, 'unit', 'each'),
                'price': float(getattr(product, 'price', 0.0)),
                'department': getattr(product, 'department', ''),
                'sku': getattr(product, 'sku', ''),
            },
            'product_name': product.name,
            'unit': getattr(product, 'unit', 'each'),
            'packaging_size': getattr(product, 'packaging_size', None),
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

