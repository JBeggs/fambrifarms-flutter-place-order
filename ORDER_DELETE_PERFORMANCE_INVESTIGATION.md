# Order Delete Performance Investigation

## Problem
Deleting orders in the Android app takes very long and reloading data is slow.

## Root Causes Identified

### 1. Backend Delete Endpoint (`perform_destroy`)
**Location**: `backend/orders/views.py:40-76`

**Issues**:
- Queries `StockMovement` with `.exists()` (1 query)
- Calls `release_stock_for_order()` which:
  - Iterates through `order.items.all()` - **N queries** if items not prefetched
  - For each item, calls `FinishedInventory.objects.get()` - **N queries**
  - Creates `StockMovement` records - **N INSERT queries**
- Total: **1 + N + N + N = 3N + 1 queries** for an order with N items

**Current Code**:
```python
existing_reservations = StockMovement.objects.filter(
    movement_type='finished_reserve',
    reference_number=order_number
).exists()  # Query 1

if existing_reservations:
    release_stock_for_order(order)  # N queries per item
```

### 2. OrderSerializer N+1 Query Problem
**Location**: `backend/orders/serializers.py:111-228`

**Issues**:
- `get_stock_action()` and `get_stock_result()` are called for **EVERY order item**
- Each method makes **2-3 database queries per item**
- For an order list with 20 orders × 5 items each = **200-300 queries**

**Problematic Methods**:
- `get_stock_action()`: 2 queries per item (by reference_number, then by timing)
- `get_stock_result()`: 2-3 queries per item (by reference_number, by timing, then FinishedInventory lookup)

### 3. Frontend Refresh After Delete
**Location**: `place-order-final/lib/providers/orders_provider.dart:245-263`

**Issues**:
- After deletion, `refreshOrders()` is called which reloads **ALL orders**
- This triggers the serializer N+1 problem for all orders
- No optimization to just remove from local state without reloading

**Current Flow**:
1. Delete order via API
2. Remove from local state ✅ (good)
3. But then `refreshOrders()` is called elsewhere, reloading everything ❌

### 4. No Caching
- No caching mechanism found in backend
- Every request hits the database
- Serializer methods run on every request

## Optimizations Needed

### Backend Optimizations

1. **Optimize `perform_destroy`**:
   - Prefetch order items before deletion
   - Bulk query `FinishedInventory` records
   - Use bulk operations for stock release

2. **Optimize OrderSerializer**:
   - Prefetch `StockMovement` records in queryset
   - Cache stock action/result lookups
   - Use `Prefetch` objects to reduce queries

3. **Add Database Indexes**:
   - Index on `StockMovement.reference_number`
   - Index on `StockMovement.movement_type`
   - Index on `StockMovement.timestamp`

4. **Consider Caching**:
   - Cache order lists for short periods
   - Cache stock action/result lookups

### Frontend Optimizations

1. **Optimize Delete Flow**:
   - Don't call `refreshOrders()` after delete
   - Just remove from local state (already done)
   - Only refresh if user explicitly requests it

2. **Lazy Load Stock Information**:
   - Don't load stock action/result for all items
   - Load on-demand when viewing order details

## Implementation Plan

1. ✅ Optimize backend delete endpoint
   - Added `_release_stock_bulk()` function that uses bulk operations
   - Prefetches order items before deletion
   - Reduces queries from 3N+1 to ~3 queries total

2. ✅ Optimize OrderSerializer queries
   - Added prefetch for StockMovement records in OrderListView
   - Modified `get_stock_action()` and `get_stock_result()` to use prefetched data
   - Reduces queries from 2-3 per item to 0 per item (using prefetched data)

3. ✅ Fix frontend refresh behavior
   - Removed unnecessary `refreshOrders()` calls after delete
   - Provider already removes order from local state
   - Only refresh inventory to update stock levels

4. ⏳ Add database indexes (if needed)
   - Consider adding indexes on:
     - `StockMovement.reference_number`
     - `StockMovement.movement_type`
     - `StockMovement.timestamp`

5. ⏳ Consider caching (future enhancement)
   - Could add Redis caching for order lists
   - Cache stock action/result lookups

## Changes Made

### Backend (`backend/orders/views.py`)
- Optimized `perform_destroy()` to prefetch order items
- Added `_release_stock_bulk()` function for efficient stock release
- Updated `OrderListView.get_queryset()` to prefetch StockMovement records

### Backend (`backend/orders/serializers.py`)
- Modified `get_stock_action()` to use prefetched movements
- Modified `get_stock_result()` to use prefetched movements and skip unnecessary queries

### Frontend (`place-order-final/lib/features/orders/`)
- Removed `refreshOrders()` calls after delete in:
  - `mobile_orders_page.dart`
  - `orders_page.dart`
- Provider already handles state updates locally

## Expected Performance Improvements

**Before**:
- Delete order with 5 items: ~16 queries (1 + 3*5)
- Load 20 orders with 5 items each: ~200-300 queries (2-3 per item)
- Total delete + reload: ~216-316 queries

**After**:
- Delete order with 5 items: ~3 queries (bulk operations)
- Load 20 orders with 5 items each: ~5-10 queries (prefetched)
- Total delete + no reload: ~3 queries

**Improvement**: ~99% reduction in database queries

