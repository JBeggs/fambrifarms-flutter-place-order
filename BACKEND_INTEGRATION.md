# Backend Integration Plan: place-order-final ↔ Django Backend

## Overview
This document outlines the integration strategy to connect the place-order-final Flutter/Python system with the existing Django backend, creating a unified order processing workflow.

## Current Architecture Analysis

### place-order-final (Current)
- **Flutter App**: Desktop UI for message display and editing
- **Python Flask Server**: WhatsApp scraping (port 5001)
- **WhatsApp Selenium**: Message extraction from WhatsApp Web
- **Data Flow**: WhatsApp → Python scraper → Flask API → Flutter UI

### Django Backend (Existing)
- **Django REST API**: Complete order management system
- **Models**: Order, OrderItem, Product, Customer, Inventory
- **Business Logic**: Monday/Thursday ordering, stock validation
- **Database**: SQLite (dev) / MySQL (prod)

## Integration Strategy

### Phase 1: API Endpoint Creation in Django Backend

#### 1.1 Create WhatsApp Message Processing App
```python
# backend/whatsapp/models.py
class WhatsAppMessage(models.Model):
    message_id = models.CharField(max_length=100, unique=True)
    chat_name = models.CharField(max_length=200)
    sender_name = models.CharField(max_length=200)
    sender_phone = models.CharField(max_length=20, blank=True)
    content = models.TextField()
    cleaned_content = models.TextField(blank=True)
    timestamp = models.DateTimeField()
    scraped_at = models.DateTimeField(auto_now_add=True)
    
    # Message classification
    MESSAGE_TYPES = [
        ('order', 'Customer Order'),
        ('stock', 'Stock Update'),
        ('instruction', 'Instruction/Note'),
        ('other', 'Other'),
    ]
    message_type = models.CharField(max_length=20, choices=MESSAGE_TYPES, default='other')
    
    # Processing status
    processed = models.BooleanField(default=False)
    order = models.ForeignKey('orders.Order', null=True, blank=True, on_delete=models.SET_NULL)
    
    # Parsed data
    parsed_items = models.JSONField(default=list)
    instructions = models.TextField(blank=True)
    confidence_score = models.FloatField(default=0.0)
    
    # Manual editing
    edited = models.BooleanField(default=False)
    original_content = models.TextField(blank=True)
    
    class Meta:
        ordering = ['-timestamp']

class StockUpdate(models.Model):
    """Stock controller messages from SHALLOME"""
    message = models.OneToOneField(WhatsAppMessage, on_delete=models.CASCADE)
    stock_date = models.DateField()
    order_day = models.CharField(max_length=10)  # Monday/Thursday
    items = models.JSONField(default=dict)  # {product_name: {quantity: X, unit: 'kg'}}
    processed = models.BooleanField(default=False)
    
    class Meta:
        ordering = ['-stock_date']
```

#### 1.2 WhatsApp API Endpoints
```python
# backend/whatsapp/views.py
from rest_framework import generics, status
from rest_framework.decorators import api_view
from rest_framework.response import Response
from .models import WhatsAppMessage, StockUpdate
from .serializers import WhatsAppMessageSerializer

@api_view(['GET'])
def health_check(request):
    """Health check endpoint"""
    return Response({'status': 'healthy', 'service': 'django-backend'})

@api_view(['POST'])
def receive_messages(request):
    """Receive scraped messages from Python scraper"""
    messages_data = request.data.get('messages', [])
    created_messages = []
    
    for msg_data in messages_data:
        message, created = WhatsAppMessage.objects.get_or_create(
            message_id=msg_data['id'],
            defaults={
                'chat_name': msg_data['chat'],
                'sender_name': msg_data['sender'],
                'content': msg_data['content'],
                'cleaned_content': msg_data.get('cleanedContent', ''),
                'timestamp': msg_data['timestamp'],
                'message_type': classify_message_type(msg_data),
                'parsed_items': msg_data.get('items', []),
                'instructions': msg_data.get('instructions', ''),
            }
        )
        if created:
            created_messages.append(message)
    
    # Process stock updates
    process_stock_updates(created_messages)
    
    return Response({
        'status': 'success',
        'messages_received': len(messages_data),
        'new_messages': len(created_messages)
    })

@api_view(['GET'])
def get_messages(request):
    """Get messages for Flutter app"""
    messages = WhatsAppMessage.objects.filter(processed=False).order_by('-timestamp')
    serializer = WhatsAppMessageSerializer(messages, many=True)
    return Response(serializer.data)

@api_view(['POST'])
def edit_message(request):
    """Edit message content"""
    message_id = request.data.get('message_id')
    edited_content = request.data.get('edited_content')
    
    try:
        message = WhatsAppMessage.objects.get(message_id=message_id)
        if not message.edited:
            message.original_content = message.content
        message.content = edited_content
        message.edited = True
        message.save()
        
        serializer = WhatsAppMessageSerializer(message)
        return Response({'message': serializer.data})
    except WhatsAppMessage.DoesNotExist:
        return Response({'error': 'Message not found'}, status=404)

@api_view(['POST'])
def process_messages_to_orders(request):
    """Convert selected messages to orders"""
    message_ids = request.data.get('message_ids', [])
    
    try:
        messages = WhatsAppMessage.objects.filter(message_id__in=message_ids)
        orders_created = []
        
        for message in messages:
            if message.message_type == 'order':
                order = create_order_from_message(message)
                if order:
                    orders_created.append(order)
                    message.processed = True
                    message.order = order
                    message.save()
        
        return Response({
            'status': 'success',
            'orders_created': len(orders_created),
            'order_numbers': [order.order_number for order in orders_created]
        })
    except Exception as e:
        return Response({'error': str(e)}, status=400)
```

