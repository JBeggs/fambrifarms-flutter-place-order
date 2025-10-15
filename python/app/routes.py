from flask import Blueprint, jsonify, request
from datetime import datetime
import os
import requests
from app.core.whatsapp_crawler import WhatsAppCrawler
from app.core.message_parser import MessageParser
from selenium.webdriver.common.by import By

whatsapp_bp = Blueprint('whatsapp', __name__)

# Global instances
crawler = WhatsAppCrawler()
parser = MessageParser()
print(f"🚨 [INIT] Created crawler instance: {id(crawler)}")
print(f"🚨 [INIT] Crawler messages attr exists: {hasattr(crawler, 'messages')}")
print(f"🚨 [INIT] Crawler messages length: {len(crawler.messages)}")


@whatsapp_bp.route('/api/whatsapp/status', methods=['GET'])
def get_status():
    """Get the status of the WhatsApp crawler"""
    status = {
        "crawler_running": crawler.is_running,
        "driver_active": crawler.driver is not None,
        "message_count": len(crawler.messages)
    }
    return jsonify(status)

@whatsapp_bp.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    payload = {
        "status": "ok",
        "crawler_running": crawler.is_running,
        "driver_active": crawler.driver is not None,
        "message_count": len(crawler.messages)
    }
    print(f"[PY][HEALTH] {payload}")
    return jsonify(payload)

@whatsapp_bp.route('/api/whatsapp/start', methods=['POST'])
def start_whatsapp():
    """Start WhatsApp crawler"""
    if not crawler.driver:
        crawler.initialize_driver()
    
    result = crawler.start_whatsapp()
    crawler.is_running = True
    print(f"[PY][START] result={result}")
    return jsonify(result)

@whatsapp_bp.route('/api/whatsapp/stop', methods=['POST'])
def stop_whatsapp():
    """Stop WhatsApp crawler"""
    crawler.stop()
    return jsonify({"status": "stopped"})

@whatsapp_bp.route('/api/messages', methods=['GET'])
def get_messages():
    """Get all scraped messages with enhanced parsing"""
    import time
    timestamp = time.time()
    print(f"🚨🚨🚨 [API] /api/messages called at {timestamp} - checking cache")
    print(f"🚨 [API] crawler instance ID: {id(crawler)}")
    print(f"🚨 [API] crawler.messages exists: {hasattr(crawler, 'messages')}")
    print(f"🚨 [API] crawler.messages length: {len(crawler.messages) if hasattr(crawler, 'messages') else 'NO ATTR'}")
    print(f"🚨 [API] crawler.messages empty check: {not crawler.messages if hasattr(crawler, 'messages') else 'NO ATTR'}")
    print(f"🚨 [API] crawler.messages is list: {isinstance(crawler.messages, list) if hasattr(crawler, 'messages') else 'NO ATTR'}")
    
    if not crawler.driver or not crawler.is_running:
        return jsonify({"error": "Crawler not running"}), 400
    
    # Use cached messages if available, only scrape if empty
    if not crawler.messages:
        print(f"🚨 [API] CACHE MISS - calling scrape_messages()")
        messages = crawler.scrape_messages()
        print(f"🚨 [API] scrape_messages() returned {len(messages)} messages")
    else:
        print(f"🚨 [API] CACHE HIT - using cached {len(crawler.messages)} messages")
        messages = crawler.messages
    
    # Enhance messages with parsing information
    enhanced_messages = []
    for message in messages:
        # Extract company name if present
        company = parser.to_canonical_company(message['content'])
        if company:
            message['company_name'] = company
        
        # Extract order items if it's an order message
        if message['message_type'] == 'order':
            items = parser.extract_order_items(message['content'])
            instructions = parser.extract_instructions(message['content'])
            message['parsed_items'] = items
            message['instructions'] = '\n'.join(instructions) if instructions else ""
        
        enhanced_messages.append(message)
    
    print(f"[PY][API]/messages -> count={len(enhanced_messages)}")
    return jsonify(enhanced_messages)

