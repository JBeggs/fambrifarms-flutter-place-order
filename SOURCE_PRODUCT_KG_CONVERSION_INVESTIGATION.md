# Source Product KG Conversion Investigation

## Issue Summary

When selecting a source product with unit "head" (or other count-based units like "each", "bunch", etc.) in the confirm order screen, the quantity input field only shows the product's native unit. Users cannot enter quantities in kg, even though the system should support converting kg to head based on packaging size.

## Current Behavior

### Location
- **File**: `place-order-final/lib/features/messages/widgets/always_suggestions_dialog.dart`
- **Method**: `_showOutOfStockOptionsModal()` - Source product quantity input (lines 4163-4231)
- **Order Confirmation**: `_confirmOrder()` - Source product data storage (lines 1974-1976)

### Current Implementation

1. **Source Product Selection** (lines 4072-4081):
   ```dart
   _selectedSourceProducts[originalText] = {
     'id': sourceProductId,
     'name': sourceSuggestion['product_name'] ?? '',
     'unit': sourceSuggestion['unit'] ?? '',  // e.g., "head"
     'stockLevel': (sourceAvailableCount ?? 0) > 0 ? sourceAvailableCount : (sourceAvailableWeightKg ?? 0.0),
   };
   ```
   - Only stores the product's native unit
   - Does NOT store `packaging_size` information

2. **Quantity Input Field** (lines 4198-4226):
   ```dart
   TextField(
     decoration: InputDecoration(
       labelText: 'Quantity to Deduct (${selectedSourceProduct['unit'] ?? ''}) *',
       suffixText: selectedSourceProduct['unit'] as String? ?? '',  // Only shows "head"
       // ...
     ),
   )
   ```
   - **Problem**: Only shows the product's native unit (e.g., "head")
   - **Problem**: No option to enter kg
   - **Problem**: No conversion calculation displayed

3. **Order Confirmation** (lines 1974-1976):
   ```dart
   itemData['source_product_id'] = sourceProduct['id'];
   itemData['source_quantity'] = sourceQuantity;  // Raw quantity entered
   itemData['source_unit'] = sourceProduct['unit'] ?? 'each';  // Always native unit
   ```
   - Stores quantity in the product's native unit only
   - No conversion logic applied

## Required Behavior

### User Flow
1. User selects a source product with unit "head" (e.g., "Cabbage (1kg per head)")
2. User should be able to choose input unit: **"head"** OR **"kg"**
3. If user enters kg:
   - System converts kg to head: `head_count = kg_entered / weight_per_head_kg`
   - Shows calculation: "X kg = Y head (at Z kg per head)"
   - Deducts the calculated head count from stock
4. If user enters head:
   - Uses directly (current behavior)
   - Shows available stock in head

### Data Available

From the backend API (`django_backend_fix/whatsapp/views.py` lines 137-155):
- `packaging_size`: String like "1kg", "500g", "2kg", etc.
- `available_quantity_count`: Number of units (head, each, etc.)
- `available_quantity_kg`: Total weight in kg
- `unit`: Product unit ("head", "each", "bunch", etc.)

The `sourceSuggestion` object contains:
```dart
{
  'product_id': int,
  'product_name': String,
  'unit': String,  // e.g., "head"
  'packaging_size': String?,  // e.g., "1kg" - AVAILABLE but NOT stored
  'stock': {
    'available_quantity_count': int,
    'available_quantity_kg': double,
  }
}
```

### Conversion Logic Needed

1. **Parse packaging_size** using `PackagingSizeParser.parseToKg()`:
   - "1kg" → 1.0 kg per head
   - "500g" → 0.5 kg per head
   - "2kg" → 2.0 kg per head

2. **Convert kg to head**:
   ```dart
   double kgEntered = userInput;
   double weightPerHeadKg = PackagingSizeParser.parseToKg(packagingSize);
   double headCount = kgEntered / weightPerHeadKg;
   ```

