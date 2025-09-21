# Order Testing Framework

## Overview
This document outlines the comprehensive testing framework for WhatsApp message scraping and order processing. The goal is to verify that messages are scraped correctly, orders are processed properly, and the complete workflow from WhatsApp to database works end-to-end.

## Test Data Structure

### Available Test Data (from crawler_test/)
- **27_08_2025_messages.json/html** - Pre-order messages (15 messages)
- **Tuesday_01_09_2025_messages.json/html** - September 1 orders (29 messages)  
- **Thursday_03_09_2025_messages.json/html** - September 3 orders (46 messages)
- **Tuesday_08_09_2025_messages.json/html** - September 8 orders (44 messages)
- **Thursday_10_09_2025_messages.json/html** - September 10 orders (32 messages)
- **Tuesday_15_09_2025_messages.json/html** - September 15 orders (19 messages)
- **messages_captured_during_scroll.json** - Complete dataset (188 messages)
- **messages_raw.html** - Raw HTML of all messages

### Key Test Messages
- **First Message**: "Hi Here is my order... Tomatoes x3..." (27/08/2025)
- **Last Message**: "Culinary" (multiple instances)
- **Stock Messages**: "SHALLOME STOCK AS AT..." with full inventory lists
- **Truncated Messages**: Messages with "Read more" buttons that need expansion

## Test Requirements

### 1. Message Scraping Verification
- [ ] **Completeness**: All 188 messages captured in correct order
- [ ] **Chronological Order**: Messages sorted oldest to newest
- [ ] **Text Completeness**: "Read more" content fully expanded
- [ ] **No Duplicates**: Each unique message captured only once
- [ ] **Timestamp Accuracy**: Proper ISO format timestamps

### 2. Media Content Verification  
- [ ] **Image URLs**: Actual `http/https` URLs captured (not `blob:`)
- [ ] **Voice Messages**: Duration info extracted and stored
- [ ] **Media Type Detection**: Correct classification (image/voice/text)
- [ ] **Media URL Validation**: URLs are accessible and valid

### 3. Message Classification
- [ ] **Order Messages**: Correctly identified and parsed
- [ ] **Stock Updates**: "SHALLOME STOCK" messages classified properly
- [ ] **Instructions**: Non-order text classified correctly
- [ ] **Company Names**: Extracted from order context
- [ ] **Demarcation Messages**: "Tuesday/Thursday orders start here" identified

### 4. Order Processing Integration
- [ ] **Company Assignment**: Orders assigned to correct companies
- [ ] **Item Extraction**: Individual items parsed from order text
- [ ] **Quantity Parsing**: Quantities and units extracted correctly
- [ ] **Database Storage**: Orders saved to Django database
- [ ] **End-to-End Flow**: WhatsApp → Scraper → Parser → Database

## Critical Features to Implement

### 1. WhatsAppCrawler Class Status
**Location**: `place-order-final/python/app/core/whatsapp_crawler.py`

**✅ IMPLEMENTED METHODS**:
- `__init__()` - Initializes crawler with driver, messages, and session management
- `initialize_driver()` - Sets up Chrome WebDriver with persistent session directory
- `start_whatsapp()` - Opens WhatsApp Web, handles QR code/login, selects target group
- `scrape_messages()` - Main scraping method with group selection and message extraction
- `_scrape_from_open_chat()` - Core scraping logic with message deduplication and expansion
- `classify_message(content, media_type)` - Classifies messages as order/stock/instruction/other
- `_scroll_to_load_all_messages()` - Scrolls to load historical messages
- `find_and_select_group(group_name)` - Finds and selects WhatsApp group by name
- `stop()` - Properly closes browser and cleans up resources

**🔄 FEATURES NEEDING VALIDATION**:
- **Read More Expansion**: Implemented but needs testing with real truncated messages
- **Media URL Capture**: Basic implementation present, needs validation with actual media
- **Message Deduplication**: Logic implemented, needs stress testing
- **Error Recovery**: Basic error handling present, needs robustness testing

### 2. Read More Click Logic (Copy from crawler_test/)
**Source**: `crawler_test/whatsapp_crawler_test.py` lines 587-610

**Key Logic**:
```python
# Check for "Read more" button and click it to expand truncated messages
read_more_buttons = msg_elem.find_elements(By.CSS_SELECTOR, '.read-more-button')
if not read_more_buttons:
    # Alternative selector for read more buttons using XPath
    read_more_buttons = msg_elem.find_elements(By.XPATH, './/div[@role="button" and contains(text(), "Read more")]')

if read_more_buttons:
    try:
        print(f"🔍 Found Read more button, clicking to expand...")
        read_more_button = read_more_buttons[0]
        self.driver.execute_script("arguments[0].click();", read_more_button)
        time.sleep(2)  # Wait for message to expand
        
        # Re-extract the expanded message text
        expanded_text_elems = msg_elem.find_elements(By.CSS_SELECTOR, '.copyable-text')
        if expanded_text_elems:
            expanded_text = expanded_text_elems[0].get_attribute('textContent') or expanded_text_elems[0].text or ''
            if expanded_text and len(expanded_text) > len(message_text):
                original_length = len(message_text)
                message_text = expanded_text
                print(f"✅ Expanded message from {original_length} to {len(expanded_text)} characters")
    except Exception as e:
        print(f"⚠️ Could not click Read more button: {e}")
```