@whatsapp_bp.route('/api/messages/refresh', methods=['POST'])
def refresh_messages():
    """Manually refresh messages with enhanced parsing"""
    print(f"🚨 [API] /api/messages/refresh called - FORCE REFRESH")
    
    if not crawler.driver or not crawler.is_running:
        return jsonify({"error": "Crawler not running"}), 400
    
    print(f"🚨 [API] REFRESH - calling scrape_messages()")
    messages = crawler.scrape_messages()
    print(f"🚨 [API] REFRESH - scrape_messages() returned {len(messages)} messages")
    
    # Enhance messages with parsing information
    enhanced_messages = []
    for message in messages:
        # Extract company name if present
        company = parser.to_canonical_company(message['content'])
        if company:
            message['company_name'] = company
        
        # Extract order items if it's an order message
        if message['message_type'] == 'order':
            items = parser.extract_order_items(message['content'])
            instructions = parser.extract_instructions(message['content'])
            message['parsed_items'] = items
            message['instructions'] = '\n'.join(instructions) if instructions else ""
        
        enhanced_messages.append(message)
    
    print(f"[PY][API]/messages/refresh -> count={len(enhanced_messages)}")
    return jsonify({
        "status": "success",
        "message_count": len(enhanced_messages),
        "messages": enhanced_messages
    })


@whatsapp_bp.route('/api/debug/analyze', methods=['GET'])
def analyze_page():
    """Analyze current WhatsApp DOM for selector diagnostics (read-only)."""
    if not crawler.driver:
        return jsonify({"error": "Driver not initialized"}), 400

    analysis = {}
    selectors = {
        'sidebar_search_input_xpath': "//div[@id='side']//div[@role='textbox' and @aria-label='Search input textbox']",
        'chat_title_xpath': f"//div[@id='pane-side']//span[@title='{os.environ.get('TARGET_GROUP_NAME', '')}']",
        'header_title_xpath': f"//header//*[normalize-space()='{os.environ.get('TARGET_GROUP_NAME', '')}']",
        'rows_in_main': '#main [role="row"]',
        'copyable_text': '.copyable-text',
        'secondary_text': 'div._akbu ._ao3e.selectable-text',
        'fallback_text': 'span._ao3e.selectable-text, span.x1lliihq',
        'voice_buttons': "button[aria-label='Play voice message'], [aria-label='Voice message']",
        'open_picture_imgs': "[aria-label='Open picture'] img[src]"
    }

    # Count matches
    for key, sel in selectors.items():
        if sel.startswith('//'):
            count = len(crawler.driver.find_elements(By.XPATH, sel))
        else:
            count = len(crawler.driver.find_elements(By.CSS_SELECTOR, sel))
        analysis[key] = { 'count': count }

    # Sample first few row previews
    rows = crawler.driver.find_elements(By.CSS_SELECTOR, '#main [role="row"]')
    previews = []
    for i, row in enumerate(rows[:5]):
        text_nodes = row.find_elements(By.CSS_SELECTOR, selectors['copyable_text']) or \
                     row.find_elements(By.CSS_SELECTOR, selectors['secondary_text']) or \
                     row.find_elements(By.CSS_SELECTOR, selectors['fallback_text'])
        lines = []
        for n in text_nodes:
            t = (n.text or '').strip()
            if t:
                lines.append(t)
        previews.append({'row': i, 'lines': len(lines), 'preview': '\n'.join(lines)[:120]})

    return jsonify({
        'status': 'ok',
        'analysis': analysis,
        'previews': previews
    })


@whatsapp_bp.route('/api/messages/edit', methods=['POST'])
def edit_message():
    """Edit a message content"""
    data = request.get_json()
    message_id = data.get('message_id')
    edited_content = data.get('edited_content')
    print(f"[PY][EDIT] id={message_id} len={len(edited_content or '')}")
    # Find and update message
    for message in crawler.messages:
        if message['id'] == message_id:
            message['original_content'] = message['content']
            message['content'] = edited_content
            message['edited'] = True
            message['edited_at'] = datetime.now().isoformat()
            message['type'] = crawler.classify_message(edited_content)
            
            return jsonify({
                "status": "success",
                "message": message
            })
    
    return jsonify({"error": "Message not found"}), 404

@whatsapp_bp.route('/api/messages/process', methods=['POST'])
def process_messages():
    """Process selected messages"""
    data = request.get_json()
    message_ids = data.get('message_ids', [])
    
    processed = []
    stock_updates = []
    orders = []
    
    for msg_id in message_ids:
        message = next((m for m in crawler.messages if m['id'] == msg_id), None)
        if not message:
            continue
        
        if message['type'] == 'stock_update':
            stock_updates.append({
                "id": f"stock_{len(stock_updates)}",
                "message": message,
                "items": extract_stock_items(message['content']),
                "processed_at": datetime.now().isoformat()
            })
        elif message['type'] == 'order':
            orders.append({
                "id": f"order_{len(orders)}",
                "message": message,
                "items": extract_order_items(message['content']),
                "processed_at": datetime.now().isoformat()
            })
        
        processed.append(message)
    
    return jsonify({
        "status": "success",
        "processed_count": len(processed),
        "stock_updates": stock_updates,
        "orders": orders
    })

