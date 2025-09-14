#!/usr/bin/env python3
"""
WhatsApp Crawler Server - Flask API for Flutter app
Handles WhatsApp Web scraping with Selenium
"""

from flask import Flask, jsonify, request
from flask_cors import CORS
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from webdriver_manager.chrome import ChromeDriverManager
from selenium.webdriver.chrome.service import Service
import threading
import time
import json
import os
from datetime import datetime

app = Flask(__name__)
CORS(app)

class WhatsAppCrawler:
    def __init__(self):
        self.driver = None
        self.is_running = False
        self.messages = []
        self.session_dir = None
        
    def cleanup_existing_sessions(self):
        """Kill any existing Chrome processes using our session directory"""
        try:
            import subprocess
            import os
            session_dir = os.path.abspath("./whatsapp-session")
            
            # Kill Chrome processes using our session directory
            try:
                result = subprocess.run(['pkill', '-f', f'user-data-dir={session_dir}'], 
                                      capture_output=True, text=True)
                if result.returncode == 0:
                    print("🧹 Killed existing Chrome processes")
                    import time
                    time.sleep(2)  # Wait for processes to fully terminate
            except Exception as e:
                print(f"⚠️ Could not kill existing processes: {e}")
        except Exception as e:
            print(f"⚠️ Error in cleanup: {e}")

    def initialize_driver(self):
        """Initialize Chrome WebDriver with WhatsApp session"""
        try:
            # First, clean up any existing sessions
            self.cleanup_existing_sessions()
            chrome_options = Options()
            
            # Basic Chrome options
            chrome_options.add_argument("--no-sandbox")
            chrome_options.add_argument("--disable-dev-shm-usage")
            chrome_options.add_argument("--disable-web-security")
            chrome_options.add_argument("--allow-running-insecure-content")
            
            # Session directory (reuse same directory to maintain login)
            import os
            self.session_dir = os.path.abspath("./whatsapp-session")
            os.makedirs(self.session_dir, exist_ok=True)
            chrome_options.add_argument(f"--user-data-dir={self.session_dir}")
            print(f"Using session directory: {self.session_dir}")
            
            # Anti-detection options
            chrome_options.add_argument("--disable-blink-features=AutomationControlled")
            chrome_options.add_experimental_option("excludeSwitches", ["enable-automation"])
            chrome_options.add_experimental_option('useAutomationExtension', False)
            
            # Try system ChromeDriver first (it works better)
            print("🔧 Trying system ChromeDriver...")
            try:
                service = Service()  # Use system chromedriver
                print("🚀 Starting Chrome browser...")
                self.driver = webdriver.Chrome(service=service, options=chrome_options)
                self.driver.execute_script("Object.defineProperty(navigator, 'webdriver', {get: () => undefined})")
                print("✅ Chrome WebDriver initialized with system driver")
                return True
            except Exception as e:
                print(f"❌ System ChromeDriver failed: {str(e)}")
                print("🔄 Falling back to ChromeDriverManager...")
            
            # Fallback: Use ChromeDriverManager
            driver_path = ChromeDriverManager().install()
            print(f"ChromeDriver path: {driver_path}")
            
            # Fix common webdriver-manager issue where it points to wrong file
            import os
            import stat
            if 'THIRD_PARTY_NOTICES' in driver_path:
                # Find the actual chromedriver executable
                driver_dir = os.path.dirname(driver_path)
                actual_driver = os.path.join(driver_dir, 'chromedriver')
                if os.path.exists(actual_driver):
                    driver_path = actual_driver
                    print(f"Fixed driver path: {driver_path}")
                else:
                    # Look for chromedriver in parent directory
                    parent_dir = os.path.dirname(driver_dir)
                    actual_driver = os.path.join(parent_dir, 'chromedriver')
                    if os.path.exists(actual_driver):
                        driver_path = actual_driver
                        print(f"Fixed driver path: {driver_path}")
            
            # Fix permissions if needed
            if os.path.exists(driver_path):
                current_permissions = os.stat(driver_path).st_mode
                if not (current_permissions & stat.S_IXUSR):
                    print("🔧 Fixing ChromeDriver permissions...")
                    os.chmod(driver_path, current_permissions | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
                    print("✅ Permissions fixed")
            
            service = Service(driver_path)
            
            print("🚀 Starting Chrome browser...")
            self.driver = webdriver.Chrome(service=service, options=chrome_options)
            
            # Remove webdriver property
            self.driver.execute_script("Object.defineProperty(navigator, 'webdriver', {get: () => undefined})")
            
            print("✅ Chrome WebDriver initialized with ChromeDriverManager")
            return True
            
        except Exception as e:
            print(f"❌ Both ChromeDriver methods failed: {str(e)}")
            print(f"Error type: {type(e).__name__}")
            import traceback
            print(f"Full traceback: {traceback.format_exc()}")
            return False
    
    def start_whatsapp(self):
        """Open WhatsApp Web"""
        try:
            self.driver.get("https://web.whatsapp.com")
            print("🌐 WhatsApp Web opened")
            
            # Wait for WhatsApp to load - try multiple selectors
            print("⏳ Waiting for WhatsApp to load...")
            
            # Debug: Check what's actually on the page
            import time
            time.sleep(5)  # Let page load
            
            # Try to find any WhatsApp elements
            page_source = self.driver.page_source
            print(f"🔍 Page title: {self.driver.title}")
            print(f"🔍 Current URL: {self.driver.current_url}")
            
            # Look for common WhatsApp elements
            qr_elements = self.driver.find_elements(By.CSS_SELECTOR, '[data-testid="qr-canvas"]')
            chat_elements = self.driver.find_elements(By.CSS_SELECTOR, '[data-testid="chat-list"]')
            landing_elements = self.driver.find_elements(By.CSS_SELECTOR, '[data-testid="landing-wrapper"]')
            
            print(f"🔍 Found QR elements: {len(qr_elements)}")
            print(f"🔍 Found chat elements: {len(chat_elements)}")
            print(f"🔍 Found landing elements: {len(landing_elements)}")
            
            # Wait for WhatsApp interface to appear - use working selector
            try:
                WebDriverWait(self.driver, 30).until(
                    lambda driver: driver.find_elements(By.CSS_SELECTOR, '#side')
                )
                print("✅ WhatsApp interface loaded")
            except Exception as wait_error:
                print(f"❌ WhatsApp failed to load: {wait_error}")
                print(f"🔍 Page source preview: {page_source[:500]}...")
                raise
            
            if self.driver.find_elements(By.CSS_SELECTOR, '[data-testid="qr-canvas"]'):
                print("📱 QR Code displayed - please scan with your phone")
                return {"status": "qr_code", "message": "Please scan QR code with your phone"}
            else:
                print("✅ WhatsApp logged in successfully")
                
                # Try to find and select the target group from environment
                import os
                target_group = os.environ['TARGET_GROUP_NAME']
                print(f"🎯 Target group from env: {target_group}")
                
                group_selected = self.find_and_select_group(target_group)
                
                if group_selected:
                    return {"status": "logged_in", "message": f"WhatsApp ready - {target_group} group selected"}
                else:
                    return {"status": "logged_in", "message": f"WhatsApp ready - could not find {target_group} group"}
                
        except Exception as e:
            error_msg = str(e) if str(e) else f"Unknown error of type {type(e).__name__}"
            print(f"❌ Error starting WhatsApp: {error_msg}")
            import traceback
            print(f"Full traceback: {traceback.format_exc()}")
            return {"status": "error", "message": error_msg}
    
    def find_and_select_group(self, group_name):
        """Find and select a specific WhatsApp group"""
        try:
            import time
            
            print(f"🔍 Searching for group: {group_name}")
            
            # Click on search box - use the actual selector from WhatsApp
            search_box = WebDriverWait(self.driver, 10).until(
                EC.element_to_be_clickable((By.CSS_SELECTOR, 'div[contenteditable="true"][data-tab="3"]'))
            )
            search_box.click()
            
            # Clear and type group name
            search_box.clear()
            search_box.send_keys(group_name)
            time.sleep(2)
            
            # Look for the group in search results - exact title match
            group_element = WebDriverWait(self.driver, 10).until(
                EC.element_to_be_clickable((By.XPATH, f"//span[@title='{group_name}']"))
            )
            
            # Click on the group
            group_element.click()
            print(f"✅ Selected group: {group_name}")
            
            # Wait a moment for the chat to load, then clear search
            time.sleep(2)
            
            # Clear search box by clicking on it and clearing - don't use ESCAPE
            try:
                search_box.clear()
            except:
                # If search box is no longer accessible, that's fine
                pass
            
            return True
            
        except Exception as e:
            print(f"❌ Could not find group '{group_name}': {e}")
            print("📝 Available groups will be listed when scraping messages")
            return False
    
    def scrape_messages(self):
        """Scrape messages from WhatsApp - try both open chat and chat list approaches"""
        try:
            print("🔍 Starting message scraping...")
            
            # First, try to ensure we're in the target group
            target_group = os.environ['TARGET_GROUP_NAME']
            print(f"🎯 Looking for group: {target_group}")
            
            # Try to find and select the group first
            if not self.find_and_select_group(target_group):
                print("⚠️ Could not select target group, will try to scrape from current view")
            
            # Wait a moment for the chat to load
            time.sleep(2)
            
            # Try to scrape from open chat first
            messages = self._scrape_from_open_chat()
            if messages:
                return messages
                
            # If that fails, try scraping from chat list
            print("🔄 Open chat scraping failed, trying chat list approach...")
            return self._scrape_from_chat_list()
            
        except Exception as e:
            print(f"❌ Error in scrape_messages: {e}")
            import traceback
            print(f"Full traceback: {traceback.format_exc()}")
            return []
    
    def _scrape_from_open_chat(self):
        """Try to scrape from an open chat conversation"""
        try:
            print("🔍 Attempting to scrape from open chat...")
            
            # Check if we have the main chat area
            main_elements = self.driver.find_elements(By.CSS_SELECTOR, "#main")
            if not main_elements:
                print("❌ No main chat area found")
                return []
            
            # Scroll to load all messages
            print("📜 Scrolling to load all messages...")
            self._scroll_to_load_all_messages()
            
            # Get all message elements from the conversation - try multiple selectors
            message_selectors = [
                '.message-in',  # Old selector
                '[data-id]',    # Messages have data-id attributes
                '.x1n2onr6',    # New WhatsApp message class
                'div[role="row"]', # Messages are often in row roles
                '.copyable-text', # Text content selector
            ]
            
            message_elements = []
            virtualized_elements = []
            
            # Find regular message elements
            for selector in message_selectors:
                elements = self.driver.find_elements(By.CSS_SELECTOR, selector)
                if elements:
                    message_elements = elements
                    print(f"🔍 Found {len(message_elements)} messages using selector: {selector}")
                    break
            
            # Also find virtualized elements (potential media messages)
            try:
                virtualized_elements = self.driver.find_elements(By.CSS_SELECTOR, '[data-virtualized="true"]')
                if virtualized_elements:
                    print(f"🎬 Found {len(virtualized_elements)} virtualized elements (potential media)")
                    # Debug: Print details of first few virtualized elements
                    for i, elem in enumerate(virtualized_elements[:3]):
                        try:
                            style = elem.get_attribute('style')
                            print(f"🔍 Virtualized element {i}: style='{style}'")
                        except:
                            pass
                else:
                    print("🎬 No virtualized elements found")
                    
                # Also try alternative media selectors
                media_selectors = [
                    'img[src*="blob:"]',  # Images
                    '[data-testid="audio-play-button"]',  # Voice messages
                    '[data-testid="media-download"]',  # Media downloads
                    '.message-in img',  # Images in messages
                    '[role="button"][aria-label*="Play"]',  # Play buttons
                ]
                
                for selector in media_selectors:
                    try:
                        media_elements = self.driver.find_elements(By.CSS_SELECTOR, selector)
                        if media_elements:
                            print(f"🎵 Found {len(media_elements)} elements with selector: {selector}")
                    except:
                        pass
                        
            except Exception as e:
                print(f"⚠️ Failed to find virtualized elements: {e}")
            
            # Process virtualized elements as media messages
            for i, virt_elem in enumerate(virtualized_elements):
                try:
                    # Get the height to determine media type
                    style = virt_elem.get_attribute('style')
                    height = 0
                    if 'min-height:' in style:
                        height_str = style.split('min-height:')[1].split('px')[0].strip()
                        try:
                            height = int(height_str)
                        except:
                            height = 0
                    
                    # Scroll to element and try to load actual content
                    self.driver.execute_script("arguments[0].scrollIntoView({behavior: 'smooth', block: 'center'});", virt_elem)
                    time.sleep(0.3)  # Wait for content to load
                    
                    # Try to find actual image URLs
                    image_url = None
                    try:
                        # Look for ALL media types in the virtualized element
                        media_selectors = {
                            'image': [
                                'img[src*="blob:"]',
                                'img[src*="data:"]', 
                                'img[src*="https://"]',
                                'img[src]',
                                '[style*="background-image"]',
                                'canvas'
                            ],
                            'voice': [
                                '[data-testid="audio-play-button"]',
                                '[data-testid="ptt-play-button"]',
                                'button[aria-label*="Play"]',
                                '.audio-play-button',
                                '[role="button"][aria-label*="audio"]'
                            ],
                            'video': [
                                'video',
                                '[data-testid="video-thumb"]',
                                '[data-testid="media-viewer-video"]'
                            ],
                            'document': [
                                '[data-testid="document-thumb"]',
                                '[data-testid="media-document"]'
                            ],
                            'sticker': [
                                '[data-testid="sticker"]',
                                'img[alt*="sticker"]'
                            ]
                        }
                        
                        # Try to detect specific media types
                        detected_media_type = None
                        media_content = None
                        
                        for media_type, selectors in media_selectors.items():
                            for selector in selectors:
                                try:
                                    media_elem = virt_elem.find_element(By.CSS_SELECTOR, selector)
                                    detected_media_type = media_type
                                    
                                    if media_type == 'image':
                                        if selector == 'canvas':
                                            try:
                                                media_content = self.driver.execute_script("return arguments[0].toDataURL('image/png');", media_elem)
                                            except:
                                                pass
                                        else:
                                            media_content = media_elem.get_attribute('src')
                                            if not media_content and 'background-image' in selector:
                                                style_attr = media_elem.get_attribute('style')
                                                if style_attr and 'background-image' in style_attr:
                                                    url_match = re.search(r'url\(["\']?([^"\']+)["\']?\)', style_attr)
                                                    if url_match:
                                                        media_content = url_match.group(1)
                                    
                                    elif media_type == 'voice':
                                        # For voice messages, try to get duration or other attributes
                                        duration = media_elem.get_attribute('aria-label') or media_elem.get_attribute('title')
                                        media_content = f"Voice message{f' - {duration}' if duration else ''}"
                                    
                                    elif media_type == 'video':
                                        # For videos, try to get thumbnail or duration
                                        src = media_elem.get_attribute('src') or media_elem.get_attribute('poster')
                                        duration = media_elem.get_attribute('duration')
                                        media_content = src or f"Video{f' - {duration}s' if duration else ''}"
                                    
                                    elif media_type == 'document':
                                        # For documents, try to get filename
                                        filename = media_elem.get_attribute('title') or media_elem.get_attribute('alt')
                                        media_content = filename or "Document attachment"
                                    
                                    elif media_type == 'sticker':
                                        # For stickers, try to get sticker info
                                        alt = media_elem.get_attribute('alt')
                                        media_content = alt or "Sticker"
                                    
                                    if media_content and len(str(media_content)) > 3:
                                        print(f"🎬 Found {media_type}: {str(media_content)[:80]}...")
                                        break
                                        
                                except:
                                    continue
                            
                            if detected_media_type and media_content:
                                break
                    except Exception as e:
                        print(f"⚠️ Error finding image: {e}")
                    
                    # Use detected media type or fall back to height-based classification
                    if detected_media_type and media_content:
                        media_type = detected_media_type
                        media_info = media_content
                    elif height > 200:
                        media_type = 'image'
                        media_info = f'Image (height: {height}px)'
                    elif height > 100:
                        media_type = 'voice'
                        media_info = f'Voice/Audio (height: {height}px)'
                    else:
                        media_type = 'other'
                        media_info = f'Media (height: {height}px)'
                    
                    # Try to find sender info from nearby elements
                    sender = "Unknown"
                    try:
                        # Look for sender in parent or sibling elements
                        parent = virt_elem.find_element(By.XPATH, '..')
                        sender_elems = parent.find_elements(By.CSS_SELECTOR, '._ahxt, ._ahx_, [data-pre-plain-text]')
                        for elem in sender_elems:
                            text = elem.text.strip()
                            if text and len(text) > 1:
                                sender = text
                                break
                    except:
                        pass
                    
                    # Create media message
                    from datetime import timezone
                    media_message = {
                        "id": f"media_{i}_{int(time.time())}",
                        "chat": "ORDERS Restaurants",
                        "sender": sender,
                        "content": f"[{media_type.upper()}] {media_info}",
                        "cleanedContent": f"[{media_type.upper()}] {media_info}",
                        "timestamp": datetime.now(timezone.utc).isoformat(),
                        "scraped_at": datetime.now().isoformat(),
                        "type": "other",  # Media messages classified as 'other'
                        "items": [],
                        "instructions": "",
                        "message_type": media_type,
                        "media_info": media_info
                    }
                    
                    messages.append(media_message)
                    print(f"🎬 Added virtualized {media_type} message: {media_info} from sender: {sender}")
                    
                except Exception as e:
                    print(f"⚠️ Error processing virtualized element {i}: {e}")
                    continue
            
            if not message_elements:
                # Debug: Let's see what's actually in the main area
                print("🔍 No messages found with standard selectors, debugging...")
                main_selectors = ["#main", ".copyable-area", "[role='main']"]
                debug_found = False
                for selector in main_selectors:
                    main_elements = self.driver.find_elements(By.CSS_SELECTOR, selector)
                    if main_elements:
                        main_area = main_elements[0]
                        html_content = main_area.get_attribute('innerHTML')[:500]
                        print(f"📋 Found main area with {selector}: {html_content}")
                        debug_found = True
                        break
                
                if not debug_found:
                    print("❌ Could not find any main area elements for debugging")
            
            if len(message_elements) == 0:
                print("❌ No messages found in open chat")
                return []

            messages = []
            for i, msg_elem in enumerate(message_elements):
                try:
                    # Get sender name
                    sender = "Unknown"
                    sender_selectors = ['._ahxt', '._ahx_', '[data-pre-plain-text]']
                    for selector in sender_selectors:
                        sender_elems = msg_elem.find_elements(By.CSS_SELECTOR, selector)
                        if sender_elems and sender_elems[0].text.strip():
                            sender = sender_elems[0].text.strip()
                            break

                    # Check for forwarded and reply messages
                    is_forwarded = False
                    is_reply = False
                    reply_content = ""
                    forwarded_info = ""
                    
                    # Detect forwarded messages
                    forwarded_selectors = [
                        '[data-testid="forwarded-indicator"]',
                        '.forwarded-indicator',
                        '[aria-label*="Forwarded"]',
                        'span:contains("Forwarded")'
                    ]
                    
                    for selector in forwarded_selectors:
                        try:
                            if msg_elem.find_elements(By.CSS_SELECTOR, selector):
                                is_forwarded = True
                                forwarded_info = "Forwarded message"
                                break
                        except:
                            continue
                    
                    # Detect reply/quoted messages
                    reply_selectors = [
                        '[data-testid="quoted-message"]',
                        '.quoted-mention',
                        '[data-testid="context-info"]',
                        '.context-info'
                    ]
                    
                    for selector in reply_selectors:
                        try:
                            reply_elems = msg_elem.find_elements(By.CSS_SELECTOR, selector)
                            if reply_elems:
                                is_reply = True
                                reply_content = reply_elems[0].text.strip()[:100] + "..." if len(reply_elems[0].text.strip()) > 100 else reply_elems[0].text.strip()
                                break
                        except:
                            continue
                    
                    # Detect message type and extract content
                    message_text = ""
                    message_type = "text"
                    media_info = {}
                    
                    # Check for media messages first
                    media_detected = False
                    
                    # Enhanced media detection - PRIORITIZE WHATSAPP CDN URLS
                    image_selectors = [
                        'img[src*="media-jnb2-1.cdn.whatsapp.net"]',  # REAL WhatsApp CDN URLs - HIGHEST PRIORITY
                        'img[src*="media-"]',                          # Other WhatsApp media URLs
                        'img[src*="whatsapp.net"]',                    # Any WhatsApp domain
                        'img[src*="blob:"]',                           # WhatsApp blob URLs (actual images)
                        'img[src*="data:image"]',                      # Base64 thumbnails
                        'img.x15kfjtz',                                # WhatsApp image class
                        'img[src*="https://"]',
                        'img[src]'
                    ]
                    
                    for selector in image_selectors:
                        try:
                            img_elems = msg_elem.find_elements(By.CSS_SELECTOR, selector)
                            if img_elems:
                                message_type = "image"
                                
                                # Prioritize WhatsApp CDN URLs, then blob URLs, then base64 thumbnails
                                best_img_src = None
                                priority_score = 0  # Higher = better
                                
                                for img in img_elems:
                                    src = img.get_attribute('src')
                                    if src and len(src) > 10:
                                        current_score = 0
                                        if 'whatsapp.net' in src or 'media-' in src:
                                            current_score = 100  # HIGHEST PRIORITY - Real WhatsApp URLs
                                        elif 'blob:' in src:
                                            current_score = 50   # Medium priority - Blob URLs
                                        elif 'data:' in src:
                                            current_score = 10   # Low priority - Base64 thumbnails
                                        else:
                                            current_score = 1    # Lowest priority - Other URLs
                                        
                                        if current_score > priority_score:
                                            best_img_src = src
                                            priority_score = current_score
                                            print(f"🎯 NEW BEST IMAGE (score {current_score}): {src[:80]}...")
                                
                                if best_img_src:
                                    media_info = best_img_src
                                    img_type = "WhatsApp CDN" if ("whatsapp.net" in best_img_src or "media-" in best_img_src) else "blob URL" if "blob:" in best_img_src else "base64" if "data:" in best_img_src else "URL"
                                    print(f"📷 FINAL IMAGE ({img_type}): {best_img_src[:80]}...")
                                    message_text = "[📷 Image]"  # Clean placeholder - actual URL is in media_info
                                else:
                                    media_info = f"Image ({len(img_elems)} found but no URLs)"
                                    message_text = "[📷 Image - NO URL FOUND]"
                                    print(f"❌ CRITICAL: Found {len(img_elems)} image elements but NO valid URLs!")
                                media_detected = True
                                break
                        except Exception as e:
                            print(f"⚠️ Error checking image selector {selector}: {e}")
                            continue
                    
                    # Check for voice messages
                    if not media_detected:
                        voice_selectors = [
                            'button[aria-label*="Play voice message"]',  # Exact WhatsApp voice button
                            '[data-icon="audio-play"]',  # WhatsApp audio play icon
                            '[data-testid="audio-play-button"]',
                            '[data-testid="ptt-play-button"]',
                            'button[aria-label*="Play"]',
                            '.audio-play-button'
                        ]
                        
                        for selector in voice_selectors:
                            try:
                                voice_elems = msg_elem.find_elements(By.CSS_SELECTOR, selector)
                                if voice_elems:
                                    message_type = "voice"
                                    message_text = "[🎤 Voice message]"
                                    
                                    # Try to extract duration from various sources
                                    duration = None
                                    
                                    # Method 1: Check aria-valuetext for duration (e.g., "0:00/0:19")
                                    try:
                                        slider_elem = msg_elem.find_element(By.CSS_SELECTOR, '[role="slider"]')
                                        valuetext = slider_elem.get_attribute('aria-valuetext')
                                        if valuetext and '/' in valuetext:
                                            duration = valuetext.split('/')[-1]  # Get "0:19" from "0:00/0:19"
                                    except:
                                        pass
                                    
                                    # Method 2: Look for duration text elements
                                    if not duration:
                                        try:
                                            duration_elems = msg_elem.find_elements(By.CSS_SELECTOR, 'div[aria-hidden="true"]')
                                            for elem in duration_elems:
                                                text = elem.text.strip()
                                                if ':' in text and len(text) <= 6:  # Format like "0:19"
                                                    duration = text
                                                    break
                                        except:
                                            pass

                                    # Method 3: Fallback to button attributes
                                    if not duration:
                                        duration = voice_elems[0].get_attribute('aria-label') or voice_elems[0].get_attribute('title')
                                    
                                    media_info = f"Voice message{f' ({duration})' if duration else ''}"
                                    media_detected = True
                                    print(f"🎤 Found voice message with duration: {media_info}")
                                    break
                            except Exception as e:
                                print(f"⚠️ Error checking voice selector {selector}: {e}")
                        continue

                    # Check for videos
                    if not media_detected:
                        video_selectors = [
                            'video',
                            '[data-testid="video-thumb"]',
                            '[data-testid="media-viewer-video"]'
                        ]
                        
                        for selector in video_selectors:
                            try:
                                video_elems = msg_elem.find_elements(By.CSS_SELECTOR, selector)
                                if video_elems:
                                    message_type = "video"
                                    message_text = "[🎥 Video]"
                                    video_src = video_elems[0].get_attribute('src') or video_elems[0].get_attribute('poster')
                                    media_info = video_src or f"Video ({len(video_elems)} found)"
                                    media_detected = True
                                    print(f"🎥 Found video: {media_info}")
                                    break
                            except Exception as e:
                                print(f"⚠️ Error checking video selector {selector}: {e}")
                                continue
                    
                    # Check for documents/files
                    if not media_detected:
                        doc_elems = msg_elem.find_elements(By.CSS_SELECTOR, '[data-testid="document-thumb"], .document-thumb')
                        if doc_elems:
                            message_type = "document"
                            message_text = "[📄 Document]"
                            media_info = {"type": "document"}
                            media_detected = True
                            print(f"📄 Found document message")
                    
                    # Check for stickers
                    if not media_detected:
                        sticker_elems = msg_elem.find_elements(By.CSS_SELECTOR, '[data-testid="sticker"]')
                        if sticker_elems:
                            message_type = "sticker"
                            message_text = "[😀 Sticker]"
                            media_info = {"type": "sticker"}
                            media_detected = True
                            print(f"😀 Found sticker message")
                    
                    # If no media detected, extract text content
                    if not media_detected:
                        content_selectors = [
                            '.selectable-text.copyable-text',
                            '._ao3e',
                            '.copyable-text',
                            '[data-testid="conversation-text"]'
                        ]
                        
                        for selector in content_selectors:
                            content_elems = msg_elem.find_elements(By.CSS_SELECTOR, selector)
                            for elem in content_elems:
                                text = elem.text.strip()
                                if text and len(text) > 2:  # Skip very short content
                                    message_text = text
                                    break
                            if message_text:
                                break
                        
                        # Fallback: get all text from message element
                        if not message_text:
                            full_text = msg_elem.text.strip()
                            # Clean up the text by removing timestamps and sender info
                            lines = [line.strip() for line in full_text.split('\n') if line.strip()]
                            for line in lines:
                                # Skip lines that look like timestamps or sender names
                                if ':' in line and len(line) < 10:  # Likely timestamp
                                    continue
                                if len(line) > 5:  # Actual message content
                                    message_text = line
                                    break
                    
                    # Skip if no content found
                    if not message_text:
                        print(f"⚠️ Skipping message with no extractable content")
                        continue

                    # Get timestamp with proper timezone
                    from datetime import timezone
                    timestamp = datetime.now(timezone.utc).isoformat()
                    
                    # Try to extract ACTUAL WhatsApp timestamp from data-pre-plain-text
                    try:
                        # Look for data-pre-plain-text attribute with format [HH:MM, DD/MM/YYYY]
                        pre_text_elems = msg_elem.find_elements(By.CSS_SELECTOR, '[data-pre-plain-text]')
                        for elem in pre_text_elems:
                            pre_text = elem.get_attribute('data-pre-plain-text')
                            if pre_text and '[' in pre_text and ']' in pre_text:
                                # Extract timestamp like "[12:46, 27/08/2025] Karl: "
                                import re
                                match = re.search(r'\[(\d{1,2}:\d{2}), (\d{1,2}/\d{1,2}/\d{4})\]', pre_text)
                                if match:
                                    time_str, date_str = match.groups()
                                    # Parse "12:46" and "27/08/2025"
                                    from datetime import datetime as dt
                                    full_datetime_str = f"{date_str} {time_str}"
                                    parsed_datetime = dt.strptime(full_datetime_str, "%d/%m/%Y %H:%M")
                                    timestamp = parsed_datetime.replace(tzinfo=timezone.utc).isoformat()
                                    print(f"🕐 EXTRACTED REAL TIMESTAMP: {timestamp} from {pre_text[:50]}...")
                                    break
                    except Exception as e:
                        print(f"⚠️ Failed to extract real timestamp: {e}")
                    
                    # Fallback: Try to get timestamp from span elements
                    if timestamp == datetime.now(timezone.utc).isoformat():
                        try:
                            time_selectors = [
                                '.x1c4vz4f.x2lah0s',  # Common timestamp selector
                                '.x1rg5ohu.x16dsc37',  # Alternative timestamp selector  
                                'span[dir="auto"]'     # Generic span with time
                            ]
                            for selector in time_selectors:
                                time_elems = msg_elem.find_elements(By.CSS_SELECTOR, selector)
                                for elem in time_elems:
                                    time_text = elem.text.strip()
                                    if time_text and ':' in time_text and len(time_text) <= 6 and 'Edited' not in time_text:
                                        # Use today's date with extracted time
                                        from datetime import datetime as dt
                                        today = dt.now(timezone.utc).date()
                                        if len(time_text.split(':')) == 2:
                                            hour, minute = time_text.split(':')
                                            parsed_time = dt.combine(today, dt.strptime(f"{hour}:{minute}", "%H:%M").time())
                                            timestamp = parsed_time.replace(tzinfo=timezone.utc).isoformat()
                                            print(f"🕐 FALLBACK TIMESTAMP: {timestamp} from span text '{time_text}'")
                                            break
                                if timestamp != datetime.now(timezone.utc).isoformat():
                                    break
                        except Exception as e:
                            print(f"⚠️ Failed to parse fallback timestamp: {e}")

                    # Extract media URL and type from media_info
                    media_url = ""
                    media_type_field = ""
                    if message_type == "image" and isinstance(media_info, str) and media_info.startswith(('http', 'blob:', 'data:')):
                        media_url = media_info
                        media_type_field = "image"
                    elif message_type == "voice":
                        media_type_field = "voice"
                        # media_info contains duration info, no URL for voice
                    elif message_type == "video" and isinstance(media_info, str) and media_info.startswith(('http', 'blob:')):
                        media_url = media_info
                        media_type_field = "video"
                    elif message_type in ["document", "sticker"]:
                        media_type_field = message_type

                    # Create message object
                    message = {
                        "id": f"msg_{i}_{int(time.time())}",
                        "chat": "ORDERS Restaurants",
                        "sender": sender,
                        "content": message_text,
                        "cleanedContent": message_text,
                        "timestamp": timestamp,
                        "scraped_at": datetime.now().isoformat(),
                        "type": self.classify_message(message_text, message_type),
                        "items": [],
                        "instructions": "",
                        "message_type": message_type,
                        "media_url": media_url,
                        "media_type": media_type_field,
                        "media_info": media_info if isinstance(media_info, str) else str(media_info),
                        "is_forwarded": is_forwarded,
                        "forwarded_info": forwarded_info,
                        "is_reply": is_reply,
                        "reply_content": reply_content
                    }

                    messages.append(message)
                    print(f"📝 Found message from {sender}: {message_text[:50]}...")

                except Exception as msg_error:
                    print(f"⚠️ Error processing message {i}: {msg_error}")
                    continue

            self.messages = messages
            print(f"✅ Scraped {len(messages)} messages from open chat")
            return messages
            
        except Exception as e:
            print(f"❌ Error scraping from open chat: {e}")
            return []
    
    def _scrape_from_chat_list(self):
        """Fallback: scrape from chat list previews"""
        try:
            print("🔍 Attempting to scrape from chat list...")
            
            # Check if we have the chat list
            chat_list = self.driver.find_elements(By.CSS_SELECTOR, '#pane-side')
            if not chat_list:
                print("❌ WhatsApp interface not loaded properly.")
                return []
            
            # Get all chat items from the list
            chat_elements = self.driver.find_elements(By.CSS_SELECTOR, '[role="listitem"]')
            print(f"🔍 Found {len(chat_elements)} chat items in list")
            
            messages = []
            target_group = os.environ['TARGET_GROUP_NAME']
            
            for i, chat_elem in enumerate(chat_elements):
                try:
                    # Get chat name/title
                    chat_name = "Unknown Chat"
                    try:
                        title_elem = chat_elem.find_element(By.CSS_SELECTOR, 'span[title]')
                        chat_name = title_elem.get_attribute('title')
                    except:
                        pass
                    
                    # Only process messages from our target group
                    if target_group.lower() not in chat_name.lower():
                        continue
                    
                    # Get message preview text
                    message_text = ""
                    try:
                        # Look for message preview in the chat item
                        preview_elems = chat_elem.find_elements(By.CSS_SELECTOR, 'span[dir]')
                        for elem in preview_elems:
                            text = elem.text.strip()
                            if text and len(text) > 10:  # Skip short texts like timestamps
                                message_text = text
                                break
                    except:
                        pass
                    
                    if not message_text:
                        continue
                    
                    # Get timestamp - try to extract ACTUAL WhatsApp timestamp
                    from datetime import timezone
                    timestamp = datetime.now(timezone.utc).isoformat()
                    
                    try:
                        # Try to extract from data-pre-plain-text first
                        pre_text_elems = chat_elem.find_elements(By.CSS_SELECTOR, '[data-pre-plain-text]')
                        for elem in pre_text_elems:
                            pre_text = elem.get_attribute('data-pre-plain-text')
                            if pre_text and '[' in pre_text and ']' in pre_text:
                                import re
                                match = re.search(r'\[(\d{1,2}:\d{2}), (\d{1,2}/\d{1,2}/\d{4})\]', pre_text)
                                if match:
                                    time_str, date_str = match.groups()
                                    from datetime import datetime as dt
                                    full_datetime_str = f"{date_str} {time_str}"
                                    parsed_datetime = dt.strptime(full_datetime_str, "%d/%m/%Y %H:%M")
                                    timestamp = parsed_datetime.replace(tzinfo=timezone.utc).isoformat()
                                    break
                        
                        # Fallback to other selectors
                        if timestamp == datetime.now(timezone.utc).isoformat():
                            time_selectors = ['._ak8i', '.x1c4vz4f.x2lah0s', '.x1rg5ohu.x16dsc37']
                            for selector in time_selectors:
                                time_elems = chat_elem.find_elements(By.CSS_SELECTOR, selector)
                                if time_elems:
                                    time_text = time_elems[0].text.strip()
                                    if time_text and ':' in time_text and len(time_text) <= 6:
                                        # Use today's date with extracted time
                                        from datetime import datetime as dt
                                        today = dt.now(timezone.utc).date()
                                        if len(time_text.split(':')) == 2:
                                            hour, minute = time_text.split(':')
                                            parsed_time = dt.combine(today, dt.strptime(f"{hour}:{minute}", "%H:%M").time())
                                            timestamp = parsed_time.replace(tzinfo=timezone.utc).isoformat()
                                            break
                    except Exception as e:
                        print(f"⚠️ Failed to extract timestamp: {e}")
                        pass
                    
                    # Create message object
                    message = {
                        "id": f"chat_{i}_{int(time.time())}",
                        "chat": chat_name,
                        "sender": chat_name,
                        "content": message_text,
                        "cleanedContent": message_text,
                        "timestamp": timestamp,
                        "scraped_at": datetime.now().isoformat(),
                        "type": self.classify_message(message_text),
                        "items": [],
                        "instructions": ""
                    }
                    
                    messages.append(message)
                    print(f"📝 Found message from {chat_name}: {message_text[:50]}...")
                    
                except Exception as msg_error:
                    print(f"⚠️ Error processing chat {i}: {msg_error}")
                    continue
            
            self.messages = messages
            print(f"✅ Scraped {len(messages)} messages from chat list")
            return messages
            
        except Exception as e:
            print(f"❌ Error scraping from chat list: {e}")
            return []
    
    def _scroll_to_load_all_messages(self):
        """Scroll up in the chat to load all messages"""
        try:
            # Try multiple selectors to find the scrollable message container
            container_selectors = [
                '.copyable-area',  # Main message area
                '#main',           # Main chat container
                '[role="main"]',   # Semantic main role
                '.x5yr21d.xnpuxes.copyable-area'  # More specific copyable area
            ]
            
            message_container = None
            for selector in container_selectors:
                try:
                    containers = self.driver.find_elements(By.CSS_SELECTOR, selector)
                    if containers:
                        message_container = containers[0]
                        print(f"📦 Found message container using selector: {selector}")
                        break
                except:
                    continue
            
            if not message_container:
                print("❌ Could not find scrollable message container")
                return
            
            print("📜 Starting scroll to load all messages...")
            previous_message_count = 0
            scroll_attempts = 0
            max_scrolls = 50  # Prevent infinite scrolling
            
            while scroll_attempts < max_scrolls:
                # Get current message count - try multiple selectors including virtualized
                current_count = 0
                virtualized_count = 0
                for selector in ['.message-in', '[data-id]', '.x1n2onr6', 'div[role="row"]']:
                    try:
                        current_messages = self.driver.find_elements(By.CSS_SELECTOR, selector)
                        if current_messages:
                            current_count = len(current_messages)
                            break
                    except:
                        continue
                
                # Also count virtualized elements (potential media)
                try:
                    virtualized_elements = self.driver.find_elements(By.CSS_SELECTOR, '[data-virtualized="true"]')
                    virtualized_count = len(virtualized_elements)
                    print(f"🎬 Found {virtualized_count} virtualized elements (potential media)")
                except:
                    pass
                
                total_elements = current_count + virtualized_count
                print(f"📊 Scroll {scroll_attempts + 1}: {current_count} messages + {virtualized_count} virtualized = {total_elements} total")
                
                # If no new messages loaded, we've reached the top
                if total_elements == previous_message_count and scroll_attempts > 0:
                    print("🔝 Reached top of chat - no more messages to load")
                    break
                
                previous_message_count = total_elements
                
                # Try different scroll methods
                try:
                    # Method 1: Scroll to top of container
                    self.driver.execute_script("arguments[0].scrollTop = 0", message_container)
                except:
                    try:
                        # Method 2: Scroll the window to top
                        self.driver.execute_script("window.scrollTo(0, 0)")
                    except:
                        try:
                            # Method 3: Send Page Up key to first message
                            if current_messages:
                                current_messages[0].send_keys(Keys.PAGE_UP)
                        except:
                            print("⚠️ All scroll methods failed for this attempt")
                
                # Additional step: Scroll through virtualized content to load media
                if virtualized_count > 0:
                    try:
                        # Slow scroll through the chat to trigger virtualized content loading
                        scroll_height = self.driver.execute_script("return arguments[0].scrollHeight", message_container)
                        for i in range(0, scroll_height, 300):
                            self.driver.execute_script(f"arguments[0].scrollTop = {i}", message_container)
                            time.sleep(0.3)  # Small delay to allow content to load
                        print("🔄 Scrolled through virtualized content to trigger loading")
                    except Exception as ve:
                        print(f"⚠️ Error scrolling through virtualized content: {ve}")
                
                # Wait for messages to load
                time.sleep(4)  # Increased wait time for media loading
                
                scroll_attempts += 1
            
            final_count = len(self.driver.find_elements(By.CSS_SELECTOR, '.message-in'))
            print(f"✅ Finished scrolling. Total messages loaded: {final_count}")
            
        except Exception as e:
            print(f"⚠️ Error during scrolling: {e}")
            print("📝 Continuing with currently loaded messages...")
    
    
    def classify_message(self, content, media_type="text"):
        """Classify message as order, stock, or other"""
        
        # Media messages are usually not orders or stock updates
        if media_type != "text":
            # Voice messages might contain orders
            if media_type == "voice":
                return 'other'  # Could be order but we can't process voice yet
            # Images might be product photos or order lists
            elif media_type == "image":
                return 'other'  # Could be order but we can't process images yet
            else:
                return 'other'
        
        content_upper = content.upper()
        
        # Order day demarcation indicators
        demarcation_keywords = ['ORDERS STARTS HERE', 'THURSDAY ORDERS', 'TUESDAY ORDERS', 'MONDAY ORDERS']
        if any(keyword in content_upper for keyword in demarcation_keywords):
            return 'demarcation'
        
        # Stock indicators (from stock controller)
        stock_keywords = ['STOCK', 'AVAILABLE', 'INVENTORY', 'SUPPLY', 'STOKE']
        if any(keyword in content_upper for keyword in stock_keywords):
            return 'stock'
        
        # Order indicators
        order_keywords = ['ORDER', 'NEED', 'WANT', 'KG', 'BOXES', 'X1', 'X2', 'X3', 'X4', 'X5']
        quantity_patterns = ['\\d+\\s*KG', '\\d+\\s*X', 'X\\d+']
        
        import re
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

# Global crawler instance
crawler = WhatsAppCrawler()

# API Routes
@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        "status": "ok",
        "crawler_running": crawler.is_running,
        "driver_active": crawler.driver is not None,
        "message_count": len(crawler.messages)
    })

