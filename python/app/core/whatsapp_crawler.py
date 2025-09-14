import os
import re
import time
from datetime import datetime, timezone
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.chrome.service import Service
import subprocess

class WhatsAppCrawler:
    def __init__(self):
        self.driver = None
        self.is_running = False
        self.messages = []
        self.session_dir = None
        
    def cleanup_existing_sessions(self):
        """Kill any existing Chrome processes using our session directory"""
        session_dir = os.path.abspath("./whatsapp-session")
        result = subprocess.run(['pkill', '-f', f'user-data-dir={session_dir}'], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            print("🧹 Killed existing Chrome processes")
            time.sleep(2)

    def initialize_driver(self):
        """Initialize Chrome WebDriver with WhatsApp session"""
        self.cleanup_existing_sessions()
        chrome_options = Options()
        
        # Basic Chrome options
        chrome_options.add_argument("--no-sandbox")
        chrome_options.add_argument("--disable-dev-shm-usage")
        chrome_options.add_argument("--disable-web-security")
        chrome_options.add_argument("--allow-running-insecure-content")
        
        # Session directory
        self.session_dir = os.path.abspath("./whatsapp-session")
        os.makedirs(self.session_dir, exist_ok=True)
        chrome_options.add_argument(f"--user-data-dir={self.session_dir}")
        print(f"Using session directory: {self.session_dir}")
        
        # Anti-detection options
        chrome_options.add_argument("--disable-blink-features=AutomationControlled")
        chrome_options.add_experimental_option("excludeSwitches", ["enable-automation"])
        chrome_options.add_experimental_option('useAutomationExtension', False)
        
        # Use system ChromeDriver
        print("🔧 Using system ChromeDriver...")
        service = Service()
        print("🚀 Starting Chrome browser...")
        self.driver = webdriver.Chrome(service=service, options=chrome_options)
        self.driver.execute_script("Object.defineProperty(navigator, 'webdriver', {get: () => undefined})")
        print("✅ Chrome WebDriver initialized")
    
    def start_whatsapp(self):
        """Open WhatsApp Web"""
        self.driver.get("https://web.whatsapp.com")
        print("🌐 WhatsApp Web opened")
        
        # Wait for WhatsApp to load
        print("⏳ Waiting for WhatsApp to load...")
        time.sleep(5)
        
        # Check what's on the page
        print(f"🔍 Page title: {self.driver.title}")
        print(f"🔍 Current URL: {self.driver.current_url}")
        
        # Look for WhatsApp elements
        qr_elements = self.driver.find_elements(By.CSS_SELECTOR, '[data-testid="qr-canvas"]')
        print(f"🔍 Found QR elements: {len(qr_elements)}")
        
        # Wait for WhatsApp interface
        WebDriverWait(self.driver, 30).until(
            lambda driver: driver.find_elements(By.CSS_SELECTOR, '#side')
        )
        print("✅ WhatsApp interface loaded")
        
        if self.driver.find_elements(By.CSS_SELECTOR, '[data-testid="qr-canvas"]'):
            print("📱 QR Code displayed - please scan with your phone")
            return {"status": "qr_code", "message": "Please scan QR code with your phone"}
        else:
            print("✅ WhatsApp logged in successfully")
            
            # Get target group from environment - REQUIRED
            target_group = os.environ['TARGET_GROUP_NAME']
            print(f"🎯 Target group from env: {target_group}")
            
            # Select group - fail fast if it doesn't work
            self.find_and_select_group(target_group)
            return {"status": "logged_in", "message": f"WhatsApp ready - {target_group} group selected"}
    
    def find_and_select_group(self, group_name):
        """Find and select a specific WhatsApp group"""
        print(f"🔍 Searching for group: {group_name}")

        # If the header already shows the target group, we're done
        header_match = self.driver.find_elements(
            By.XPATH,
            f"//header//*[normalize-space()='{group_name}']"
        )
        if header_match:
            print(f"✅ Already in group: {group_name}")
            return

        # Focus the sidebar search input and type the group name (from saved HTML)
        # Exact selector: //div[@id='side']//div[@role='textbox' and @aria-label='Search input textbox']
        search_input = WebDriverWait(self.driver, 10).until(
            EC.element_to_be_clickable((By.XPATH, "//div[@id='side']//div[@role='textbox' and @aria-label='Search input textbox']"))
        )
        search_input.click()
        search_input.clear()
        search_input.send_keys(group_name)
        time.sleep(2)

        # Select the chat by title within the chat list (#pane-side)
        group_element = WebDriverWait(self.driver, 15).until(
            EC.element_to_be_clickable(
                (By.XPATH, f"//div[@id='pane-side']//span[@title='{group_name}']")
            )
        )
        group_element.click()
        print(f"✅ Selected group: {group_name}")

        # Confirm the header updates to the selected group
        WebDriverWait(self.driver, 15).until(
            EC.presence_of_element_located(
                (
                    By.XPATH,
                    f"//header//*[normalize-space()='{group_name}']"
                )
            )
        )
        time.sleep(1)

    
    def scrape_messages(self):
        """Scrape messages from WhatsApp"""
        print("🔍 Starting message scraping...")
        
        # Try to ensure we're in the target group
        target_group = os.environ['TARGET_GROUP_NAME']
        print(f"🎯 Looking for group: {target_group}")
        
        self.find_and_select_group(target_group)
        print(f"✅ Successfully selected group: {target_group}")
        
        time.sleep(2)
        return self._scrape_from_open_chat()
    
    def _scrape_from_open_chat(self):
        """Scrape from an open chat conversation"""
        print("🔍 Attempting to scrape from open chat...")
        
        # Check if we have the main chat area
        main_elements = self.driver.find_elements(By.CSS_SELECTOR, "#main")
        if not main_elements:
            raise Exception("No main chat area found")
        
        # Scroll to load all messages
        print("📜 Scrolling to load all messages...")
        self._scroll_to_load_all_messages()
        
        # Get message elements strictly from the open chat area (#main)
        message_elements = self.driver.find_elements(By.CSS_SELECTOR, '#main [role="row"]')
        print(f"🔍 Found {len(message_elements)} messages in #main")
        
        if len(message_elements) == 0:
            raise Exception("No messages found in open chat")

        messages = []
        seen_ids = set()
        for i, msg_elem in enumerate(message_elements):
            # Deduplicate based on WhatsApp's stable data-id when present
            data_id_nodes = msg_elem.find_elements(By.CSS_SELECTOR, '[data-id]')
            row_id = data_id_nodes[0].get_attribute('data-id') if data_id_nodes else None
            if row_id and row_id in seen_ids:
                continue
            if row_id:
                seen_ids.add(row_id)
            # Get sender name - from actual HTML structure (messages don't have sender info visible)
            sender = "Group Member"

            # Extract message content
            message_text = ""
            media_type = ""  # image | voice | video | document | ''
            media_url = None
            media_src = None  # raw src value (not persisted)
            voice_duration = None
            
            # Always extract text first (deterministic, no conditionals)
            # Prefer WhatsApp's copyable-text containers, then common span classes
            sel_primary = '.copyable-text'
            sel_secondary = 'div._akbu ._ao3e.selectable-text'
            sel_fallback = 'span._ao3e.selectable-text, span.x1lliihq'
            text_elems = msg_elem.find_elements(By.CSS_SELECTOR, sel_primary)
            source_selector = sel_primary if text_elems else ''
            if not text_elems:
                text_elems = msg_elem.find_elements(By.CSS_SELECTOR, sel_secondary)
                source_selector = sel_secondary if text_elems else source_selector
            if not text_elems:
                text_elems = msg_elem.find_elements(By.CSS_SELECTOR, sel_fallback)
                source_selector = sel_fallback if text_elems else source_selector
            message_lines = []
            prev_line = None
            for elem in text_elems:
                txt = (elem.text or '').strip()
                if not txt:
                    continue
                # Skip standalone time badges (e.g., 12:46)
                if re.match(r'^\d{1,2}:\d{2}$', txt):
                    continue
                # Remove only consecutive duplicates within the same bubble
                if prev_line is not None and txt == prev_line:
                    continue
                message_lines.append(txt)
                prev_line = txt
            message_text = '\n'.join(message_lines) if message_lines else ""
            print(f"[DEBUG] Row {i}: text_lines={len(message_lines)} selector='{source_selector}' preview='{message_text[:60]}'")
            
            # Independent, deterministic detection (no nested if/else chains)
            # 1) Voice: explicit button aria-labels
            voice_sel = "button[aria-label='Play voice message'], [aria-label='Voice message']"
            voice_nodes = msg_elem.find_elements(By.CSS_SELECTOR, voice_sel)
            voice_detected = bool(voice_nodes)

            # 2) Image: only images inside the media bubble with explicit Open picture container
            image_sel = "[aria-label='Open picture'] img[src]"
            image_nodes = msg_elem.find_elements(By.CSS_SELECTOR, image_sel)
            http_image_nodes = [n for n in image_nodes if (n.get_attribute('src') or '').startswith('http')]
            image_http_src = (http_image_nodes[0].get_attribute('src') or '').strip() if http_image_nodes else None
            print(f"[DEBUG] Row {i}: voice_detected={voice_detected} voice_sel='{voice_sel}' image_http={'yes' if image_http_src else 'no'} image_sel='{image_sel}'")

            # Decide type with clear precedence: voice > image > text
            if voice_detected:
                media_type = "voice"
                # Extract duration deterministically from slider aria-valuetext or visible short time text in the row
                sliders = msg_elem.find_elements(By.CSS_SELECTOR, "[role='slider']")
                for slider in sliders:
                    aria = (slider.get_attribute('aria-valuetext') or '').strip()
                    # Example: "0:00/0:19" → take last part
                    if '/' in aria:
                        last = aria.split('/')[-1].strip()
                        if last and ':' in last:
                            voice_duration = last
                            break
                if not voice_duration:
                    for cand in msg_elem.find_elements(By.XPATH, ".//*[contains(text(), ':')]"):
                        t = (cand.text or '').strip()
                        # Choose short mm:ss patterns only
                        if t and 1 <= t.count(':') <= 2 and 3 <= len(t) <= 5:
                            voice_duration = t
                            break
                print(f"[DEBUG] Row {i}: voice_duration='{voice_duration or ''}'")
            elif image_http_src:
                media_type = "image"
                media_url = image_http_src
            # 3) Text is whatever we extracted above; only override it for media placeholders
            print(f"[DEBUG] Row {i}: media_type_raw={media_type}, media_url='{media_url or ''}'")
            
            # Skip only if there is neither text nor media
            if not message_text and not media_type:
                print(f"[DEBUG] Row {i}: skipped (no text and no media)")
                continue

            # Prefer message's own timestamp from WhatsApp; fallback to visible HH:MM, then processing time
            timestamp = None
            ts_source = 'unknown'
            # 1) data-pre-plain-text: "[12:46, 13/09/2025] Name:"
            pre_nodes = msg_elem.find_elements(By.CSS_SELECTOR, '.copyable-text')
            for pn in pre_nodes:
                pre = pn.get_attribute('data-pre-plain-text') or ''
                if pre.startswith('[') and ']' in pre:
                    try:
                        inside = pre[1:pre.index(']')].strip()
                        parts = [p.strip() for p in inside.split(',')]
                        if len(parts) == 2 and ':' in parts[0] and '/' in parts[1]:
                            dt = datetime.strptime(f"{parts[1]} {parts[0]}", "%d/%m/%Y %H:%M")
                            timestamp = dt.replace(tzinfo=timezone.utc).isoformat()
                            ts_source = 'pre_plain'
                            break
                    except Exception:
                        pass
            # 2) Visible HH:MM (assume today)
            if not timestamp:
                time_elems = msg_elem.find_elements(By.CSS_SELECTOR, 'span.x1c4vz4f.x2lah0s')
                for elem in time_elems:
                    time_text = (elem.text or '').strip()
                    if time_text and ':' in time_text:
                        today = datetime.now().strftime("%d/%m/%Y")
                        full_datetime_str = f"{today} {time_text}"
                        try:
                            parsed_datetime = datetime.strptime(full_datetime_str, "%d/%m/%Y %H:%M")
                            timestamp = parsed_datetime.replace(tzinfo=timezone.utc).isoformat()
                            ts_source = 'span_time_today'
                            break
                        except Exception:
                            continue
            # 3) Processing time
            if not timestamp:
                timestamp = datetime.now(timezone.utc).isoformat()
                ts_source = 'processing_time_fallback'

            # Classify message type for backend (order | stock | instruction | demarcation | other | image | voice)
            # Images require a usable media_url. Voice/text do not.
            if media_type == "image" and not media_url:
                effective_media_type = "text"
            else:
                effective_media_type = media_type if media_type else "text"
            classified_type = self.classify_message(message_text, effective_media_type)
            print(f"[PY][CLASSIFY] row={i} media={effective_media_type} -> {classified_type} text_preview='{message_text[:60]}'")

            # Create message object (align with Django expectations)
            message = {
                "id": row_id or f"msg_{i}_{int(time.time())}",
                "chat": os.environ['TARGET_GROUP_NAME'],
                "sender": sender,
                "content": message_text,
                "cleanedContent": message_text,
                "timestamp": timestamp,
                "scraped_at": datetime.now().isoformat(),
                "message_type": classified_type,
                "items": [],
                "instructions": "",
                "media_type": media_type,
                "media_url": media_url,
                "media_info": (voice_duration or ""),
                "mediaInfo": (voice_duration or ""),
                "company_name": "",  # Will be filled by parser
                "parsed_items": []   # Will be filled by parser
            }

            messages.append(message)
            print(f"📝 Found message from {sender}: type={classified_type}, media_type={media_type}, url={'set' if media_url else 'none'}, ts_source={ts_source}, text='{message_text[:50]}'")

        self.messages = messages
        print(f"[PY][SCRAPE] total_messages={len(messages)}")
        return messages
    
    def _scroll_to_load_all_messages(self):
        """Scroll up in the chat to load all messages"""
        # Single working selector for message container
        containers = self.driver.find_elements(By.CSS_SELECTOR, '#main .copyable-area')
        message_container = containers[0] if containers else None
        
        if not message_container:
            raise Exception("Could not find scrollable message container")
        
        print("📜 Starting scroll to load all messages...")
        previous_message_count = 0
        scroll_attempts = 0
        max_scrolls = 50
        
        while scroll_attempts < max_scrolls:
            # Get current message count within #main only
            current_messages = self.driver.find_elements(By.CSS_SELECTOR, '#main [role="row"]')
            current_count = len(current_messages)
            
            print(f"📊 Scroll {scroll_attempts + 1}: {current_count} messages")
            
            # If no new messages loaded, we've reached the top
            if current_count == previous_message_count and scroll_attempts > 0:
                print("🔝 Reached top of chat - no more messages to load")
                break
            
            previous_message_count = current_count
            
            # Scroll to top of container
            self.driver.execute_script("arguments[0].scrollTop = 0", message_container)
            
            # Wait for messages to load
            time.sleep(4)
            
            scroll_attempts += 1
        
        final_count = len(self.driver.find_elements(By.CSS_SELECTOR, '#main [role="row"]'))
        print(f"✅ Finished scrolling. Total messages loaded: {final_count}")
    
    def classify_message(self, content, media_type="text"):
        """Classify message as order, stock, or other"""
        if media_type == "image":
            return 'image'
        if media_type == "voice":
            return 'voice'
        if media_type != "text":
            return 'other'
        
        content_upper = content.upper()
        
        # Order day demarcation indicators
        demarcation_keywords = ['ORDERS STARTS HERE', 'THURSDAY ORDERS', 'TUESDAY ORDERS', 'MONDAY ORDERS']
        if any(keyword in content_upper for keyword in demarcation_keywords):
            return 'demarcation'
        
        # Stock indicators
        stock_keywords = ['STOCK', 'AVAILABLE', 'INVENTORY', 'SUPPLY', 'STOKE']
        if any(keyword in content_upper for keyword in stock_keywords):
            return 'stock'
        
        # Order indicators
        order_keywords = ['ORDER', 'NEED', 'WANT', 'KG', 'BOXES', 'X1', 'X2', 'X3', 'X4', 'X5']
        quantity_patterns = ['\\d+\\s*KG', '\\d+\\s*X', 'X\\d+']
        
        has_order_keywords = any(keyword in content_upper for keyword in order_keywords)
        has_quantities = any(re.search(pattern, content_upper) for pattern in quantity_patterns)
        
        if has_order_keywords or has_quantities:
            return 'order'
        
        # Instruction indicators
        instruction_keywords = ['GOOD MORNING', 'HELLO', 'HI', 'THANKS', 'PLEASE', 'NOTE']
        if any(keyword in content_upper for keyword in instruction_keywords):
            return 'instruction'
        
        return 'other'
    
    def stop(self):
        """Stop the crawler and close browser"""
        self.is_running = False
        if self.driver:
            self.driver.quit()
            self.driver = None
        print("🛑 WhatsApp crawler stopped")