#### 1.3 Order Creation Logic
```python
# backend/whatsapp/services.py
from orders.models import Order, OrderItem
from products.models import Product
from accounts.models import User
from django.contrib.auth import get_user_model
from datetime import datetime, date
import re

def classify_message_type(msg_data):
    """Classify message type based on content and sender"""
    content = msg_data['content'].upper()
    sender = msg_data['sender']
    
    # Stock controller messages
    if '+27 61 674 9368' in sender or 'SHALLOME' in sender:
        if 'STOKE AS AT' in content or 'STOCK AS AT' in content:
            return 'stock'
    
    # Order day demarcation
    if 'ORDERS STARTS HERE' in content or '👇👇👇' in content:
        return 'instruction'
    
    # Company orders (has items)
    if has_order_items(content):
        return 'order'
    
    return 'other'

def has_order_items(content):
    """Check if message contains order items"""
    # Look for quantity patterns: 5kg, 2×5kg, 3 boxes, etc.
    quantity_patterns = [
        r'\d+\s*(?:kg|kilos?|kilogram)',
        r'\d+\s*(?:×|x)\s*\d+\s*kg',
        r'\d+\s*(?:box|boxes|pun|punnet|punnets)',
        r'\d+\s*(?:bag|bags|packet|packets)',
        r'\d+\s*(?:bunch|bunches|head|heads)',
    ]
    
    for pattern in quantity_patterns:
        if re.search(pattern, content, re.IGNORECASE):
            return True
    return False

def create_order_from_message(message):
    """Create Django Order from WhatsApp message"""
    try:
        # Extract company name (first line usually)
        lines = message.content.strip().split('\n')
        company_name = lines[0].strip()
        
        # Get or create customer
        customer = get_or_create_customer(company_name, message.sender_name)
        
        # Determine order date (must be Monday or Thursday)
        order_date = get_valid_order_date(message.timestamp.date())
        
        # Create order
        order = Order.objects.create(
            restaurant=customer,
            order_date=order_date,
            status='received',
            whatsapp_message_id=message.message_id,
            original_message=message.content,
            parsed_by_ai=True
        )
        
        # Parse and create order items
        items_created = create_order_items(order, message)
        
        if items_created:
            return order
        else:
            order.delete()  # No valid items found
            return None
            
    except Exception as e:
        print(f"Error creating order from message {message.message_id}: {e}")
        return None

def get_or_create_customer(company_name, sender_name):
    """Get or create customer from company name"""
    User = get_user_model()
    
    # Try to find existing customer
    email = f"{company_name.lower().replace(' ', '')}@restaurant.com"
    
    customer, created = User.objects.get_or_create(
        email=email,
        defaults={
            'username': email,
            'first_name': company_name,
            'user_type': 'restaurant',
            'is_active': True
        }
    )
    
    return customer

def get_valid_order_date(message_date):
    """Get valid order date (Monday or Thursday)"""
    # If message is from Monday or Thursday, use that date
    if message_date.weekday() in [0, 3]:  # Monday=0, Thursday=3
        return message_date
    
    # Otherwise, find next valid order date
    days_ahead = 0
    while True:
        check_date = message_date + timedelta(days=days_ahead)
        if check_date.weekday() in [0, 3]:
            return check_date
        days_ahead += 1
        if days_ahead > 7:  # Safety check
            break
    
    return message_date  # Fallback

def create_order_items(order, message):
    """Parse message content and create order items"""
    content = message.content
    items_created = 0
    
    # Parse items from message
    parsed_items = parse_order_items(content)
    
    for item_data in parsed_items:
        try:
            # Find or create product
            product = get_or_create_product(item_data['product_name'])
            
            # Create order item
            OrderItem.objects.create(
                order=order,
                product=product,
                quantity=item_data['quantity'],
                unit=item_data['unit'],
                price=product.price or 0,
                original_text=item_data['original_text'],
                confidence_score=item_data.get('confidence', 0.8)
            )
            items_created += 1
            
        except Exception as e:
            print(f"Error creating order item: {e}")
            continue
    
    return items_created

def parse_order_items(content):
    """Parse order items from message content"""
    items = []
    lines = content.split('\n')
    
    for line in lines[1:]:  # Skip first line (company name)
        line = line.strip()
        if not line:
            continue
            
        # Parse quantity and product
        item = parse_single_item(line)
        if item:
            items.append(item)
    
    return items

def parse_single_item(line):
    """Parse single order item line"""
    # Patterns for different formats
    patterns = [
        r'(\d+)\s*(?:×|x)\s*(\d+)\s*(kg|kilos?)\s*(.+)',  # 2×5kg Tomatoes
        r'(\d+)\s*(kg|kilos?|box|boxes|pun|punnet|punnets|bag|bags)\s*(.+)',  # 5kg Tomatoes
        r'(.+?)\s*(?:×|x)\s*(\d+)\s*(.+)',  # Tomatoes x3
        r'(\d+)\s*(.+)',  # 5 Tomatoes
    ]
    
    for pattern in patterns:
        match = re.search(pattern, line, re.IGNORECASE)
        if match:
            groups = match.groups()
            
            if len(groups) == 4:  # 2×5kg format
                quantity = int(groups[0]) * int(groups[1])
                unit = groups[2]
                product_name = groups[3].strip()
            elif len(groups) == 3 and groups[1] in ['kg', 'box', 'pun', 'bag']:  # 5kg format
                quantity = int(groups[0])
                unit = groups[1]
                product_name = groups[2].strip()
            else:
                continue
            
            return {
                'quantity': quantity,
                'unit': unit,
                'product_name': clean_product_name(product_name),
                'original_text': line,
                'confidence': 0.8
            }
    
    return None

def clean_product_name(name):
    """Clean and normalize product name"""
    # Remove common prefixes/suffixes
    name = re.sub(r'^(fresh|organic|local)\s+', '', name, flags=re.IGNORECASE)
    name = re.sub(r'\s+(fresh|organic|local)$', '', name, flags=re.IGNORECASE)
    
    # Normalize common variations
    replacements = {
        'tomatos': 'tomatoes',
        'tomatoe': 'tomatoes',
        'onion': 'onions',
        'potato': 'potatoes',
        'lettuce': 'lettuce',
    }
    
    name_lower = name.lower()
    for old, new in replacements.items():
        if old in name_lower:
            name = name_lower.replace(old, new).title()
            break
    
    return name.strip()

def get_or_create_product(product_name):
    """Get or create product"""
    try:
        return Product.objects.get(name__iexact=product_name)
    except Product.DoesNotExist:
        # Create new product
        return Product.objects.create(
            name=product_name.title(),
            price=0,  # Will be updated manually
            department_id=1,  # Default department
            is_active=True
        )

def process_stock_updates(messages):
    """Process stock update messages from SHALLOME"""
    for message in messages:
        if message.message_type == 'stock' and 'STOKE AS AT' in message.content:
            try:
                stock_update = parse_stock_message(message)
                if stock_update:
                    StockUpdate.objects.create(
                        message=message,
                        stock_date=stock_update['date'],
                        order_day=stock_update['order_day'],
                        items=stock_update['items']
                    )
            except Exception as e:
                print(f"Error processing stock update: {e}")

def parse_stock_message(message):
    """Parse stock update message from SHALLOME"""
    content = message.content
    lines = content.split('\n')
    
    # Find date line
    date_line = None
    for line in lines:
        if 'STOKE AS AT' in line or 'STOCK AS AT' in line:
            date_line = line
            break
    
    if not date_line:
        return None
    
    # Extract date
    date_match = re.search(r'(\d{1,2})\s+(\w+)\s+(\d{4})', date_line)
    if not date_match:
        return None
    
    day, month_name, year = date_match.groups()
    
    # Parse items
    items = {}
    for line in lines:
        line = line.strip()
        if re.match(r'^\d+\.', line):  # Numbered items
            item = parse_stock_item(line)
            if item:
                items[item['name']] = {
                    'quantity': item['quantity'],
                    'unit': item['unit']
                }
    
    return {
        'date': f"{day} {month_name} {year}",
        'order_day': determine_order_day(message.timestamp.date()),
        'items': items
    }

def parse_stock_item(line):
    """Parse single stock item line"""
    # Remove number prefix: "1.Spinach 3kg" -> "Spinach 3kg"
    line = re.sub(r'^\d+\.', '', line).strip()
    
    # Parse quantity and unit
    match = re.search(r'(.+?)\s+(\d+(?:\.\d+)?)\s*(kg|pun|box|bag|bunch|head|g)s?$', line, re.IGNORECASE)
    if match:
        name = match.group(1).strip()
        quantity = float(match.group(2))
        unit = match.group(3).lower()
        
        return {
            'name': clean_product_name(name),
            'quantity': quantity,
            'unit': unit
        }
    
    return None

def determine_order_day(date):
    """Determine which order day this stock applies to"""
    weekday = date.weekday()
    if weekday <= 0:  # Monday or before
        return 'Monday'
    elif weekday <= 3:  # Tuesday-Thursday
        return 'Thursday'
    else:  # Friday or after
        return 'Monday'  # Next week
```

