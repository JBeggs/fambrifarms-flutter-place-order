import os
import re
import time
import requests
import hashlib
import uuid
from datetime import datetime, timezone
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
import subprocess
from bs4 import BeautifulSoup

class SimplifiedWhatsAppCrawler:
    """
    Simplified WhatsApp crawler that:
    1. Gets messages without excessive scrolling
    2. Handles "read more" expansion
    3. Sends raw HTML to Django backend
    4. Periodically checks for new messages
    """
    
    def __init__(self, django_url="http://localhost:8000"):
        self.driver = None
        self.is_running = False
        self.session_dir = None
        self.django_url = django_url
        self.last_message_count = 0
        
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
        
        try:
            self.driver = webdriver.Chrome(options=chrome_options)
            self.driver.execute_script("Object.defineProperty(navigator, 'webdriver', {get: () => undefined})")
            print("✅ Chrome WebDriver initialized successfully")
            return True
        except Exception as e:
            print(f"❌ Failed to initialize Chrome WebDriver: {e}")
            return False

    def is_logged_in(self):
        """
        Check if user is logged into WhatsApp using multiple detection methods
        Returns True if logged in, False otherwise
        """
        try:
            # Method 1: Check for main chat area
            main_element = self.driver.find_elements(By.CSS_SELECTOR, '#main')
            if main_element:
                print("🔍 Login detection: Found #main element")
                return True
            
            # Method 2: Check for chat list (side panel)
            chat_list = self.driver.find_elements(By.CSS_SELECTOR, '[data-testid="chat-list"]')
            if chat_list:
                print("🔍 Login detection: Found chat list")
                return True
            
            # Method 3: Check for search input (appears when logged in)
            search_input = self.driver.find_elements(By.CSS_SELECTOR, '[data-testid="chat-list-search"]')
            if search_input:
                print("🔍 Login detection: Found search input")
                return True
            
            # Method 4: Check for any chat elements
            chat_elements = self.driver.find_elements(By.CSS_SELECTOR, '[data-testid="conversation-panel-wrapper"]')
            if chat_elements:
                print("🔍 Login detection: Found conversation panel")
                return True
            
            # Method 5: Check if QR code is NOT present (negative indicator)
            qr_elements = self.driver.find_elements(By.CSS_SELECTOR, '[data-testid="qr-code"]')
            if not qr_elements:
                # QR code not present, check for other logged-in indicators
                side_panel = self.driver.find_elements(By.CSS_SELECTOR, '#side')
                if side_panel:
                    print("🔍 Login detection: No QR code + side panel present")
                    return True
            
            print("🔍 Login detection: No login indicators found")
            return False
            
        except Exception as e:
            print(f"🔍 Login detection error: {e}")
            return False

    def debug_page_elements(self):
        """Debug method to see what elements are present on the page"""
        try:
            print("🔍 DEBUG: Checking page elements...")
            
            # Check common WhatsApp elements
            selectors_to_check = [
                '#main',
                '#side', 
                '[data-testid="chat-list"]',
                '[data-testid="chat-list-search"]',
                '[data-testid="qr-code"]',
                '[data-testid="conversation-panel-wrapper"]',
                '.landing-wrapper',
                '._2dloB',  # Common WhatsApp class
                '._3WByx',  # Another common class
            ]
            
            for selector in selectors_to_check:
                elements = self.driver.find_elements(By.CSS_SELECTOR, selector)
                if elements:
                    print(f"✅ Found: {selector} ({len(elements)} elements)")
                else:
                    print(f"❌ Not found: {selector}")
            
            # Check page title
            title = self.driver.title
            print(f"📄 Page title: {title}")
            
            # Check current URL
            url = self.driver.current_url
            print(f"🌐 Current URL: {url}")
            
        except Exception as e:
            print(f"🔍 Debug error: {e}")


    def start_whatsapp_session(self):
        """Start WhatsApp Web session and navigate to target group"""
        if not self.initialize_driver():
            return False
            
        try:
            print("🌐 Navigating to WhatsApp Web...")
            self.driver.get("https://web.whatsapp.com")
            
            # Wait for WhatsApp to load
            print("⏳ Waiting for WhatsApp to load...")
            WebDriverWait(self.driver, 30).until(
                lambda driver: driver.execute_script("return document.readyState") == "complete"
            )
            
            # Wait for WhatsApp Web to actually load content (either QR code or main interface)
            print("⏳ Waiting for WhatsApp Web content to load...")
            try:
                WebDriverWait(self.driver, 30).until(
                    lambda driver: (
                        driver.find_elements(By.CSS_SELECTOR, '[data-testid="qr-code"]') or
                        driver.find_elements(By.CSS_SELECTOR, '#main') or
                        driver.find_elements(By.CSS_SELECTOR, '#side') or
                        driver.find_elements(By.CSS_SELECTOR, '.landing-wrapper')
                    )
                )
                print("✅ WhatsApp Web content loaded")
            except:
                print("⚠️ WhatsApp Web content taking longer than expected to load")
                print("🔍 Checking what's on the page after 30 seconds...")
                self.debug_page_elements()
            
            # Check if already logged in with multiple detection methods
            if self.is_logged_in():
                print("✅ Already logged into WhatsApp")
            else:
                print("📱 Please scan QR code to log into WhatsApp...")
                print("🔍 Running debug to see what elements are present...")
                self.debug_page_elements()
                
                # Wait for login with improved detection
                login_successful = False
                for attempt in range(12):  # 60 seconds total, 5-second intervals
                    time.sleep(5)
                    if self.is_logged_in():
                        print("✅ Successfully logged into WhatsApp")
                        login_successful = True
                        break
                    print(f"⏳ Waiting for login... ({attempt + 1}/12)")
                
                if not login_successful:
                    print("❌ Failed to detect WhatsApp login after 60 seconds")
                    print("🔍 Final debug - checking what's on the page:")
                    self.debug_page_elements()
                    return False
            
            # Navigate to target group
            target_group = os.environ.get('TARGET_GROUP_NAME', 'ORDERS Restaurants')
            if self.select_target_group(target_group):
                self.is_running = True
                print(f"🎯 Successfully connected to group: {target_group}")
                return True
            else:
                print(f"❌ Failed to find group: {target_group}")
                return False
                
        except Exception as e:
            print(f"❌ Error starting WhatsApp session: {e}")
            return False

    def select_target_group(self, group_name):
        """Find and select the target WhatsApp group"""
        try:
            print(f"🔍 Searching for group: {group_name}")
            
            # First check if we're already in the target group by looking at the header
            try:
                header_text = self.driver.find_element(By.CSS_SELECTOR, 'header span._ao3e').text
                if group_name in header_text:
                    print(f"✅ Already in group: {group_name}")
                    return True
            except:
                pass
            
            # Find the search button in the header (based on actual HTML)
            try:
                # Debug: Check what search-related elements are present
                print("🔍 DEBUG: Checking for search elements...")
                search_selectors = [
                    'div[aria-label="Search"]',
                    '[data-testid="search"]', 
                    '[aria-label*="search"]',
                    '[aria-label*="Search"]',
                    'button[aria-label*="Search"]',
                    '.search',
                    '#search'
                ]
                
                for selector in search_selectors:
                    elements = self.driver.find_elements(By.CSS_SELECTOR, selector)
                    if elements:
                        print(f"✅ Found search element: {selector} ({len(elements)} elements)")
                    else:
                        print(f"❌ Not found: {selector}")
                
                # Use working approach from crawler_test - target search input directly
                search_input = WebDriverWait(self.driver, 10).until(
                    EC.element_to_be_clickable((By.XPATH, "//div[@id='side']//div[@role='textbox' and @aria-label='Search input textbox']"))
                )
                print("✅ Found search input")
            except Exception as e:
                print(f"❌ Could not find search input: {e}")
                print("🔍 DEBUG: Page might need more time to load or interface changed")
                return False
            
            # Clear and type in the search input
            try:
                search_input.click()
                search_input.clear()
                search_input.send_keys(group_name)
                print(f"✅ Entered search term: {group_name}")
                time.sleep(2)
            except Exception as e:
                print(f"❌ Could not find search input: {e}")
                return False
            
            # Look for the group in search results using the actual structure
            try:
                # Look for a span with the group name as title attribute
                group_element = WebDriverWait(self.driver, 10).until(
                    EC.element_to_be_clickable((By.CSS_SELECTOR, f'span[title="{group_name}"]'))
                )
                group_element.click()
                print(f"✅ Found and clicked group: {group_name}")
            except:
                # Fallback: look for any element containing the group name
                try:
                    group_element = WebDriverWait(self.driver, 10).until(
                        EC.element_to_be_clickable((By.XPATH, f"//span[contains(text(), '{group_name}')]"))
                    )
                    group_element.click()
                    print(f"✅ Found group by text content: {group_name}")
                except Exception as e:
                    print(f"❌ Could not find group '{group_name}': {e}")
                    return False
            
            # Wait for the chat to load by checking for the main area
            try:
                WebDriverWait(self.driver, 10).until(
                    EC.presence_of_element_located((By.CSS_SELECTOR, '#main'))
                )
                print(f"✅ Chat loaded for group: {group_name}")
                
                # Verify we're in the right group by checking header again
                time.sleep(2)
                header_text = self.driver.find_element(By.CSS_SELECTOR, 'header span._ao3e').text
                if group_name in header_text:
                    print(f"✅ Confirmed in group: {group_name}")
                    return True
                else:
                    print(f"⚠️ Header shows: {header_text}, expected: {group_name}")
                    return False
                    
            except Exception as e:
                print(f"❌ Chat failed to load: {e}")
                return False
            
        except Exception as e:
            print(f"❌ Error selecting group {group_name}: {e}")
            import traceback
            print(f"Full traceback: {traceback.format_exc()}")
            return False

    def get_current_messages(self, scroll_to_load_more=False):
        """
        Get current messages from the chat without excessive scrolling
        
        Args:
            scroll_to_load_more: If True, scroll up a bit to load more recent messages
        """
        try:
            # Find message container first for scrolling
            scroll_container = None
            if scroll_to_load_more:
                print("📜 Scrolling up to load more messages...")
                
                # Find the scrollable container - based on actual HTML it's .copyable-area
                try:
                    scroll_container = self.driver.find_element(By.CSS_SELECTOR, '.copyable-area')
                    print("✅ Found scroll container: .copyable-area")
                    
                    # Scroll up moderately to load more messages
                    for i in range(3):  # Limited scrolling
                        self.driver.execute_script("arguments[0].scrollTop -= 1000", scroll_container)
                        print(f"📜 Scroll {i+1}/3")
                        time.sleep(1)
                        
                except Exception as e:
                    print(f"⚠️ Could not find scroll container: {e} - skipping scroll")
            
            # Get message elements from the actual HTML structure
            try:
                # Based on the actual HTML, messages are in #main with role="row"
                message_elements = self.driver.find_elements(By.CSS_SELECTOR, '#main [role="row"]')
                print(f"📝 Found {len(message_elements)} message elements")
                
                if not message_elements:
                    print("❌ No message elements found")
                    return []
                    
            except Exception as e:
                print(f"❌ Error finding message elements: {e}")
                return []
            
            html_messages = []
            
            for i, msg_elem in enumerate(message_elements):
                try:
                    # Extract message with expansion handling
                    message_data = self.extract_message_with_expansion(msg_elem)
                    
                    if message_data and message_data['content'].strip():
                        # Get raw HTML
                        raw_html = msg_elem.get_attribute('outerHTML')
                        
                        # Generate message ID (use timestamp + position for uniqueness)
                        message_id = f"msg_{int(time.time())}_{i}"
                        
                        html_message = {
                            'id': message_id,
                            'chat': os.environ.get('TARGET_GROUP_NAME', 'ORDERS Restaurants'),
                            'html': raw_html,
                            'timestamp': datetime.now(timezone.utc).isoformat(),
                            'message_data': message_data
                        }
                        
                        html_messages.append(html_message)
                        
                        expansion_status = ""
                        if message_data.get('was_expanded'):
                            expansion_status = " [EXPANDED]"
                        elif message_data.get('expansion_failed'):
                            expansion_status = " [EXPANSION FAILED]"
                        
                        print(f"📝 Message {i}: {message_data['content'][:50]}...{expansion_status}")
                    
                except Exception as e:
                    print(f"⚠️ Error processing message {i}: {e}")
                    continue
            
            print(f"✅ Extracted {len(html_messages)} valid messages")
            return html_messages
            
        except Exception as e:
            print(f"❌ Error getting messages: {e}")
            return []

    def extract_message_with_expansion(self, msg_element):
        """Extract message content with automatic read more expansion"""
        try:
            # Step 1: Get initial text content
            initial_text = self.get_text_content(msg_element)
            
            if not initial_text.strip():
                return None
            
            # Step 2: Check for truncation indicators
            if self.is_truncated(initial_text):
                print(f"🔍 [TRUNCATE] Detected truncated message: '{initial_text[:50]}...'")
                
                # Step 3: Find and click expand button
                if self.expand_message(msg_element):
                    # Step 4: Re-extract full content after expansion
                    expanded_text = self.get_text_content(msg_element)
                    print(f"✅ [EXPAND] Successfully expanded: {len(expanded_text)} chars")
                    return {
                        'content': expanded_text,
                        'was_expanded': True,
                        'original_preview': initial_text[:100]
                    }
                else:
                    # Expansion failed - return what we have but flag the issue
                    print(f"❌ [EXPAND] Failed to expand truncated message")
                    return {
                        'content': initial_text,
                        'was_expanded': False,
                        'expansion_failed': True,
                        'error': 'Could not find or click expand button',
                        'original_preview': initial_text[:100]
                    }
            
            # No truncation detected
            return {
                'content': initial_text,
                'was_expanded': False
            }
            
        except Exception as e:
            print(f"❌ Error extracting message: {e}")
            return None

    def is_truncated(self, text):
        """Check if text appears to be truncated"""
        truncation_indicators = ['…', '...', '…\n', '...\n']
        return any(indicator in text for indicator in truncation_indicators)

    def expand_message(self, msg_element):
        """Find and click the read more button"""
        try:
            # Multiple strategies for finding expand buttons
            expand_selectors = [
                'div[role="button"]',  # Primary WhatsApp expand buttons
                '.read-more-button',   # Alternative class name
                'button[aria-label*="more"]',  # Aria label approach
                '[data-testid*="expand"]',     # Test ID approach
            ]
            
            for selector in expand_selectors:
                buttons = msg_element.find_elements(By.CSS_SELECTOR, selector)
                
                for btn in buttons:
                    btn_text = (btn.text or '').strip().lower()
                    aria_label = (btn.get_attribute('aria-label') or '').lower()
                    
                    # Check if this looks like an expand button
                    if (
                        'read more' in btn_text or 
                        'more' in btn_text or 
                        'expand' in btn_text or
                        'expand' in aria_label or
                        'more' in aria_label or
                        btn_text == ''  # Sometimes expand buttons have no text
                    ):
                        print(f"🔍 [EXPAND] Found expand button: text='{btn_text}' aria='{aria_label}'")
                        
                        # Click using JavaScript to avoid interception
                        self.driver.execute_script("arguments[0].click();", btn)
                        
                        # Wait for expansion to complete
                        time.sleep(2.5)  # Slightly longer wait for reliability
                        
                        return True
            
            print(f"❌ [EXPAND] No expand button found")
            return False
            
        except Exception as e:
            print(f"❌ [EXPAND] Exception during expansion: {e}")
            return False

    def get_text_content(self, msg_element):
        """Extract text content from message element based on actual HTML structure"""
        try:
            # FIXED: Only use the primary copyable-text container, not nested ones
            # Look for the main copyable-text element (usually has _ahy1 or _ahy2 class)
            primary_copyable = msg_element.find_elements(By.CSS_SELECTOR, '._ahy1.copyable-text, ._ahy2.copyable-text')
            
            if primary_copyable:
                # Use the first primary copyable-text element
                elem = primary_copyable[0]
                
                # Get text from ._ao3e.selectable-text spans within the primary copyable-text
                text_spans = elem.find_elements(By.CSS_SELECTOR, '._ao3e.selectable-text')
                
                if text_spans:
                    lines = []
                    for span in text_spans:
                        text = (span.get_attribute('textContent') or span.text or '').strip()
                        if text and not re.match(r'^\d{1,2}:\d{2}$', text):  # Skip timestamps
                            lines.append(text)
                    
                    if lines:
                        result = '\n'.join(lines)
                        print(f"🔍 [TEXT] Extracted from primary .copyable-text: '{result[:50]}...'")
                        return result
                else:
                    # Fallback: get text directly from primary copyable-text element
                    text = (elem.get_attribute('textContent') or elem.text or '').strip()
                    if text and not re.match(r'^\d{1,2}:\d{2}$', text):
                        result = text
                        print(f"🔍 [TEXT] Extracted from primary element: '{result[:50]}...'")
                        return result
            
            # Fallback: use any .copyable-text element (but only the first one)
            copyable_text_elems = msg_element.find_elements(By.CSS_SELECTOR, '.copyable-text')
            if copyable_text_elems:
                elem = copyable_text_elems[0]  # Only use the first one to avoid duplicates
                text = (elem.get_attribute('textContent') or elem.text or '').strip()
                if text and not re.match(r'^\d{1,2}:\d{2}$', text):
                    result = text
                    print(f"🔍 [TEXT] Extracted from fallback .copyable-text: '{result[:50]}...'")
                    return result
            
            # Fallback: look for any ._ao3e.selectable-text elements
            text_elems = msg_element.find_elements(By.CSS_SELECTOR, '._ao3e.selectable-text')
            if text_elems:
                lines = []
                for elem in text_elems:
                    text = (elem.get_attribute('textContent') or elem.text or '').strip()
                    if text and not re.match(r'^\d{1,2}:\d{2}$', text):
                        lines.append(text)
                
                if lines:
                    result = '\n'.join(lines)
                    print(f"🔍 [TEXT] Extracted from ._ao3e.selectable-text: '{result[:50]}...'")
                    return result
            
            print("⚠️ [TEXT] No text content found in message element")
            return ""
            
        except Exception as e:
            print(f"❌ [TEXT] Error extracting text: {e}")
            return ""

    def send_to_django(self, html_messages):
        """Send HTML messages to Django backend"""
        if not html_messages:
            print("📭 No messages to send to Django")
            return True
            
        try:
            url = f"{self.django_url}/api/whatsapp/receive-html/"
            payload = {
                'messages': html_messages
            }
            
            print(f"📤 Sending {len(html_messages)} messages to Django: {url}")
            
            response = requests.post(url, json=payload, timeout=30)
            
            if response.status_code == 200:
                result = response.json()
                print(f"✅ Django processed {result.get('processed_count', 0)} messages")
                print(f"📊 Expansion stats: {result.get('expansion_stats', {})}")
                return True
            else:
                print(f"❌ Django error {response.status_code}: {response.text}")
                return False
                
        except Exception as e:
            print(f"❌ Error sending to Django: {e}")
            return False

    def run_periodic_check(self, check_interval=30):
        """
        Run periodic checks for new messages
        
        Args:
            check_interval: Seconds between checks (default 30)
        """
        print(f"🔄 Starting periodic message checking (every {check_interval}s)")
        
        # Initial full scan
        print("🚀 Performing initial message scan...")
        messages = self.get_current_messages(scroll_to_load_more=True)
        if messages:
            self.send_to_django(messages)
            self.last_message_count = len(messages)
        
        # Periodic checks for new messages
        while self.is_running:
            try:
                time.sleep(check_interval)
                
                print(f"🔍 Checking for new messages...")
                
                # Get current messages without scrolling (just check what's visible)
                current_messages = self.get_current_messages(scroll_to_load_more=False)
                
                # Simple check: if message count increased, send new batch
                if len(current_messages) > self.last_message_count:
                    new_message_count = len(current_messages) - self.last_message_count
                    print(f"📬 Found {new_message_count} new messages")
                    
                    # Send only the new messages (last N messages)
                    new_messages = current_messages[-new_message_count:]
                    if self.send_to_django(new_messages):
                        self.last_message_count = len(current_messages)
                else:
                    print("📭 No new messages found")
                    
            except Exception as e:
                print(f"⚠️ Error during periodic check: {e}")
                time.sleep(5)  # Short pause before retrying

    def stop(self):
        """Stop the crawler"""
        self.is_running = False
        if self.driver:
            try:
                self.driver.quit()
                print("🛑 WebDriver stopped")
            except:
                pass
        print("🛑 Crawler stopped")

    def __del__(self):
        """Cleanup on destruction"""
        self.stop()


if __name__ == "__main__":
    # Example usage
    crawler = SimplifiedWhatsAppCrawler()
    
    try:
        if crawler.start_whatsapp_session():
            print("🚀 Starting periodic message monitoring...")
            crawler.run_periodic_check(check_interval=30)
        else:
            print("❌ Failed to start WhatsApp session")
    except KeyboardInterrupt:
        print("\n🛑 Stopping crawler...")
        crawler.stop()

