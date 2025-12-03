# Source Product Stock Deduction - Clarification Needed

## User Report
"Stock not being handled correctly for example lemons stock not coming down when stock used from lemon, stay at 26 kg"

## User Question
"There is no product lemon? What is going on here"

## Investigation Needed

### Possible Scenarios:

1. **Same Product Issue**:
   - Ordered product: "Lemons" (ID: 123)
   - Source product selected: "Lemons" (ID: 123) - same product
   - Stock should still be deducted from "Lemons"
   - **Question**: Can you select the same product as both ordered and source?

2. **Product Name Mismatch**:
   - Ordered product: "Lemons" (plural)
   - Source product: "Lemon" (singular) - different product
   - User says "There is no product lemon"
   - **Question**: Does "Lemon" (singular) exist as a separate product?

3. **Product Not in Suggestions**:
   - Source products are filtered from `_getSuggestionsForItem(originalText)`
   - Only shows products that match the search term AND have stock
   - **Question**: Is "lemon" showing up in the source product list?

4. **Case Sensitivity**:
   - Product names might be case-sensitive
   - "Lemon" vs "lemon" vs "LEMON"
   - **Question**: Are product names case-sensitive in the database?

## Current Code Flow

### Frontend (`always_suggestions_dialog.dart`):
1. Line 4739: Gets all suggestions for the item: `_getSuggestionsForItem(originalText)`
2. Line 4740-4755: Filters to products with stock
3. Line 4786-4794: Stores source product with `id`, `name`, `unit`, etc.
4. Line 2401: Sends `source_product_id` to backend

### Backend (`whatsapp/views.py`):
1. Line 2681-2695: Extracts source product info BEFORE stock reservation
2. Line 2694-2695: Determines `stock_product` and `stock_quantity`
3. Line 2703-2708: Reserves stock from `stock_product` (source if specified)

## Questions to Answer

1. **What product name is shown in the source product list?**
   - Is it "Lemons", "Lemon", or something else?

2. **What product ID is being sent?**
   - Check `itemData['source_product_id']` in the order creation

3. **Is the source product the same as the ordered product?**
   - If yes, stock should still be deducted (just from the same product)

4. **What does the backend log show?**
   - Check logs for which product stock is being reserved from

## Debugging Steps

1. Add logging to see what source product is selected
2. Add logging to see what product ID is sent to backend
3. Add logging to see which product stock is reserved from
4. Check database to see actual product names and IDs

## Next Steps

Need user to clarify:
- What exact product name appears in the source product selection list?
- What product are they ordering (exact name)?
- What product are they selecting as source (exact name)?
- Are they the same product or different products?