@whatsapp_bp.route('/api/messages/parse-orders', methods=['POST'])
def parse_messages_to_orders():
    """Parse messages into orders with company assignments"""
    try:
        data = request.get_json()
        messages = data.get('messages', [])
        
        if not messages:
            # Use current scraped messages if none provided
            messages = crawler.messages
        
        # Parse messages into orders
        orders = parser.parse_messages_to_orders(messages)
        
        print(f"[PY][PARSE] Parsed {len(messages)} messages into {len(orders)} orders")
        for order in orders:
            print(f"[PY][ORDER] {order['company_name']}: {len(order['items_text'])} items")
        
        return jsonify({
            "status": "success",
            "message_count": len(messages),
            "order_count": len(orders),
            "orders": orders
        })
        
    except Exception as e:
        print(f"❌ Error parsing messages to orders: {e}")
        import traceback
        print(f"Full traceback: {traceback.format_exc()}")
        return jsonify({"error": str(e)}), 500

def extract_stock_items(content):
    """Extract stock items from message content"""
    lines = content.split('\n')
    items = []
    
    for line in lines:
        line = line.strip()
        if any(char.isdigit() for char in line) and len(line) > 3:
            items.append({
                "raw_text": line,
                "product": extract_product_name(line),
                "quantity": extract_quantity(line)
            })
    
    return items

def extract_order_items(content):
    """Extract order items from message content"""
    return extract_stock_items(content)

def extract_product_name(text):
    """Extract product name while preserving packaging information"""
    import re
    
    # Clean the text
    text = text.strip()
    
    # Remove multiplier patterns but keep packaging
    # "2 x 10kg tomatoes" -> "10kg tomatoes"
    text = re.sub(r'^\d+\s*[x×*]\s*', '', text)
    
    # Remove leading quantity + container words but keep packaging sizes
    # "3 bags 5kg potatoes" -> "5kg potatoes"
    # "3 bags potatoes" -> "potatoes"
    text = re.sub(r'^\d+\s+(bags?|boxes?|pcs?|pieces?|pkts?|packets?|heads?|bunches?)\s*', '', text)
    
    # Remove "bags" or "box" that appears after packaging size
    # "10kg bags red onions" -> "10kg red onions"
    text = re.sub(r'(\d+\s*(kg|g|ml|l))\s+(bags?|boxes?)\s*', r'\1 ', text)
    
    # Remove standalone quantity at start if followed by space
    # "5 tomatoes" -> "tomatoes" (but keep "5kg tomatoes")
    text = re.sub(r'^\d+\s+(?!\d*(kg|g|ml|l|box|bag))', '', text)
    
    # Clean up extra spaces
    text = re.sub(r'\s+', ' ', text).strip()
    
    return text

def extract_quantity(text):
    """Extract quantity from text - understanding multipliers vs packaging"""
    import re
    
    # Clean the text
    text = text.strip().lower()
    
    # Pattern 1: "2 x 10kg" - multiplier pattern
    multiplier_match = re.search(r'^(\d+)\s*[x×*]\s*\d+\s*(kg|box|bags?|pcs?|pieces?|pkts?|packets?|heads?|bunches?)', text)
    if multiplier_match:
        return multiplier_match.group(1)
    
    # Pattern 2: "3 bags", "5 boxes" - quantity + container
    container_match = re.search(r'^(\d+)\s+(bags?|boxes?|pcs?|pieces?|pkts?|packets?|heads?|bunches?)', text)
    if container_match:
        return container_match.group(1)
    
    # Pattern 3: "2 x" at start - multiplier without packaging
    simple_multiplier = re.search(r'^(\d+)\s*[x×*]', text)
    if simple_multiplier:
        return simple_multiplier.group(1)
    
    # Pattern 3b: "x12" at end - multiplier at end
    end_multiplier = re.search(r'\s+[x×*](\d+)$', text)
    if end_multiplier:
        return end_multiplier.group(1)
    
    # Pattern 4: Just packaging size like "5kg tomatoes" - quantity is 1
    packaging_only = re.search(r'^\d+\s*(kg|g|ml|l)\s+\w+', text)
    if packaging_only:
        return "1"
    
    # Pattern 5: Leading number that's clearly a quantity
    leading_number = re.search(r'^(\d+)\s+', text)
    if leading_number:
        return leading_number.group(1)
    
    # Default: assume quantity is 1
    return "1"
