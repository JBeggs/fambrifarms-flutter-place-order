# Original Text Field Issue

## 📝 Problem Description

When viewing order PDFs/Excel files, the "Original:" field in the notes should show the **raw WhatsApp text** (e.g., "2kg tomatoes"), but it's showing the **edited/processed version** instead.

## 🔍 Root Cause

The `original_text` field in `OrderItem` is being **updated/overwritten** when order items are edited, instead of remaining immutable.

## ✅ Expected Behavior

### For WhatsApp Orders:
1. **Initial Creation**: `original_text` = "2kg tomatoes" (raw WhatsApp text)
2. **After Editing** (e.g., changing quantity to 3kg or product to "Cherry Tomatoes"):
   - `original_text` should **STILL** be "2kg tomatoes" (unchanged)
   - `quantity`, `product_name`, etc. get updated
   - The PDF/Excel should show:
     ```
     Product: Cherry Tomatoes
     Quantity: 3 kg
     Notes: Original: 2kg tomatoes
     ```

### For Manually Added Items:
1. **When Added**: `original_text` = null (no WhatsApp source)
2. **PDF/Excel**: No "Original:" line shown (which is correct)

## 🔧 Frontend Status

✅ **Frontend is correct** - The display code properly:
1. Shows "Original: [text]" only if `originalText` exists and is not empty
2. Does NOT send `original_text` when manually adding items
3. Formats it correctly in PDF (as a subtitle) and Excel (in notes field)

## ⚠️ Backend Fix Required

The Django backend needs to ensure:

1. **Never update** `original_text` field when editing order items
2. **Only set** `original_text` when creating orders from WhatsApp messages
3. **Leave it null** for manually created order items

### Backend Code to Check:

```python
# In your OrderItem model update method
def update(self, **kwargs):
    # original_text should NOT be in kwargs when updating
    # It should only be set during initial creation from WhatsApp
    if 'original_text' in kwargs:
        # Remove it to prevent accidental overwrites
        kwargs.pop('original_text')
    super().update(**kwargs)
```

## 🧪 How to Test

1. **Create order from WhatsApp** with "2kg tomatoes"
2. **Edit the order** - change quantity to 3kg
3. **Generate PDF/Excel**
4. **Check Notes** - should show "Original: 2kg tomatoes" (NOT "Original: 3kg tomatoes")

## 📊 Current Status

- **Frontend**: ✅ Implemented correctly
- **Backend**: ⚠️ Needs fix to preserve `original_text` immutability

---

**Note**: This is a **backend database/API issue**, not a frontend display issue. The frontend correctly shows whatever the backend provides.