3. **Display calculation**:
   ```
   "5.0 kg = 5 head (at 1.0 kg per head)"
   ```

4. **Store for order**:
   - Store `source_quantity` as the **head count** (converted value)
   - Store `source_unit` as **"head"** (native unit)
   - Optionally store `source_quantity_kg` for reference

## Implementation Requirements

### 1. Store Packaging Size When Selecting Source Product

**Location**: Lines 4074-4079

**Change**:
```dart
_selectedSourceProducts[originalText] = {
  'id': sourceProductId,
  'name': sourceSuggestion['product_name'] ?? '',
  'unit': sourceSuggestion['unit'] ?? '',
  'packagingSize': sourceSuggestion['packaging_size'] as String?,  // ADD THIS
  'stockLevel': (sourceAvailableCount ?? 0) > 0 ? sourceAvailableCount : (sourceAvailableWeightKg ?? 0.0),
  'availableCount': sourceAvailableCount,  // ADD THIS
  'availableWeightKg': sourceAvailableWeightKg,  // ADD THIS
};
```

### 2. Add Unit Selector (Head/KG Toggle)

**Location**: Lines 4196-4227

**Add**:
- Radio buttons or dropdown to select input unit: "head" or "kg"
- Only show kg option if `packagingSize` is available
- Store selected input unit in state: `_sourceQuantityUnits[originalText] = 'head' | 'kg'`

### 3. Add Conversion Logic and Display

**Location**: Lines 4216-4225 (onChanged handler)

**Add**:
- Check if input unit is "kg"
- If kg: Convert to head using packaging_size
- Display conversion calculation below input field
- Store converted head count in `_sourceQuantities[originalText]`

### 4. Update Order Confirmation

**Location**: Lines 1974-1976

**Change**:
- Always store `source_unit` as the product's native unit (head)
- Always store `source_quantity` as the native unit count (converted if needed)
- Optionally store `source_quantity_kg` if user entered kg

## Example Scenarios

### Scenario 1: Cabbage (1kg per head)
- Product: "Cabbage", unit: "head", packaging_size: "1kg"
- Stock: 10 head available
- User enters: **5 kg**
- Conversion: 5 kg ÷ 1 kg/head = **5 head**
- Display: "5.0 kg = 5 head (at 1.0 kg per head)"
- Stock deduction: 5 head

### Scenario 2: Cabbage (1kg per head) - Enter Head Directly
- Product: "Cabbage", unit: "head", packaging_size: "1kg"
- Stock: 10 head available
- User enters: **5 head**
- No conversion needed
- Display: "5 head"
- Stock deduction: 5 head

### Scenario 3: Product Without Packaging Size
- Product: "Lettuce", unit: "head", packaging_size: null
- Stock: 10 head available
- User can only enter head (kg option not available)
- Display: "Enter quantity in head"

## Files to Modify

1. **always_suggestions_dialog.dart**:
   - Store packaging_size when selecting source product (line ~4078)
   - Add unit selector UI (line ~4196)
   - Add conversion logic (line ~4216)
   - Update order confirmation (line ~1976)

2. **State Variables Needed**:
   ```dart
   final Map<String, String> _sourceQuantityUnits = {};  // 'head' or 'kg'
   ```

## Backend Considerations

The backend already provides `packaging_size` in the suggestion data. The conversion should happen on the frontend before sending to the backend. The backend expects:
- `source_quantity`: Quantity in the product's native unit (head count)
- `source_unit`: Product's native unit ("head")

## Testing Checklist

- [ ] Select source product with unit "head" and packaging_size "1kg"
- [ ] Verify kg option appears in unit selector
- [ ] Enter kg value and verify conversion calculation displays
- [ ] Verify converted head count is stored correctly
- [ ] Verify order confirmation sends correct head count
- [ ] Test with products without packaging_size (kg option should not appear)
- [ ] Test direct head entry (no conversion needed)
- [ ] Test with different packaging sizes (0.5kg, 2kg, etc.)

