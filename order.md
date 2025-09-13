# Order Processing Logic - Detailed Concept

## Overview
This document outlines the comprehensive logic for processing WhatsApp orders based on the message patterns observed in the ORDERS Restaurants group, with special handling for stock controller messages and order day demarcations.

## Key Stakeholders & Roles

### Stock Controller
- **Contact**: SHALLOME🤝 +27 61 674 9368
- **Role**: Provides stock availability updates
- **Message Pattern**: "STOKE AS AT [DATE]" followed by numbered inventory list
- **Timing**: Posted on order days or before to indicate available stock in storeroom

### Order Days
- **Primary Order Days**: Monday and Thursday
- **Order Demarcation**: Messages like "Thursday orders starts here. 👇👇👇" and "Tuesday orders starts here"
- **Note**: Only these days accept new orders

## Message Classification System

### 1. Stock Messages
**Identifier**: Messages from +27 61 674 9368 (SHALLOME)
**Pattern**: 
```
STOKE AS AT [DATE]
1. Product Name Quantity
2. Product Name Quantity
...
43. Product Name Quantity
```

**Processing Logic**:
- Extract date from "STOKE AS AT" line
- Parse numbered inventory items (1-43+)
- Store as available stock for the corresponding order day
- Format: `{product_name: {quantity: X, unit: kg/pun/box/etc}}`

### 2. Order Day Demarcation Messages
**Identifiers**:
- "Thursday orders starts here. 👇👇👇"
- "Tuesday orders starts here"
- "[DAY] orders starts here"

**Processing Logic**:
- Mark the start of a new order collection period
- Reset order collection state
- Set current_order_day = extracted day
- All subsequent orders belong to this day until next demarcation

### 3. Company Orders
**Pattern**: Company name followed by order items
**Examples**:
- "Mugg and Bean" → followed by order items
- "Debonair" → followed by order items
- "Order valley" → followed by order items

## Core Processing Algorithm

### Phase 1: Message Preprocessing
```python
def preprocess_messages(messages):
    processed_messages = []
    current_order_day = None
    current_stock = {}
    
    for message in messages:
        # Classify message type
        msg_type = classify_message(message)
        
        if msg_type == "stock_update":
            current_stock = parse_stock_message(message)
            
        elif msg_type == "order_day_demarcation":
            current_order_day = extract_order_day(message)
            
        elif msg_type == "company_order":
            processed_messages.append({
                'message': message,
                'order_day': current_order_day,
                'available_stock': current_stock.copy(),
                'timestamp': message.timestamp
            })
    
    return processed_messages
```

### Phase 2: Order Extraction & Validation

```python
def process_orders(processed_messages):
    orders = []
    
    for msg_data in processed_messages:
        if msg_data['order_day'] in ['Monday', 'Thursday']:  # Valid order days
            order = extract_order_details(msg_data['message'])
            
            # Validate against available stock
            validated_order = validate_against_stock(
                order, 
                msg_data['available_stock']
            )
            
            orders.append({
                'company': order['company'],
                'items': validated_order['items'],
                'order_day': msg_data['order_day'],
                'stock_availability': validated_order['stock_status'],
                'timestamp': msg_data['timestamp'],
                'raw_message': msg_data['message']
            })
    
    return orders
```

### Phase 3: Stock Validation Logic

```python
def validate_against_stock(order, available_stock):
    validated_items = []
    
    for item in order['items']:
        product_name = normalize_product_name(item['product'])
        requested_qty = item['quantity']
        
        if product_name in available_stock:
            available_qty = available_stock[product_name]['quantity']
            
            if requested_qty <= available_qty:
                status = "AVAILABLE"
                allocated_qty = requested_qty
            else:
                status = "PARTIAL" 
                allocated_qty = available_qty
        else:
            status = "OUT_OF_STOCK"
            allocated_qty = 0
        
        validated_items.append({
            'product': item['product'],
            'requested_quantity': requested_qty,
            'allocated_quantity': allocated_qty,
            'unit': item['unit'],
            'status': status
        })
    
    return {'items': validated_items, 'stock_status': calculate_overall_status(validated_items)}
```

