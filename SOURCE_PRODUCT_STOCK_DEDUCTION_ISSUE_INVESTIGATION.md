# Source Product Stock Deduction Issue Investigation

## Problem
When using stock from another product (source product) in the place order confirm order screen, stock is not being deducted correctly. For example, when using stock from "lemon" for "lemons", the stock stays at 26 kg instead of being reduced.

## Root Cause

**Location**: `backend/whatsapp/views.py:2684-2753`

**Issue**: Stock reservation happens BEFORE source product information is extracted, so it uses the wrong product and quantity.

### Current Flow (INCORRECT):

1. **Line 2684-2692**: Stock is reserved using `reserve_stock_for_customer()` with:
   - `product=product` (ordered product, e.g., "lemons")
   - `quantity=quantity` (ordered quantity)
   - **Problem**: Source product info not available yet

2. **Line 2742-2753**: Source product information is extracted AFTER stock reservation:
   - `source_product` and `source_quantity` are extracted from `item_data`
   - Stored in OrderItem model
   - **Problem**: Too late - stock already reserved from wrong product

### Expected Flow:

1. Extract source product information FIRST (if present)
2. Reserve stock from source product (if specified), otherwise from ordered product
3. Use source quantity (if specified), otherwise use ordered quantity
4. Create OrderItem with source product info

## Code Analysis

### Current Code (Lines 2684-2753):

```python
# Handle stock actions
if stock_action == 'reserve':
    # Reserve stock for this item
    stock_result = reserve_stock_for_customer(
        product=product,  # ❌ Wrong - uses ordered product
        quantity=quantity,  # ❌ Wrong - uses ordered quantity
        customer=customer,
        fulfillment_method='user_confirmed'
    )

# ... later ...

# Handle source product if specified
source_product = None
source_quantity = None
if 'source_product_id' in item_data and item_data['source_product_id'] is not None:
    source_product = products_dict.get(item_data['source_product_id'])
    if source_product:
        source_quantity = Decimal(str(item_data.get('source_quantity', 0)))
```

**Problem**: Stock reservation uses `product` and `quantity` instead of `source_product` and `source_quantity` when source product is specified.

## Solution

### Fix Required:

1. **Extract source product information BEFORE stock reservation**
2. **Use source product/quantity for stock reservation if specified**
3. **Otherwise use ordered product/quantity**

### Implementation:

```python
# Extract source product information FIRST (before stock reservation)
source_product = None
source_quantity = None
if 'source_product_id' in item_data and item_data['source_product_id'] is not None:
    source_product = products_dict.get(item_data['source_product_id'])
    if source_product:
        source_quantity = Decimal(str(item_data.get('source_quantity', 0)))

# Determine which product/quantity to use for stock reservation
stock_product = source_product if source_product else product
stock_quantity = source_quantity if source_quantity else quantity

# Handle stock actions
if stock_action == 'reserve':
    # Reserve stock from the correct product (source or ordered)
    stock_result = reserve_stock_for_customer(
        product=stock_product,  # ✅ Correct - uses source product if specified
        quantity=stock_quantity,  # ✅ Correct - uses source quantity if specified
        customer=customer,
        fulfillment_method='user_confirmed'
    )
```

## Impact

**Before Fix**:
- Stock reserved from ordered product (e.g., "lemons")
- Source product stock (e.g., "lemon") not affected
- Stock levels incorrect

**After Fix**:
- Stock reserved from source product when specified (e.g., "lemon")
- Source product stock correctly reduced
- Stock levels accurate

## Testing

Test scenarios:
1. Order "lemons" using stock from "lemon" → "lemon" stock should decrease
2. Order product without source product → ordered product stock should decrease
3. Order with source quantity different from ordered quantity → source quantity should be used

## Implementation Status

✅ **FIXED**

### Changes Made:

1. **Moved source product extraction BEFORE stock reservation** (lines 2681-2695)
   - Extract `source_product` and `source_quantity` before handling stock actions
   - Determine `stock_product` and `stock_quantity` to use for stock operations

2. **Updated stock reservation to use correct product/quantity** (lines 2700-2708)
   - Changed `product=product` to `product=stock_product`
   - Changed `quantity=quantity` to `quantity=stock_quantity`
   - Stock now correctly deducted from source product when specified

3. **Enhanced stock movement notes** (lines 2713-2720)
   - Include source product information in notes when applicable
   - Format: "Product Name (stock from Source Product: quantity unit)"

### Result:

- ✅ Stock correctly deducted from source product when specified
- ✅ Stock correctly deducted from ordered product when no source product
- ✅ Stock movement notes include source product information
- ✅ Stock levels now accurate

