# WhatsApp Crawler Updates - October 23, 2025

## Overview
Updated the WhatsApp crawler with improved message scraping, date filtering, and better handling of truncated messages, images, and voice notes.

## Key Changes

### 1. **Date Filtering - Current Day + Previous Day Only**
- **Feature**: Crawler now only collects messages from the current day and previous day
- **Implementation**: 
  - `is_message_in_date_range()` method checks message timestamps
  - Filters out messages older than 2 days during processing
  - Scroll stops automatically when hitting messages older than cutoff date
- **Benefits**: 
  - Reduces processing time
  - Avoids duplicate messages from old scrapes
  - Focuses on relevant recent orders

### 2. **Improved Scroll Handling**
- **Date-Aware Scrolling**: Stops scrolling when messages older than 2 days are detected
- **DOM Change Detection**: Tracks message count changes during scrolling
- **Stable Count Logic**: Stops after 20 consecutive scrolls with no new messages
- **Aggressive Scrolling**: Uses Ctrl+Home every 10th scroll for better reach
- **Message Capture During Scroll**: Captures messages incrementally to avoid missing any

### 3. **Enhanced Timestamp Extraction**
- **Three-Method Approach**:
  1. `data-pre-plain-text` attribute (most accurate)
  2. Visible time spans (assumes today's date)
  3. Processing time fallback
- **Timestamp Contamination Cleaning**: Removes timestamps appended to company names
  - Example: "Maltos08:09" → "Maltos"
  - Example: "Casa bella08:11" → "Casa bella"

### 4. **Better Truncated Message Handling**
- Detects truncated messages (containing '…' or '...')
- Automatically clicks "Read more" button
- Re-extracts full content after expansion
- Prevents duplicate lines from expansion process

### 5. **Improved Media Detection**
- **Voice Messages**: Multiple selector fallbacks for voice detection
- **Images**: Detects images with proper URL extraction (http/blob URLs)
- **Videos**: Basic video detection (limited by WhatsApp Web)
- **Duration Extraction**: Extracts voice message duration from slider or visible text

### 6. **Message Verification**
- Generates verification hash for each message
- Validates message integrity before adding to results
- Checks for required fields (id, content/media, timestamp)

## Backend Duplicate Prevention

### Database Level
**Model**: `WhatsAppMessage` (backend/whatsapp/models.py)
- **Unique Constraint**: `message_id` field has `unique=True`
- **Content Hash**: `content_hash` field stores MD5 hash for deduplication
- **Indexes**: Optimized indexes on `message_type`, `timestamp`, `sender_phone`, `is_deleted`

### API Level
**Endpoint**: `/api/whatsapp/receive-messages` (backend/whatsapp/views.py)

#### Duplicate Detection Strategy:
1. **Primary Check**: Look up by `message_id` (WhatsApp's unique identifier)
2. **Secondary Check**: If not found by ID, check by:
   - `sender_name`
   - `content` (exact match)
   - `timestamp` (within 1-minute window)
   - `is_deleted=False`

#### Handling Existing Messages:
- **If Found**: Updates existing message with new data (respects soft-delete)
- **If Deleted**: Skips the message (respects `is_deleted=True`)
- **If New**: Creates new message record

```python
# From backend/whatsapp/views.py:335-355
existing_message = None

# First try by message_id
try:
    existing_message = WhatsAppMessage.objects.get(message_id=msg_data['id'])
    # Respect soft-delete: if deleted, skip updates/creation
    if existing_message.is_deleted:
        continue
except WhatsAppMessage.DoesNotExist:
    # If not found by ID, check by content + sender + timestamp (within 1 minute window)
    time_window_start = timestamp - timedelta(minutes=1)
    time_window_end = timestamp + timedelta(minutes=1)
    
    existing_message = WhatsAppMessage.objects.filter(
        sender_name=msg_data['sender'],
        content=msg_data['content'],
        timestamp__gte=time_window_start,
        timestamp__lte=time_window_end,
        is_deleted=False
    ).first()

if existing_message:
    # Update existing message
    ...
else:
    # Create new message
    ...
```

### Content Hash Deduplication
**Endpoint**: `/api/whatsapp/receive-html-messages` (backend/whatsapp/views.py:563-570)

```python
# Check if message already exists (by ID or content hash for deduplication)
content_hash = hashlib.md5(parsed_content['content'].encode('utf-8')).hexdigest()

existing_message = WhatsAppMessage.objects.filter(
    models.Q(message_id=message_id) | 
    models.Q(content_hash=content_hash)
).first()
```

### Processing Status Check
**Endpoint**: `/api/whatsapp/process-messages-to-orders` (backend/whatsapp/views.py:1066-1075)

```python
for message in messages:
    try:
        # Skip if already processed
        if message.processed:
            warnings.append({
                'message_id': message.message_id,
                'warning': 'Message already processed',
                'existing_order': message.order.order_number if message.order else None
            })
            continue
```

## Known Limitations

### Images and Voice Notes
- **WhatsApp Web Limitation**: Images use blob URLs that expire quickly
- **Voice Notes**: Duration extraction works, but audio file access is limited
- **Workaround**: Media detection works for classification, but actual media content may not persist
- **Recommendation**: Focus on text-based orders; treat images/voice as supplementary

### Timestamp Accuracy
- **Best Case**: Full date/time from `data-pre-plain-text` attribute
- **Fallback**: Time-only from visible spans (assumes today's date)
- **Edge Case**: Messages scraped after midnight may have incorrect dates if using fallback

### Scroll Performance
- **Large Groups**: May take 5-10 minutes to scroll through thousands of messages
- **Date Filtering**: Significantly improves performance by stopping early
- **Network Dependent**: Slow connections may cause incomplete scrolling

## Testing Recommendations

1. **Date Range Testing**: Verify only current + previous day messages are collected
2. **Duplicate Testing**: Send same message twice, verify only one is stored
3. **Truncation Testing**: Send long messages, verify full content is captured
4. **Media Testing**: Send voice note and image, verify detection works
5. **Timestamp Testing**: Check timestamps are accurate and properly formatted

## Configuration

### Environment Variables
- `TARGET_GROUP_NAME`: WhatsApp group to scrape (default: "ORDERS Restaurants")

### Adjustable Parameters
- `max_scrolls`: Maximum scroll attempts (default: 200)
- `stable_count`: Scrolls with no new messages before stopping (default: 20)
- `scroll_wait_time`: Wait time after each scroll (default: 6 seconds)
- `date_cutoff`: Days to look back (default: 2 days)

## Future Improvements

1. **Incremental Scraping**: Only scrape new messages since last run
2. **Better Media Handling**: Explore WhatsApp Web API for better media access
3. **Sender Identification**: Extract individual sender names from group messages
4. **Real-time Monitoring**: WebSocket-based live message detection
5. **Error Recovery**: Better handling of Chrome crashes and network issues

