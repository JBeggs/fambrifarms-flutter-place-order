# Place Order Save Progress Investigation

## Current State

### Existing Infrastructure

1. **OrderItemsPersistence** (`lib/features/messages/utils/order_items_persistence.dart`)
   - Already exists and saves progress
   - Saves ALL state: `selectedSuggestions`, `quantities`, `units`, `stockActions`, `skippedItems`, `useSourceProduct`, `selectedSourceProducts`, `sourceQuantities`, `editedOriginalText`
   - Saves per `messageId` (one file for all orders, keyed by messageId)
   - Has `saveProgress()` and `loadSavedProgress()` methods
   - Has `clearOrderProgress()` method

2. **Save Button** (`always_suggestions_dialog.dart` line ~699)
   - Manual "Save Progress" button exists
   - Calls `_saveProgress()` method (line ~1646)
   - Currently saves ALL items regardless of whether they've been changed

3. **No Auto-Load**
   - No automatic loading of saved progress on dialog open
   - No restore functionality visible in code

### Stock Take Comparison

**Stock Take Save Functionality:**
- Saves only products that have been **added to the stock take list** (manually added or changed)
- Products NOT in the list are not saved (they're still "unprocessed")
- Has auto-save on dispose
- Has auto-load on initState
- Has restore dialog asking user if they want to restore
- Saves: product data + controller values (entered values, comments, wastage, etc.)

**Key Difference:**
- Stock take: Products are **added** to a list (only changed ones are in list)
- Place order: All items come from message (all items exist, but some are "processed" and some are not)

## Requirements Analysis

### What "Changed" Means for Place Order

An item is considered **"changed"** (processed) if ANY of these are true:
1. ✅ Product has been selected (`_selectedSuggestions[originalText] != null`)
2. ✅ Quantity has been modified (`_quantities[originalText]` differs from parsed quantity)
3. ✅ Unit has been changed (`_units[originalText]` differs from parsed unit)
4. ✅ Stock action has been set (`_stockActions[originalText]` is set)
5. ✅ Item has been skipped (`_skippedItems[originalText] == true`)
6. ✅ Source product has been selected (`_selectedSourceProducts[originalText] != null`)
7. ✅ Original text has been edited (`_editedOriginalText[originalText] != originalText`)

An item is **"unprocessed"** (still needs processing) if:
- No product selected
- No changes made from original parsed values
- Not skipped

### What Should Be Saved

**Option A: Save Only Changed Items (Recommended)**
- Only save items that have been changed/processed
- Unprocessed items remain in `_items` but are not saved
- On restore: Load saved items + keep unprocessed items from original message
- **Pros**: Matches stock take behavior, smaller save file, clearer what's done
- **Cons**: Need to merge saved + original on restore

**Option B: Save All Items with Status Flags**
- Save all items but mark which are "processed" vs "unprocessed"
- On restore: Restore all, but show status
- **Pros**: Simpler restore logic
- **Cons**: Saves unnecessary data, doesn't match stock take pattern

**Option C: Save Changed Items + List of Unprocessed**
- Save changed items + list of originalText for unprocessed items
- On restore: Restore changed + add unprocessed from original
- **Pros**: Clear separation, efficient
- **Cons**: Need to track unprocessed list

## Recommended Implementation

### Approach: Save Only Changed Items (Option A)

**Data Structure to Save:**
```dart
{
  'messageId': '...',
  'timestamp': '...',
  'changedItems': [
    {
      'originalText': '...',
      'selectedSuggestion': {...},  // Only if selected
      'quantity': 5.0,
      'unit': 'kg',
      'stockAction': 'reserve',
      'isSkipped': false,
      'useSourceProduct': true,
      'selectedSourceProduct': {...},  // Only if using source
      'sourceQuantity': 10.0,
      'sourceQuantityUnit': 'kg',
      'editedOriginalText': '...',  // Only if edited
    },
    // ... only changed items
  ],
  'unprocessedItems': [
    'originalText1',
    'originalText2',
    // ... list of originalText for items not yet processed
  ]
}
```

### Implementation Steps

1. **Modify `OrderItemsPersistence.saveProgress()`**
   - Add logic to filter only changed items
   - Track unprocessed items (originalText list)
   - Save both changed items and unprocessed list

2. **Add `_isItemChanged()` helper method**
   - Check if item has been modified from original state
   - Returns true if any change detected

3. **Add Auto-Save**
   - Auto-save on dispose (like stock take)
   - Optional: Auto-save on changes (debounced)

4. **Add Auto-Load on Init**
   - Check for saved progress on dialog open
   - Show restore dialog if saved progress exists
   - Merge saved items with unprocessed items from original message

5. **Add Restore Logic**
   - Restore changed items into state maps
   - Keep unprocessed items in `_items` list
   - Reinitialize controllers for restored items

### Key Differences from Stock Take

| Aspect | Stock Take | Place Order |
|--------|-----------|-------------|
| **Items Source** | Manually added | From message (all exist initially) |
| **Changed Detection** | In list = changed | Need to detect changes |
| **Unprocessed** | Not in list | In list but unchanged |
| **Restore** | Replace all | Merge saved + original |

## Files to Modify

1. **`lib/features/messages/utils/order_items_persistence.dart`**
   - Modify `saveProgress()` to filter changed items
   - Add `unprocessedItems` tracking
   - Update data structure

2. **`lib/features/messages/widgets/always_suggestions_dialog.dart`**
   - Add `_isItemChanged()` method
   - Modify `_saveProgress()` to pass changed items only
   - Add `_loadSavedProgress()` method (auto-load on init)
   - Add `_restoreProgress()` method
   - Add auto-save on dispose
   - Update `_initializeSelections()` to check for saved progress

## Data to Track Per Item

**Original State (from message):**
- `originalText` - original text from message
- `parsed` - parsed quantity/unit
- `suggestions` - available product suggestions

**Current State (user changes):**
- `_selectedSuggestions[originalText]` - selected product
- `_quantities[originalText]` - quantity (may differ from parsed)
- `_units[originalText]` - unit (may differ from parsed)
- `_stockActions[originalText]` - stock action
- `_skippedItems[originalText]` - skip flag
- `_useSourceProduct[originalText]` - using source product
- `_selectedSourceProducts[originalText]` - source product data
- `_sourceQuantities[originalText]` - source quantity
- `_sourceQuantityUnits[originalText]` - source quantity unit
- `_editedOriginalText[originalText]` - edited text

## Change Detection Logic

```dart
bool _isItemChanged(String originalText) {
  // Check if product selected
  if (_selectedSuggestions[originalText] != null) return true;
  
  // Check if skipped
  if (_skippedItems[originalText] == true) return true;
  
  // Check if original text edited
  final originalItem = _items.firstWhere((i) => i['original_text'] == originalText);
  if (_editedOriginalText[originalText] != originalText) return true;
  
  // Check if quantity changed from parsed
  final parsed = originalItem['parsed'] as Map<String, dynamic>;
  final parsedQuantity = (parsed['quantity'] as num?)?.toDouble() ?? 1.0;
  final currentQuantity = _quantities[originalText] ?? parsedQuantity;
  if (currentQuantity != parsedQuantity) return true;
  
  // Check if unit changed from parsed
  final parsedUnit = parsed['unit'] as String? ?? 'each';
  final currentUnit = _units[originalText] ?? parsedUnit;
  if (currentUnit != parsedUnit) return true;
  
  // Check if stock action set (and not default)
  if (_stockActions[originalText] != null && _stockActions[originalText] != 'reserve') return true;
  
  // Check if source product selected
  if (_selectedSourceProducts[originalText] != null) return true;
  
  return false;
}
```

## Restore Logic Flow

1. **On Dialog Open:**
   - Check if saved progress exists for `messageId`
   - If exists, show restore dialog
   - If user confirms:
     - Load saved progress
     - Restore changed items into state maps
     - Keep unprocessed items from original `_items`
     - Reinitialize controllers

2. **On Save:**
   - Filter `_items` to find changed items
   - Save changed items + list of unprocessed originalText values
   - Show success message

3. **On Order Confirmation:**
   - Clear saved progress for this `messageId`
   - (Order is complete, no need to save)

## Edge Cases

1. **Item removed from message**: If original message changes, unprocessed items may no longer exist
2. **Item added to message**: New items should be added as unprocessed
3. **Multiple saves**: Should overwrite previous save (same messageId)
4. **Partial restore**: User may want to restore some items but not others (not implemented in stock take)

## Testing Scenarios

1. **Save with some items changed**: Only changed items saved
2. **Restore with saved progress**: Changed items restored, unprocessed remain
3. **Save then add new item**: New item not in saved data, appears as unprocessed
4. **Save then confirm order**: Saved progress cleared
5. **Save then close dialog**: Progress persists, can restore on reopen

## Summary

**Current State:**
- Save functionality exists but saves ALL items
- No auto-load/restore functionality
- Manual save button only

**Required Changes:**
1. Modify save to only store changed items
2. Track unprocessed items separately
3. Add auto-load on dialog open
4. Add restore functionality
5. Add auto-save on dispose
6. Clear saved progress on order confirmation

**Complexity:** Medium
**Impact:** High (prevents data loss, improves UX)
**Pattern:** Similar to stock take but adapted for different data structure