### 3. Image/Voice URL Capture
**Current Issue**: Test HTML files show no actual image URLs, only SVG icons

**Required Logic**:
```python
# For images: look for actual http/https URLs
img_elements = msg_elem.find_elements(By.CSS_SELECTOR, 'img[src^="http"]')
if img_elements:
    media_url = img_elements[0].get_attribute('src')
    media_type = 'image'

# For voice: look for voice message containers with duration
voice_elements = msg_elem.find_elements(By.CSS_SELECTOR, '[aria-label*="voice message"], [aria-label*="Voice message"]')
if voice_elements:
    media_type = 'voice'
    # Extract duration from aria-label or nearby elements
```

## Test Implementation Plan

### Phase 1: Core Infrastructure
1. **Create WhatsAppCrawler class** with all required methods
2. **Copy Read more click logic** from crawler_test/
3. **Implement media URL capture** for images and voice
4. **Create test data loader** to use existing JSON/HTML files

### Phase 2: Message Scraping Tests
1. **Test against each day's data** (27_08 through 15_09)
2. **Verify message completeness** and order
3. **Test Read more expansion** on stock messages
4. **Validate timestamp parsing** and formatting

### Phase 3: Order Processing Tests  
1. **Test message classification** (order/stock/instruction)
2. **Test company extraction** from message context
3. **Test item parsing** from order messages
4. **Verify database integration** end-to-end

### Phase 4: Media Content Tests
1. **Test image URL extraction** (when available)
2. **Test voice message detection** and duration parsing
3. **Validate media type classification**
4. **Test blob: URL filtering** (should not be saved)

## Expected Test Results

### Message Counts by Day
- **27_08_2025**: 15 messages (pre-orders)
- **01_09_2025**: 29 messages (Tuesday orders)
- **03_09_2025**: 46 messages (Thursday orders)
- **08_09_2025**: 44 messages (Tuesday orders)
- **10_09_2025**: 32 messages (Thursday orders)  
- **15_09_2025**: 19 messages (Tuesday orders)
- **Total**: 188 messages

### Key Validation Points
1. **First message exists**: "Hi Here is my order... Tomatoes x3..."
2. **Stock messages complete**: Full SHALLOME inventory lists (not truncated)
3. **Company orders parsed**: Venue, Debonairs, Casa Bella, etc.
4. **Chronological order**: 27/08 → 15/09 progression
5. **No missing "Culinary"**: All instances captured

## Database Integration Testing

### Order Processing Workflow
1. **Scrape messages** from WhatsApp Web
2. **Parse into orders** using MessageParser
3. **Save to Django database** via API endpoints
4. **Verify in Flutter UI** that orders appear correctly
5. **Test order editing** and status updates

### Database Schema Validation
- **Messages table**: All scraped messages stored
- **Orders table**: Parsed orders with company assignments
- **OrderItems table**: Individual items with quantities
- **Media table**: Image/voice URLs and metadata

## Success Criteria

### Functional Requirements
- [ ] All 188 messages scraped and stored correctly
- [ ] Read more content fully expanded (no truncation)
- [ ] Orders correctly assigned to companies
- [ ] Items parsed with proper quantities and units
- [ ] Database integration working end-to-end
- [ ] Media URLs captured when available

### Performance Requirements  
- [ ] Scraping completes within reasonable time (< 5 minutes)
- [ ] No memory leaks or browser crashes
- [ ] Reliable session persistence across runs
- [ ] Graceful error handling for network issues

### Data Quality Requirements
- [ ] Zero duplicate messages in final dataset
- [ ] All timestamps in valid ISO format
- [ ] Company names standardized and consistent
- [ ] Item quantities parsed accurately
- [ ] Media URLs validated and accessible

## Test Execution

### Manual Testing Steps
1. Run WhatsApp crawler against live WhatsApp Web
2. Verify all messages captured (compare to known dataset)
3. Check Read more expansion on stock messages
4. Validate order parsing and company assignment
5. Confirm database storage and retrieval

### Automated Testing
1. Unit tests for each scraper method
2. Integration tests using saved HTML/JSON data
3. End-to-end tests with database verification
4. Performance tests for large message volumes

## Notes

- **Read More Critical**: Stock messages are truncated without expansion
- **Image URLs Missing**: Current test data has no actual image URLs
- **Voice Detection**: Need to implement voice message identification
- **Session Management**: WhatsApp session must persist across runs
- **Error Handling**: Must handle network issues and DOM changes gracefully