### Phase 2: Modify place-order-final Flutter App

#### 2.1 Update API Service
```dart
// lib/services/api_service.dart
class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000/api';  // Django backend
  static const String whatsappUrl = 'http://127.0.0.1:5001/api';  // Python scraper
  late final Dio _djangoDio;
  late final Dio _whatsappDio;

  ApiService() {
    _djangoDio = Dio(BaseOptions(baseUrl: baseUrl));
    _whatsappDio = Dio(BaseOptions(baseUrl: whatsappUrl));
  }

  // WhatsApp scraping (Python service)
  Future<Map<String, dynamic>> startWhatsApp() async {
    final response = await _whatsappDio.post('/whatsapp/start');
    return response.data;
  }

  Future<List<WhatsAppMessage>> scrapeMessages() async {
    final response = await _whatsappDio.get('/messages');
    
    // Send scraped messages to Django backend
    await _djangoDio.post('/whatsapp/receive-messages', data: {
      'messages': response.data
    });
    
    // Get processed messages from Django
    final djangoResponse = await _djangoDio.get('/whatsapp/messages');
    return djangoResponse.data.map((json) => WhatsAppMessage.fromJson(json)).toList();
  }

  // Order processing (Django backend)
  Future<Map<String, dynamic>> processMessagesToOrders(List<String> messageIds) async {
    final response = await _djangoDio.post('/whatsapp/process-messages', data: {
      'message_ids': messageIds,
    });
    return response.data;
  }

  // Get created orders
  Future<List<Order>> getOrders() async {
    final response = await _djangoDio.get('/orders/orders/');
    return response.data.map((json) => Order.fromJson(json)).toList();
  }

  // Get products for validation
  Future<List<Product>> getProducts() async {
    final response = await _djangoDio.get('/products/products/');
    return response.data.map((json) => Product.fromJson(json)).toList();
  }

  // Get inventory status
  Future<Map<String, dynamic>> getInventoryStatus() async {
    final response = await _djangoDio.get('/inventory/finished/');
    return response.data;
  }
}
```