@app.route('/api/whatsapp/start', methods=['POST'])
def start_whatsapp():
    """Start WhatsApp crawler"""
    try:
        if not crawler.driver:
            if not crawler.initialize_driver():
                return jsonify({"error": "Failed to initialize WebDriver"}), 500
        
        result = crawler.start_whatsapp()
        crawler.is_running = True
        
        return jsonify(result)
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/whatsapp/stop', methods=['POST'])
def stop_whatsapp():
    """Stop WhatsApp crawler"""
    try:
        crawler.stop()
        return jsonify({"status": "stopped"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/messages', methods=['GET'])
def get_messages():
    """Get all scraped messages"""
    try:
        if not crawler.driver or not crawler.is_running:
            return jsonify({"error": "Crawler not running"}), 400
        
        # Always scrape fresh messages when requested
        messages = crawler.scrape_messages()
        return jsonify(messages)
    except Exception as e:
        print(f"❌ Error in get_messages: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/api/messages/refresh', methods=['POST'])
def refresh_messages():
    """Manually refresh messages"""
    try:
        if not crawler.driver or not crawler.is_running:
            return jsonify({"error": "Crawler not running"}), 400
        
        messages = crawler.scrape_messages()
        return jsonify({
            "status": "success",
            "message_count": len(messages),
            "messages": messages
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/messages/edit', methods=['POST'])
def edit_message():
    """Edit a message content"""
    try:
        data = request.get_json()
        message_id = data.get('message_id')
        edited_content = data.get('edited_content')
        
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
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/messages/process', methods=['POST'])
def process_messages():
    """Process selected messages"""
    try:
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
        
    except Exception as e:
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
    return extract_stock_items(content)  # Same logic for now

def extract_product_name(text):
    """Extract product name from text"""
    # Simple extraction - remove numbers and common units
    import re
    cleaned = re.sub(r'\d+', '', text)
    cleaned = re.sub(r'(kg|box|boxes|pcs|pieces)', '', cleaned, flags=re.IGNORECASE)
    return cleaned.strip()

def extract_quantity(text):
    """Extract quantity from text"""
    import re
    numbers = re.findall(r'\d+', text)
    return numbers[0] if numbers else "1"

if __name__ == '__main__':
    print("🚀 Starting WhatsApp Server...")
    print("📱 Make sure Chrome is installed")
    print("🌐 Server will run on http://localhost:5001")
    
    app.run(host='127.0.0.1', port=5001, debug=True)
