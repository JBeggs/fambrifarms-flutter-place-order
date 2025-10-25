import os
import re
import time
import json
import hashlib
from datetime import datetime, timezone, timedelta
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager
import subprocess

class WhatsAppCrawler:
    def __init__(self):
        self.driver = None
        self.is_running = False
        self.messages = []
        self.session_dir = None
        self.dom_snapshots = []  # Track DOM changes
        
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
        print("🚀 Starting Chrome browser...")
        self.driver = webdriver.Chrome(options=chrome_options)
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
            
            # Use environment variable with fallback
            target_group = os.environ.get('TARGET_GROUP_NAME', 'ORDERS Restaurants')
            print(f"🎯 Target group: {target_group}")
            
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

        # Focus the sidebar search input and type the group name
        search_input = WebDriverWait(self.driver, 10).until(
            EC.element_to_be_clickable((By.XPATH, "//div[@id='side']//div[@role='textbox' and @aria-label='Search input textbox']"))
        )
        search_input.click()
        search_input.clear()
        search_input.send_keys(group_name)
        time.sleep(2)

        # Select the chat by title within the chat list
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
                (By.XPATH, f"//header//*[normalize-space()='{group_name}']")
            )
        )
        time.sleep(1)

    def get_dom_snapshot(self):
        """Get a snapshot of the current DOM state for change detection"""
        try:
            message_elements = self.driver.find_elements(By.CSS_SELECTOR, '#main [role="row"]')
            snapshot = {
                'timestamp': time.time(),
                'message_count': len(message_elements),
                'message_ids': []
            }
            
            for elem in message_elements[:10]:  # Sample first 10 for performance
                data_id_nodes = elem.find_elements(By.CSS_SELECTOR, '[data-id]')
                if data_id_nodes:
                    msg_id = data_id_nodes[0].get_attribute('data-id')
                    if msg_id:
                        snapshot['message_ids'].append(msg_id)
            
            # Create a hash of the current state
            state_string = f"{snapshot['message_count']}:{':'.join(snapshot['message_ids'][:5])}"
            snapshot['hash'] = hashlib.md5(state_string.encode()).hexdigest()
            
            return snapshot
        except Exception as e:
            print(f"⚠️ Error getting DOM snapshot: {e}")
            return None

    def is_message_in_date_range(self, timestamp_str):
        """Check if message timestamp is within current day or previous day"""
        try:
            # Parse the timestamp
            if isinstance(timestamp_str, str):
                msg_datetime = datetime.fromisoformat(timestamp_str.replace('Z', '+00:00'))
            else:
                return False
            
            # Get current date and previous date (in UTC)
            now = datetime.now(timezone.utc)
            current_date = now.date()
            previous_date = (now - timedelta(days=1)).date()
            
            # Get message date
            msg_date = msg_datetime.date()
            
            # Check if message is from current day or previous day
            is_in_range = msg_date == current_date or msg_date == previous_date
            
            if not is_in_range:
                print(f"📅 [DATE_FILTER] Skipping message from {msg_date} (current: {current_date}, previous: {previous_date})")
            
            return is_in_range
            
        except Exception as e:
            print(f"⚠️ Error checking message date range: {e}")
            # If we can't parse the date, include the message to be safe
            return True
    
    def scrape_messages(self):
        """Scrape messages from WhatsApp - ONLY current day and previous day"""
        print("🚨🚨🚨 [SCRAPER] scrape_messages() CALLED - STARTING SCRAPE")
        print(f"🚨 [SCRAPER] Current self.messages length: {len(self.messages)}")
        print("🔍 Starting message scraping...")
        
        # Calculate date range
        now = datetime.now(timezone.utc)
        current_date = now.date()
        previous_date = (now - timedelta(days=1)).date()
        print(f"📅 [DATE_RANGE] Collecting messages from {previous_date} and {current_date}")
        
        # Try to ensure we're in the target group
        target_group = os.environ.get('TARGET_GROUP_NAME', 'ORDERS Restaurants')
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
        
        # Scroll to load messages with DOM change detection and capture during scroll
        print("📜 Scrolling to load messages...")
        messages_captured_during_scroll = self._scroll_and_capture_messages()
        
        # Get message elements strictly from the open chat area
        message_elements = self.driver.find_elements(By.CSS_SELECTOR, '#main [role="row"]')
        print(f"🔍 Found {len(message_elements)} messages in #main after scrolling")
        
        if len(message_elements) == 0:
            raise Exception("No messages found in open chat")

        self.messages = []
        messages = self.messages
        seen_ids = set()
        messages_in_date_range = 0
        messages_filtered_out = 0
        
        print(f"📋 Processing messages with date filtering...")
        
        for msg_index, msg_elem in enumerate(message_elements):
            # Deduplicate based on WhatsApp's stable data-id when present
            data_id_nodes = msg_elem.find_elements(By.CSS_SELECTOR, '[data-id]')
            row_id = data_id_nodes[0].get_attribute('data-id') if data_id_nodes else None
            if row_id and row_id in seen_ids:
                print(f"🚨 [SKIP] Duplicate message at position {msg_index}: ID={row_id}")
                continue
            if row_id:
                seen_ids.add(row_id)

            # Extract message content with improved media handling
            message_data = self._extract_message_content(msg_elem, msg_index)
            if not message_data:
                continue

            # DATE FILTER: Only include messages from current day or previous day
            if not self.is_message_in_date_range(message_data['timestamp']):
                messages_filtered_out += 1
                continue

            # Verify message integrity
            if self._verify_message_integrity(message_data):
                messages.append(message_data)
                messages_in_date_range += 1
                print(f"📝 ✅ Verified message from {message_data['sender']}: type={message_data['message_type']}, media={message_data['media_type']}")
            else:
                print(f"❌ Failed verification for message {msg_index}")

        self.messages = messages
        print(f"🚨 [SCRAPER] FINISHED - Setting self.messages to {len(messages)} messages")
        print(f"📊 [DATE_FILTER] Messages in range: {messages_in_date_range}, Filtered out: {messages_filtered_out}")
        print(f"[PY][SCRAPE] total_messages={len(messages)}")
        return messages

    def _extract_message_content(self, msg_elem, msg_index):
        """Extract content from a message element with improved media handling"""
        try:
            # Initialize message data
            message_text = ""
            media_type = ""
            media_url = None
            media_info = ""
            voice_duration = None
            
            # STEP 1: Extract text content
            message_text = self._extract_text_content(msg_elem, msg_index)
            
            # STEP 2: Detect and extract media content
            media_data = self._extract_media_content(msg_elem, msg_index)
            media_type = media_data['type']
            media_url = media_data['url']
            media_info = media_data['info']
            voice_duration = media_data.get('duration')
            
            # STEP 3: Extract timestamp
            timestamp_data = self._extract_timestamp(msg_elem, msg_index)
            
            # STEP 4: Classify message
            effective_media_type = media_type if media_type else "text"
            classified_type = self.classify_message(message_text, effective_media_type)
            
            # Skip if no content
            if not message_text and not media_type:
                print(f"[DEBUG] Row {msg_index}: skipped (no text and no media)")
                return None
            
            # Create message object
            message = {
                "id": msg_elem.find_elements(By.CSS_SELECTOR, '[data-id]')[0].get_attribute('data-id') if msg_elem.find_elements(By.CSS_SELECTOR, '[data-id]') else f"msg_{msg_index}_{int(time.time())}",
                "chat": os.environ.get('TARGET_GROUP_NAME', 'ORDERS Restaurants'),
                "sender": "Group Member",  # WhatsApp Web doesn't show individual senders in groups
                "content": message_text,
                "cleanedContent": message_text,
                "timestamp": timestamp_data['timestamp'],
                "scraped_at": datetime.now().isoformat(),
                "message_type": classified_type,
                "items": [],
                "instructions": "",
                "media_type": media_type,
                "media_url": media_url,
                "media_info": media_info,
                "mediaInfo": media_info,
                "company_name": "",
                "parsed_items": [],
                "timestamp_source": timestamp_data['source'],
                "verification_hash": self._generate_message_hash(message_text, media_type, timestamp_data['timestamp'])
            }
            
            return message
            
        except Exception as e:
            print(f"❌ Error extracting message {msg_index}: {e}")
            return None

    def _extract_text_content(self, msg_elem, msg_index):
        """Extract text content with improved truncation handling"""
        message_lines = []
        message_was_expanded = False
        
        # Try multiple selectors for text content
        selectors = ['.copyable-text', 'div._akbu ._ao3e.selectable-text', 'span._ao3e.selectable-text, span.x1lliihq']
        text_elems = []
        
        for selector in selectors:
            text_elems = msg_elem.find_elements(By.CSS_SELECTOR, selector)
            if text_elems:
                break
        
        for elem in text_elems:
            if message_was_expanded:
                break
                
            txt = elem.get_attribute('textContent') or elem.text or ''
            txt = txt.strip()
            
            if not txt:
                continue
            
            # Handle truncated text
            if '…' in txt or '...' in txt:
                print(f"🔍 [TRUNCATE] Detected truncated text in message {msg_index}")
                expanded_text = self._expand_truncated_message(msg_elem, txt)
                if expanded_text:
                    message_lines = expanded_text.split('\n')
                    message_was_expanded = True
                    print(f"✅ [EXPAND] Successfully expanded message {msg_index}")
                    break
                else:
                    print(f"⚠️ [EXPAND] Failed to expand message {msg_index}, using truncated text")
            
            # Skip time badges and clean timestamp contamination
            if re.match(r'^\d{1,2}:\d{2}$', txt):
                continue
            
            # CRITICAL FIX: Clean timestamp contamination from text content
            cleaned_txt = self._clean_timestamp_contamination(txt)
            
            if not message_was_expanded and cleaned_txt:
                message_lines.append(cleaned_txt)
        
        return '\n'.join(message_lines) if message_lines else ""

    def _clean_timestamp_contamination(self, text):
        """Clean timestamp contamination from message text"""
        if not text:
            return text
        
        # Pattern 1: "CompanyName08:30" -> "CompanyName" (no space before timestamp)
        cleaned = re.sub(r'([a-zA-Z])\d{1,2}:\d{2}$', r'\1', text).strip()
        
        # Pattern 2: "Company Name 08:30" -> "Company Name" (space before timestamp)
        cleaned = re.sub(r'\s+\d{1,2}:\d{2}$', '', cleaned).strip()
        
        # Pattern 3: Standalone timestamps at end "08:30"
        cleaned = re.sub(r'^\d{1,2}:\d{2}$|(?<=\s)\d{1,2}:\d{2}$', '', cleaned).strip()
        
        # Pattern 4: Any remaining timestamp patterns at end
        cleaned = re.sub(r'\d{1,2}:\d{2}$', '', cleaned).strip()
        
        # Pattern 5: Handle multiline - clean each line
        if '\n' in cleaned:
            lines = cleaned.split('\n')
            clean_lines = []
            for line in lines:
                line = line.strip()
                # Remove timestamp from end of each line
                line = re.sub(r'\s*\d{1,2}:\d{2}\s*$', '', line)
                if line:  # Only keep non-empty lines
                    clean_lines.append(line)
            cleaned = '\n'.join(clean_lines)
        
        return cleaned

    def _expand_truncated_message(self, msg_elem, truncated_text):
        """Expand truncated messages by clicking Read more button"""
        try:
            # Look for expand buttons
            expand_buttons = msg_elem.find_elements(By.CSS_SELECTOR, 'div[role="button"]')
            if not expand_buttons:
                expand_buttons = msg_elem.find_elements(By.CSS_SELECTOR, '.read-more-button')
            
            # Find the actual expand button
            actual_expand_button = None
            for btn in expand_buttons:
                btn_text = btn.text.strip().lower()
                if 'read more' in btn_text or 'more' in btn_text or btn_text == '':
                    actual_expand_button = btn
                    break
            
            if actual_expand_button:
                print(f"🔍 [EXPAND] Found expand button, clicking...")
                self.driver.execute_script("arguments[0].click();", actual_expand_button)
                time.sleep(2.0)
                
                # Re-extract text after expansion
                copyable_text_elem = msg_elem.find_element(By.CSS_SELECTOR, '.copyable-text')
                if copyable_text_elem:
                    expanded_text = copyable_text_elem.get_attribute('textContent') or copyable_text_elem.text or ''
                    return expanded_text.strip()
            
            return None
            
        except Exception as e:
            print(f"❌ [EXPAND] Expansion failed: {e}")
            return None

    def _extract_media_content(self, msg_elem, msg_index):
        """Extract media content (voice, image, video) with improved detection"""
        media_data = {
            'type': '',
            'url': None,
            'info': '',
            'duration': None
        }
        
        try:
            # VOICE MESSAGE DETECTION
            voice_selectors = [
                "button[aria-label='Play voice message']",
                "[aria-label='Voice message']",
                "button[data-testid='audio-play']",
                ".audio-play-button"
            ]
            
            voice_detected = False
            for selector in voice_selectors:
                voice_nodes = msg_elem.find_elements(By.CSS_SELECTOR, selector)
                if voice_nodes:
                    voice_detected = True
                    print(f"🎵 [VOICE] Detected voice message in row {msg_index} using selector: {selector}")
                    break
            
            if voice_detected:
                media_data['type'] = 'voice'
                
                # Extract voice duration
                duration = self._extract_voice_duration(msg_elem)
                if duration:
                    media_data['duration'] = duration
                    media_data['info'] = duration
                    print(f"🎵 [VOICE] Duration: {duration}")
                
                return media_data
            
            # IMAGE DETECTION
            image_selectors = [
                "[aria-label='Open picture'] img[src]",
                "img[src*='blob:']",
                "img[src*='https://']",
                ".image-thumb img"
            ]
            
            image_url = None
            for selector in image_selectors:
                image_nodes = msg_elem.find_elements(By.CSS_SELECTOR, selector)
                for img in image_nodes:
                    src = img.get_attribute('src') or ''
                    if src and (src.startswith('http') or src.startswith('blob:')):
                        image_url = src
                        print(f"🖼️ [IMAGE] Detected image in row {msg_index}: {src[:50]}...")
                        break
                if image_url:
                    break
            
            if image_url:
                media_data['type'] = 'image'
                media_data['url'] = image_url
                
                # Try to extract image info (dimensions, alt text, etc.)
                try:
                    img_elem = msg_elem.find_element(By.CSS_SELECTOR, f"img[src='{image_url}']")
                    alt_text = img_elem.get_attribute('alt') or ''
                    width = img_elem.get_attribute('width') or ''
                    height = img_elem.get_attribute('height') or ''
                    if alt_text or width or height:
                        media_data['info'] = f"alt:{alt_text} size:{width}x{height}".strip()
                except:
                    pass
                
                return media_data
            
            # VIDEO DETECTION
            video_selectors = [
                "video[src]",
                "[aria-label='Play video']",
                "button[data-testid='video-play']"
            ]
            
            video_detected = False
            video_url = None
            for selector in video_selectors:
                video_nodes = msg_elem.find_elements(By.CSS_SELECTOR, selector)
                if video_nodes:
                    video_detected = True
                    # Try to get video source
                    for video in video_nodes:
                        src = video.get_attribute('src') or ''
                        if src:
                            video_url = src
                            break
                    print(f"🎥 [VIDEO] Detected video in row {msg_index}")
                    break
            
            if video_detected:
                media_data['type'] = 'video'
                if video_url:
                    media_data['url'] = video_url
                return media_data
            
        except Exception as e:
            print(f"⚠️ [MEDIA] Error extracting media from row {msg_index}: {e}")
        
        return media_data

    def _extract_voice_duration(self, msg_elem):
        """Extract voice message duration"""
        try:
            # Try slider aria-valuetext
            sliders = msg_elem.find_elements(By.CSS_SELECTOR, "[role='slider']")
            for slider in sliders:
                aria = (slider.get_attribute('aria-valuetext') or '').strip()
                if '/' in aria:
                    duration = aria.split('/')[-1].strip()
                    if ':' in duration:
                        return duration
            
            # Try visible time text
            time_candidates = msg_elem.find_elements(By.XPATH, ".//*[contains(text(), ':')]")
            for elem in time_candidates:
                text = (elem.text or '').strip()
                if text and 1 <= text.count(':') <= 2 and 3 <= len(text) <= 8:
                    # Validate it looks like a duration (mm:ss or h:mm:ss)
                    if re.match(r'^\d{1,2}:\d{2}(:\d{2})?$', text):
                        return text
            
        except Exception as e:
            print(f"⚠️ Error extracting voice duration: {e}")
        
        return None

    def _extract_timestamp(self, msg_elem, msg_index):
        """Extract timestamp with improved accuracy"""
        timestamp = None
        ts_source = 'unknown'
        
        try:
            # Method 1: data-pre-plain-text attribute
            pre_nodes = msg_elem.find_elements(By.CSS_SELECTOR, '.copyable-text')
            for j, pn in enumerate(pre_nodes):
                pre = pn.get_attribute('data-pre-plain-text') or ''
                if pre.startswith('[') and ']' in pre:
                    try:
                        inside = pre[1:pre.index(']')].strip()
                        parts = [p.strip() for p in inside.split(',')]
                        if len(parts) == 2 and ':' in parts[0] and '/' in parts[1]:
                            # Try both date formats (MM/DD/YYYY and DD/MM/YYYY)
                            date_str = parts[1]
                            time_str = parts[0]
                            dt = None
                            
                            # Try MM/DD/YYYY first (American format)
                            try:
                                dt = datetime.strptime(f"{date_str} {time_str}", "%m/%d/%Y %H:%M")
                            except ValueError:
                                # Try DD/MM/YYYY (European format)
                                try:
                                    dt = datetime.strptime(f"{date_str} {time_str}", "%d/%m/%Y %H:%M")
                                except ValueError:
                                    pass
                            
                            if dt:
                                timestamp = dt.replace(tzinfo=timezone.utc).isoformat()
                                ts_source = 'pre_plain'
                                break
                    except Exception as e:
                        print(f"⚠️ Error parsing timestamp from pre-plain-text: {e}")
                        continue
            
            # Method 2: Visible time spans
            if not timestamp:
                time_elems = msg_elem.find_elements(By.CSS_SELECTOR, 'span.x1c4vz4f.x2lah0s')
                for elem in time_elems:
                    time_text = (elem.text or '').strip()
                    if time_text and ':' in time_text and re.match(r'^\d{1,2}:\d{2}$', time_text):
                        today = datetime.now().strftime("%d/%m/%Y")
                        full_datetime_str = f"{today} {time_text}"
                        try:
                            parsed_datetime = datetime.strptime(full_datetime_str, "%d/%m/%Y %H:%M")
                            timestamp = parsed_datetime.replace(tzinfo=timezone.utc).isoformat()
                            ts_source = 'span_time_today'
                            break
                        except Exception:
                            continue
            
            # Method 3: Fallback to processing time
            if not timestamp:
                timestamp = datetime.now(timezone.utc).isoformat()
                ts_source = 'processing_time_fallback'
                print(f"⚠️ Using fallback timestamp for message {msg_index}")
            
        except Exception as e:
            print(f"❌ Error extracting timestamp from message {msg_index}: {e}")
            timestamp = datetime.now(timezone.utc).isoformat()
            ts_source = 'error_fallback'
        
        return {
            'timestamp': timestamp,
            'source': ts_source
        }

    def _generate_message_hash(self, content, media_type, timestamp):
        """Generate a hash for message verification"""
        hash_string = f"{content[:100]}:{media_type}:{timestamp}"
        return hashlib.md5(hash_string.encode()).hexdigest()

    def _verify_message_integrity(self, message_data):
        """Verify message integrity"""
        try:
            # Basic checks
            if not message_data.get('id'):
                print("❌ Verification failed: No message ID")
                return False
            
            if not message_data.get('content') and not message_data.get('media_type'):
                print("❌ Verification failed: No content or media")
                return False
            
            if not message_data.get('timestamp'):
                print("❌ Verification failed: No timestamp")
                return False
            
            # Verify hash
            expected_hash = self._generate_message_hash(
                message_data.get('content', ''),
                message_data.get('media_type', ''),
                message_data.get('timestamp', '')
            )
            
            if message_data.get('verification_hash') != expected_hash:
                print("❌ Verification failed: Hash mismatch")
                return False
            
            return True
            
        except Exception as e:
            print(f"❌ Verification error: {e}")
            return False
    
    def _scroll_and_capture_messages(self):
        """Scroll up and capture messages during scrolling - stop when we hit messages older than 2 days"""
        print("📜 Starting scroll with date-aware stopping...")
        
        # Calculate cutoff date (2 days ago to ensure we get all of yesterday)
        cutoff_date = (datetime.now(timezone.utc) - timedelta(days=2)).date()
        print(f"📅 [SCROLL] Will stop when reaching messages older than {cutoff_date}")
        
        # Find scrollable container
        scrollable_container = self._find_scrollable_container()
        
        previous_message_count = 0
        scroll_attempts = 0
        max_scrolls = 200
        stable_count = 0
        messages_captured = []
        seen_message_ids = set()
        should_stop_scrolling = False
        
        while scroll_attempts < max_scrolls and not should_stop_scrolling:
            # Get current message count
            current_messages = self.driver.find_elements(By.CSS_SELECTOR, '#main [role="row"]')
            current_count = len(current_messages)
            
            print(f"📊 Scroll {scroll_attempts + 1}: {current_count} messages")
            
            # Check if we've hit the date cutoff by examining oldest visible message
            if scroll_attempts > 0 and current_count > 0:
                # Check the first few messages (oldest) for their dates
                for i in range(min(5, len(current_messages))):
                    try:
                        msg_elem = current_messages[i]
                        pre_nodes = msg_elem.find_elements(By.CSS_SELECTOR, '.copyable-text')
                        for pn in pre_nodes:
                            pre = pn.get_attribute('data-pre-plain-text') or ''
                            if pre.startswith('[') and ']' in pre:
                                inside = pre[1:pre.index(']')].strip()
                                parts = [p.strip() for p in inside.split(',')]
                                if len(parts) == 2 and '/' in parts[1]:
                                    # Parse date
                                    dt = datetime.strptime(parts[1], "%d/%m/%Y")
                                    msg_date = dt.date()
                                    if msg_date < cutoff_date:
                                        print(f"📅 [SCROLL] Found message from {msg_date} which is older than cutoff {cutoff_date}")
                                        print(f"🛑 [SCROLL] Stopping scroll - reached date limit")
                                        should_stop_scrolling = True
                                        break
                    except Exception as e:
                        continue
                    if should_stop_scrolling:
                        break
            
            if should_stop_scrolling:
                break
            
            # If no new messages loaded, increment stable counter
            if current_count == previous_message_count:
                stable_count += 1
                print(f"🔄 No new messages loaded (stable count: {stable_count})")
                if stable_count >= 20:
                    print("🔝 Reached top of chat - no more messages to load")
                    break
            else:
                stable_count = 0
                print(f"✅ New messages loaded: {previous_message_count} → {current_count}")
            
            previous_message_count = current_count
            
            # Scroll to top
            self.driver.execute_script("arguments[0].scrollTop = 0", scrollable_container)
            
            # Every 10th scroll, add Ctrl+Home for aggressive scroll
            if scroll_attempts % 10 == 0:
                try:
                    scrollable_container.send_keys(Keys.CONTROL + Keys.HOME)
                    print(f"🔼 Used Ctrl+Home for aggressive scroll (attempt {scroll_attempts + 1})")
                except:
                    pass
            
            # Wait for messages to load
            time.sleep(6)
            
            # Capture new messages that appeared after this scroll
            self._capture_new_messages(messages_captured, seen_message_ids, scroll_attempts + 1)
            
            scroll_attempts += 1
        
        final_count = len(self.driver.find_elements(By.CSS_SELECTOR, '#main [role="row"]'))
        print(f"✅ Finished scrolling. Total messages loaded: {final_count}")
        print(f"📋 Captured {len(messages_captured)} unique messages during scrolling")
        
        # Save captured messages
        self._save_captured_messages(messages_captured)
        
        return messages_captured

    def _find_scrollable_container(self):
        """Find the scrollable container in the chat"""
        # Find all potential scrollable containers in #main
        potential_containers = self.driver.find_elements(By.CSS_SELECTOR, '#main *')
        scrollable_container = None
        
        print(f"🔍 Checking {len(potential_containers)} potential containers for scrollability...")
        
        for i, container in enumerate(potential_containers):
            try:
                scroll_height = self.driver.execute_script("return arguments[0].scrollHeight", container)
                client_height = self.driver.execute_script("return arguments[0].clientHeight", container)
                tag_name = container.tag_name
                class_name = container.get_attribute('class') or ''
                
                # Find container where scrollHeight > clientHeight (has scrollable content)
                if scroll_height > client_height and scroll_height > 100:
                    scrollable_container = container
                    print(f"✅ Found scrollable container: {tag_name}.{class_name[:30]} (scrollHeight={scroll_height}, clientHeight={client_height})")
                    break
            except Exception as e:
                continue
        
        if not scrollable_container:
            print("❌ No scrollable container found, using #main as fallback")
            scrollable_container = self.driver.find_element(By.CSS_SELECTOR, '#main')
        
        return scrollable_container

    def _capture_new_messages(self, messages_captured, seen_message_ids, scroll_attempt):
        """Capture new messages that appeared after scrolling"""
        try:
            current_message_elements = self.driver.find_elements(By.CSS_SELECTOR, '#main [role="row"]')
            new_messages_count = 0
            
            for msg_elem in current_message_elements:
                try:
                    # Get unique identifier
                    data_id_nodes = msg_elem.find_elements(By.CSS_SELECTOR, '[data-id]')
                    if not data_id_nodes:
                        continue
                        
                    msg_id = data_id_nodes[0].get_attribute('data-id')
                    if not msg_id or msg_id in seen_message_ids:
                        continue
                    
                    # Extract basic message info
                    text_elems = msg_elem.find_elements(By.CSS_SELECTOR, '.copyable-text')
                    if not text_elems:
                        continue
                    
                    message_text = text_elems[0].get_attribute('textContent') or text_elems[0].text or ''
                    if not message_text.strip():
                        continue
                    
                    # Extract timestamp
                    timestamp = ''
                    for elem in text_elems:
                        pre_text = elem.get_attribute('data-pre-plain-text') or ''
                        if pre_text.startswith('[') and ']' in pre_text:
                            timestamp = pre_text[1:pre_text.index(']')].strip()
                            break
                    
                    # Handle truncated messages
                    if '…' in message_text or '...' in message_text:
                        expanded_text = self._expand_truncated_message(msg_elem, message_text)
                        if expanded_text:
                            message_text = expanded_text
                    
                    # Store message
                    messages_captured.append({
                        'id': msg_id,
                        'text': message_text,
                        'timestamp': timestamp,
                        'html': msg_elem.get_attribute('outerHTML'),
                        'scroll_attempt': scroll_attempt
                    })
                    
                    seen_message_ids.add(msg_id)
                    new_messages_count += 1
                    
                except Exception as e:
                    print(f"⚠️ Error capturing message: {e}")
                    continue
            
            if new_messages_count > 0:
                print(f"    📝 Captured {new_messages_count} new messages in scroll {scroll_attempt}")
                
        except Exception as e:
            print(f"❌ Error in _capture_new_messages: {e}")

    def _save_captured_messages(self, messages_captured):
        """Save captured messages to JSON file"""
        if not messages_captured:
            return
        
        try:
            # Sort by timestamp (chronological order)
            def parse_timestamp(ts):
                try:
                    if ts and ', ' in ts:
                        time_part, date_part = ts.split(', ')
                        return datetime.strptime(f"{date_part} {time_part}", "%d/%m/%Y %H:%M")
                    return datetime.min
                except:
                    return datetime.min
            
            messages_captured.sort(key=lambda x: parse_timestamp(x.get('timestamp', '')))
            
            # Save to file
            filename = f'messages_captured_{datetime.now().strftime("%Y%m%d_%H%M%S")}.json'
            with open(filename, 'w', encoding='utf-8') as f:
                json.dump(messages_captured, f, indent=2, ensure_ascii=False)
            
            print(f"💾 Saved {len(messages_captured)} captured messages to {filename}")
            
        except Exception as e:
            print(f"❌ Error saving captured messages: {e}")
    
    def classify_message(self, content, media_type="text"):
        """Classify message with improved stock detection"""
        if media_type == "image":
            return 'image'
        if media_type == "voice":
            return 'voice'
        if media_type == "video":
            return 'video'
        if media_type != "text":
            return 'other'
        
        content_upper = content.upper()
        
        # Order day demarcation indicators
        demarcation_keywords = ['ORDERS STARTS HERE', 'THURSDAY ORDERS', 'TUESDAY ORDERS', 'MONDAY ORDERS']
        if any(keyword in content_upper for keyword in demarcation_keywords):
            return 'demarcation'
        
        # Enhanced stock indicators - including SHALLOME
        stock_keywords = ['STOCK', 'AVAILABLE', 'INVENTORY', 'SUPPLY', 'STOKE', 'SHALLOME']
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