## Data Structures

### Order Object
```python
{
    'order_id': 'unique_identifier',
    'company': 'Company Name',
    'order_day': 'Monday|Thursday',
    'timestamp': datetime,
    'items': [
        {
            'product': 'Tomatoes',
            'requested_quantity': 5,
            'allocated_quantity': 5,
            'unit': 'kg',
            'status': 'AVAILABLE|PARTIAL|OUT_OF_STOCK'
        }
    ],
    'overall_status': 'COMPLETE|PARTIAL|FAILED',
    'stock_reference_date': datetime,
    'raw_message': 'original WhatsApp message',
    'processing_notes': []
}
```

### Stock Object
```python
{
    'stock_date': datetime,
    'items': {
        'tomatoes': {'quantity': 15, 'unit': 'kg'},
        'spinach': {'quantity': 3, 'unit': 'kg'},
        'cocktail_tomatoes': {'quantity': 25, 'unit': 'pun'},
        # ... more items
    },
    'last_updated': datetime,
    'controller': '+27 61 674 9368'
}
```

## Business Rules

### 1. Order Day Validation
- Only accept orders on Monday and Thursday
- Orders outside these days are flagged as "INVALID_DAY"
- Stock updates can occur on any day but apply to the next valid order day

### 2. Stock Allocation Priority
- First-come, first-served basis within each order day
- Process orders in chronological order within the same day
- Partial allocation when stock is insufficient

### 3. Product Name Normalization
- Handle variations: "Tomatoes" vs "tomato" vs "Tomato"
- Unit standardization: "kg" vs "kilos" vs "kilogram"
- Quantity parsing: "5kg" vs "5 kg" vs "5×kg"

### 4. Stock Deduction Logic
- Deduct allocated quantities from available stock
- Update remaining stock for subsequent orders
- Track stock movements for audit trail

## Error Handling & Edge Cases

### 1. Missing Stock Information
- If no stock message found for order day, flag as "STOCK_UNKNOWN"
- Allow order processing but mark for manual review

### 2. Ambiguous Company Names
- Maintain company alias mapping
- Flag unclear company references for manual resolution

### 3. Invalid Quantity Formats
- Parse various quantity formats: "2×5kg", "5 kg", "5kg"
- Default to manual review for unparseable quantities

### 4. Duplicate Orders
- Detect potential duplicate orders from same company on same day
- Flag for manual review rather than auto-merge

## Output Generation

### 1. Order Summary Report
- Group by order day and company
- Show requested vs allocated quantities
- Highlight stock shortages

### 2. Stock Depletion Report
- Show remaining stock after all allocations
- Identify items running low
- Suggest reorder quantities

### 3. Exception Report
- List all orders requiring manual review
- Categorize by exception type
- Provide resolution suggestions

## Implementation Phases

### Phase 1: Basic Order Extraction
- Implement message classification
- Extract company names and order items
- Basic quantity parsing

### Phase 2: Stock Integration
- Parse stock controller messages
- Implement stock validation logic
- Generate availability reports

### Phase 3: Advanced Features
- Product name normalization
- Duplicate detection
- Comprehensive reporting

### Phase 4: Optimization
- Performance improvements
- Advanced parsing algorithms
- Machine learning for better classification

## Testing Strategy

### 1. Unit Tests
- Test individual parsing functions
- Validate stock calculation logic
- Test edge cases and error conditions

### 2. Integration Tests
- Test full message processing pipeline
- Validate order day transitions
- Test stock deduction accuracy

### 3. Data Validation
- Compare processed results with manual review
- Validate against known good datasets
- Test with various message formats

This comprehensive approach ensures accurate order processing while maintaining flexibility for the dynamic nature of WhatsApp messaging patterns.
