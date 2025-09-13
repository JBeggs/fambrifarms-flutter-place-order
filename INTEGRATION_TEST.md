# Integration Test Guide

## Testing the Django Backend Integration

This guide walks through testing the complete integration between place-order-final Flutter app and the Django backend.

## Prerequisites

1. **Django Backend Running**
   ```bash
   cd backend/
   python manage.py makemigrations whatsapp
   python manage.py migrate
   python manage.py runserver
   ```

2. **Python WhatsApp Scraper Running**
   ```bash
   cd place-order-final/python/
   python whatsapp_server.py
   ```

3. **Flutter App**
   ```bash
   cd place-order-final/
   flutter run -d macos
   ```

## Test Scenarios

### 1. Health Check Test
**Objective**: Verify Django backend connectivity

**Steps**:
1. Open Flutter app
2. Check if health check passes
3. Verify both Django (port 8000) and Python scraper (port 5001) are accessible

**Expected Result**: 
- Django health endpoint returns: `{"status": "healthy", "service": "django-whatsapp-integration"}`
- No connection errors in Flutter app logs

### 2. WhatsApp Message Scraping Test
**Objective**: Test message scraping and Django processing

**Steps**:
1. Start WhatsApp scraper in Flutter app
2. Wait for QR code scan and WhatsApp Web to load
3. Click "Refresh Messages" in Flutter app
4. Verify messages appear in Django admin

**Expected Result**:
- Messages scraped from Python service
- Messages sent to Django `/api/whatsapp/receive-messages/`
- Messages classified (order, stock, instruction, demarcation, other)
- Messages visible in Django admin at `/admin/whatsapp/whatsappmessage/`

### 3. Stock Update Processing Test
**Objective**: Test SHALLOME stock message processing

**Test Data**: Use this sample stock message
```
STOKE AS AT 28 AUGUST 2025
1.Spinach 3kg
2.Patty pan 12 pun
3.Deveined Spinach 3.5kg
4.Cocktail 25 Pun
5.Green grape 4up
6.Red Grape 4 pun
7.Beetroot 11kg
8.Grape fruits 11kg
9.Pine Apple 1
10.Water melon 1
```

**Steps**:
1. Send test message from SHALLOME (+27 61 674 9368)
2. Refresh messages in Flutter app
3. Check Django admin for StockUpdate creation

**Expected Result**:
- Message classified as `stock` type
- StockUpdate object created with parsed items
- Items properly parsed with quantities and units
- Available in `/admin/whatsapp/stockupdate/`

### 4. Order Day Demarcation Test
**Objective**: Test order day boundary detection

**Test Data**: Use this sample demarcation message
```
Thursday orders starts here. 👇👇👇
```

**Steps**:
1. Send demarcation message
2. Refresh messages in Flutter app
3. Check for OrderDayDemarcation creation

**Expected Result**:
- Message classified as `demarcation` type
- OrderDayDemarcation object created
- Subsequent messages tagged with correct order_day

### 5. Order Creation Test
**Objective**: Test WhatsApp message to Django Order conversion

**Test Data**: Use this sample order message
```
Mugg and Bean

Tomatoes x3 
Sweet melonx1 
Bananas 2kg 
Onions 10kg 
Lemon x2 
Mixed lettuce x3box 
Cherry tomatoes x15 200g 
Carrots 2kg 
Spring onion 1kg 
Mushrooms x10 
Grapesx1 
Red cabage x2
Strawberry x1

Thanks
```

**Steps**:
1. Send order message
2. Refresh messages in Flutter app
3. Select message and click "Process to Orders"
4. Check Django admin for Order creation

**Expected Result**:
- Message classified as `order` type
- Customer created/found for "Mugg and Bean"
- Order object created with correct order_date (Monday/Thursday)
- OrderItems created for each parsed item
- Products created if they don't exist
- Order visible in `/admin/orders/order/`

### 6. Stock Validation Test
**Objective**: Test order validation against available stock

**Prerequisites**: 
- Stock update from SHALLOME processed
- Order created with overlapping items

**Steps**:
1. Create order with items that exist in stock
2. Call stock validation API
3. Check allocation results

**Expected Result**:
- Items marked as `available`, `partial`, or `out_of_stock`
- Correct quantity allocation
- Stock deduction calculated

### 7. End-to-End Workflow Test
**Objective**: Test complete order processing workflow

**Steps**:
1. Send SHALLOME stock update
2. Send order day demarcation
3. Send multiple restaurant orders
4. Process all messages to orders
5. Validate orders against stock
6. Check final state in Django admin

**Expected Result**:
- All messages properly classified
- Orders created with correct business rules
- Stock validation working
- Complete audit trail in processing logs

## Debugging Tips

### Django Logs
```bash
# Check Django server logs for errors
tail -f django.log

# Check database for created objects
python manage.py shell
>>> from whatsapp.models import *
>>> WhatsAppMessage.objects.count()
>>> StockUpdate.objects.count()
>>> Order.objects.count()
```

### Flutter Logs
```bash
# Check Flutter console for API errors
flutter logs

# Look for [DJANGO] and [WHATSAPP] prefixed logs
```

### API Testing
```bash
# Test Django endpoints directly
curl http://127.0.0.1:8000/api/whatsapp/health/
curl http://127.0.0.1:8000/api/whatsapp/messages/
curl http://127.0.0.1:8000/api/orders/orders/

# Test Python scraper
curl http://127.0.0.1:5001/api/health
curl http://127.0.0.1:5001/api/messages
```

## Common Issues

### 1. Connection Refused
- **Cause**: Django server not running
- **Fix**: `python manage.py runserver`

### 2. Migration Errors
- **Cause**: WhatsApp models not migrated
- **Fix**: `python manage.py makemigrations whatsapp && python manage.py migrate`

### 3. CORS Errors
- **Cause**: Flutter app blocked by CORS policy
- **Fix**: Check CORS_ALLOWED_ORIGINS in Django settings

### 4. Message Classification Issues
- **Cause**: Message content doesn't match expected patterns
- **Fix**: Check `classify_message_type()` function in services.py

### 5. Order Date Validation Errors
- **Cause**: Order placed on invalid day
- **Fix**: Ensure order_date is Monday (0) or Thursday (3)

## Success Criteria

✅ **Integration Complete When**:
- [ ] Health checks pass for both services
- [ ] Messages scraped and processed in Django
- [ ] Stock updates parsed and stored
- [ ] Orders created from WhatsApp messages
- [ ] Stock validation working correctly
- [ ] All business rules enforced (Monday/Thursday orders)
- [ ] Flutter app displays Django data correctly
- [ ] No critical errors in logs

## Performance Benchmarks

- **Message Processing**: < 2 seconds per message
- **Order Creation**: < 5 seconds per order
- **Stock Validation**: < 1 second per order
- **API Response Time**: < 500ms for most endpoints

This integration test ensures the complete workflow from WhatsApp message scraping to Django order management works seamlessly.