#### 2.2 Create Order Models
```dart
// lib/models/order.dart
class Order {
  final String id;
  final String orderNumber;
  final String restaurantName;
  final String orderDate;
  final String deliveryDate;
  final String status;
  final List<OrderItem> items;
  final String originalMessage;
  final double totalAmount;

  Order({
    required this.id,
    required this.orderNumber,
    required this.restaurantName,
    required this.orderDate,
    required this.deliveryDate,
    required this.status,
    required this.items,
    required this.originalMessage,
    required this.totalAmount,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'].toString(),
      orderNumber: json['order_number'],
      restaurantName: json['restaurant']['first_name'] ?? 'Unknown',
      orderDate: json['order_date'],
      deliveryDate: json['delivery_date'],
      status: json['status'],
      items: (json['items'] as List).map((item) => OrderItem.fromJson(item)).toList(),
      originalMessage: json['original_message'] ?? '',
      totalAmount: double.parse(json['total_amount'] ?? '0'),
    );
  }
}

class OrderItem {
  final String id;
  final String productName;
  final double quantity;
  final String unit;
  final double price;
  final double totalPrice;
  final String originalText;

  OrderItem({
    required this.id,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.price,
    required this.totalPrice,
    required this.originalText,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'].toString(),
      productName: json['product']['name'],
      quantity: double.parse(json['quantity']),
      unit: json['unit'] ?? '',
      price: double.parse(json['price']),
      totalPrice: double.parse(json['total_price']),
      originalText: json['original_text'] ?? '',
    );
  }
}
```

