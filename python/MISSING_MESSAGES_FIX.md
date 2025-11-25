# Missing Messages Fix - WhatsApp Crawler

## Problem Identified

The WhatsApp crawler was missing messages when the script wasn't run for a day or more. This happened because:

1. **Date Filtering**: The crawler only fetched messages from **today** and **yesterday** (1 day back)
2. **Gap Issue**: If the script wasn't run yesterday, messages from 2+ days ago were filtered out
3. **No Recovery**: There was no way to fetch missed messages from previous days

## Root Cause

In `simplified_whatsapp_crawler.py`:
- `is_message_in_date_range()` only allowed messages from current day or previous day
- `get_current_messages()` hardcoded `days_back=1` (today + yesterday only)
- No parameter to adjust the date range for catching up after missed runs

## Solution Implemented

### 1. **Configurable Date Range**
- Added `days_back` parameter to `is_message_in_date_range()` and `get_current_messages()`
- Default: `days_back=1` (today + yesterday) for normal operation
- Can be set to `7` for last week, `30` for last month, or `None` to disable filtering entirely

### 2. **Initial Scan Enhancement**
- Initial scan now uses `days_back=7` to catch any missed messages from the past week
- Regular periodic checks still use `days_back=1` for efficiency

### 3. **Manual Scan Option**
- Manual scan endpoint (`/api/whatsapp/manual-scan`) now accepts `days_back` parameter
- Allows fetching messages from any number of days back

## Usage

### Normal Operation (Default)
```python
# Fetches today + yesterday (default)
messages = crawler.get_current_messages(scroll_to_load_more=True)
```

### Catch Up After Missed Days
```python
# Fetch last 7 days to catch missed messages
messages = crawler.get_current_messages(scroll_to_load_more=True, days_back=7)

# Fetch last 30 days
messages = crawler.get_current_messages(scroll_to_load_more=True, days_back=30)

# Fetch ALL messages (no date filtering)
messages = crawler.get_current_messages(scroll_to_load_more=True, days_back=None)
```

### Via API (Manual Scan)
```bash
# Fetch last 7 days
curl -X POST http://localhost:5001/api/whatsapp/manual-scan \
  -H "Content-Type: application/json" \
  -d '{"scroll_to_load_more": true, "days_back": 7}'

# Fetch last 30 days
curl -X POST http://localhost:5001/api/whatsapp/manual-scan \
  -H "Content-Type: application/json" \
  -d '{"scroll_to_load_more": true, "days_back": 30}'
```

## Changes Made

### `simplified_whatsapp_crawler.py`
1. **`is_message_in_date_range()`**: Added `days_back` parameter (default: 1)
2. **`get_current_messages()`**: Added `days_back` parameter (default: 1)
3. **`run_periodic_check()`**: Initial scan now uses `days_back=7` to catch missed messages

### `simplified_routes.py`
1. **`manual_scan()` endpoint**: Added `days_back` parameter support (default: 1)

## Workaround for Missing Messages

If you notice messages are missing:

1. **Quick Fix**: Run a manual scan with `days_back=7`:
   ```bash
   curl -X POST http://localhost:5001/api/whatsapp/manual-scan \
     -H "Content-Type: application/json" \
     -d '{"scroll_to_load_more": true, "days_back": 7}'
   ```

2. **For Longer Gaps**: Increase `days_back` to match the gap:
   - Missed 3 days? Use `days_back=3`
   - Missed a week? Use `days_back=7`
   - Missed a month? Use `days_back=30`

3. **Initial Scan**: The crawler now automatically fetches the last 7 days on startup to catch any missed messages

## Testing

To test the fix:

1. **Stop the crawler** if running
2. **Wait a day** (or simulate by changing system date)
3. **Start the crawler** - it should fetch last 7 days automatically
4. **Check logs** for: `📅 [DATE_RANGE] Collecting messages from last 7 days`
5. **Verify** messages from the missed day are included

## Future Improvements

1. **Query Django for Last Message**: Query Django backend for the last message timestamp and fetch messages since then
2. **Persistent Last Run Time**: Store last successful run time in a file/database
3. **Automatic Gap Detection**: Detect gaps in message timestamps and automatically fetch missing ranges

## Notes

- **Performance**: Fetching more days takes longer. Use `days_back=1` for regular operation, `days_back=7` for catch-up
- **Deduplication**: Django backend handles duplicate prevention, so fetching overlapping date ranges is safe
- **Scroll Stopping**: Scroll stops automatically when reaching messages older than the cutoff date (if date filtering enabled)