### Phase 3: Integration Workflow

#### 3.1 Complete Processing Flow
```
1. Python Scraper (place-order-final/python/whatsapp_server.py)
   ↓ Scrapes WhatsApp messages
   
2. Flutter App calls scrapeMessages()
   ↓ Gets messages from Python, sends to Django
   
3. Django Backend (/api/whatsapp/receive-messages)
   ↓ Processes and classifies messages
   
4. Flutter App displays processed messages
   ↓ User selects messages to convert to orders
   
5. Django Backend (/api/whatsapp/process-messages)
   ↓ Creates Order and OrderItem objects
   
6. Flutter App shows created orders
   ↓ Integration with existing order management
```

#### 3.2 Stock Validation Integration
```python
# backend/whatsapp/services.py (additional)
def validate_order_against_stock(order):
    """Validate order items against available stock"""
    try:
        # Get latest stock update for this order day
        order_day = 'Monday' if order.order_date.weekday() == 0 else 'Thursday'
        stock_update = StockUpdate.objects.filter(
            order_day=order_day,
            processed=False
        ).order_by('-stock_date').first()
        
        if not stock_update:
            return {'status': 'no_stock_data', 'items': []}
        
        validated_items = []
        for item in order.items.all():
            product_name = item.product.name.lower()
            available_stock = stock_update.items.get(product_name, {})
            
            if available_stock:
                available_qty = available_stock['quantity']
                if item.quantity <= available_qty:
                    status = 'available'
                    allocated = item.quantity
                else:
                    status = 'partial'
                    allocated = available_qty
            else:
                status = 'out_of_stock'
                allocated = 0
            
            validated_items.append({
                'item_id': item.id,
                'product': item.product.name,
                'requested': item.quantity,
                'allocated': allocated,
                'status': status
            })
        
        return {'status': 'validated', 'items': validated_items}
        
    except Exception as e:
        return {'status': 'error', 'message': str(e)}
```

### Phase 4: URL Configuration

#### 4.1 Django URLs
```python
# backend/whatsapp/urls.py
from django.urls import path
from . import views

urlpatterns = [
    path('health/', views.health_check, name='health'),
    path('receive-messages/', views.receive_messages, name='receive-messages'),
    path('messages/', views.get_messages, name='get-messages'),
    path('messages/edit/', views.edit_message, name='edit-message'),
    path('process-messages/', views.process_messages_to_orders, name='process-messages'),
    path('stock-updates/', views.get_stock_updates, name='stock-updates'),
    path('validate-order/<int:order_id>/', views.validate_order_stock, name='validate-order'),
]

# backend/familyfarms_api/urls.py (add)
path('api/whatsapp/', include('whatsapp.urls')),
```

## Benefits of This Integration

### 1. Unified Data Management
- All orders stored in Django database
- Consistent customer management
- Integrated inventory tracking
- Complete audit trail

### 2. Business Logic Enforcement
- Monday/Thursday order validation
- Automatic delivery date calculation
- Stock validation against SHALLOME's updates
- Order status tracking

### 3. Scalability
- Django handles complex business logic
- Flutter provides rich UI experience
- Python scraper remains focused on WhatsApp
- Clear separation of concerns

### 4. Existing System Integration
- Leverages existing Django models
- Uses established API patterns
- Maintains current business workflows
- Preserves data integrity

## Implementation Timeline

1. **Week 1**: Create WhatsApp Django app and models
2. **Week 2**: Implement API endpoints and message processing
3. **Week 3**: Modify Flutter app to use Django backend
4. **Week 4**: Test integration and stock validation
5. **Week 5**: Deploy and optimize performance

This integration creates a robust, scalable system that combines the best of both worlds: the rich UI of Flutter, the powerful scraping of Python/Selenium, and the solid business logic foundation of Django.
