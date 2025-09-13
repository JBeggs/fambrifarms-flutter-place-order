#!/usr/bin/env python3
"""
Chrome WebDriver management for WhatsApp Web scraping
Handles WebDriver lifecycle, session management, and error recovery
"""

import os
import subprocess
import time
from pathlib import Path
from typing import Optional

from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from webdriver_manager.chrome import ChromeDriverManager

from ..config.settings import (
    CHROME_CONFIG, WHATSAPP_CONFIG, PERFORMANCE_CONFIG, 
    get_chrome_options, ensure_directories
)
from ..config.logging_config import LoggerMixin, log_performance
from .exceptions import (
    WebDriverInitializationError, WebDriverConnectionError, 
    WebDriverTimeoutError, WhatsAppLoginError, WhatsAppNavigationError
)


class WebDriverManager(LoggerMixin):
    """
    Manages Chrome WebDriver lifecycle for WhatsApp Web scraping.
    
    Handles:
    - WebDriver initialization and cleanup
    - Session management and recovery
    - Chrome process management
    - Connection health monitoring
    """
    
    def __init__(self):
        self.driver: Optional[webdriver.Chrome] = None
        self.session_dir = Path(CHROME_CONFIG['user_data_dir'])
        self.is_initialized = False
        
        # Ensure required directories exist
        ensure_directories()
    
    @log_performance("WebDriver Initialization")
    def initialize_driver(self) -> webdriver.Chrome:
        """
        Initialize Chrome WebDriver with WhatsApp Web optimized settings.
        
        Returns:
            Chrome WebDriver instance
            
        Raises:
            WebDriverInitializationError: If driver initialization fails
        """
        if self.driver and self.is_driver_alive():
            self.logger.info("WebDriver already initialized and alive")
            return self.driver
        
        try:
            # Clean up any existing sessions first
            self._cleanup_existing_sessions()
            
            # Get Chrome options
            options = get_chrome_options()
            
            # Set up Chrome service
            service = Service(ChromeDriverManager().install())
            
            self.logger.info("Initializing Chrome WebDriver...")
            
            # Create WebDriver instance
            self.driver = webdriver.Chrome(service=service, options=options)
            
            # Configure timeouts
            self.driver.implicitly_wait(PERFORMANCE_CONFIG['implicit_wait'])
            self.driver.set_page_load_timeout(PERFORMANCE_CONFIG['page_load_timeout'])
            
            # Test driver responsiveness
            self.driver.get("about:blank")
            
            self.is_initialized = True
            self.logger.info("✅ Chrome WebDriver initialized successfully")
            
            return self.driver
            
        except Exception as e:
            self.logger.error(f"❌ Failed to initialize WebDriver: {e}")
            self._cleanup_driver()
            raise WebDriverInitializationError(f"WebDriver initialization failed: {e}")
    
    def is_driver_alive(self) -> bool:
        """
        Check if WebDriver is alive and responsive.
        
        Returns:
            True if driver is alive, False otherwise
        """
        if not self.driver:
            return False
        
        try:
            # Try a simple operation to test responsiveness
            _ = self.driver.current_url
            return True
        except Exception as e:
            self.logger.warning(f"WebDriver not responsive: {e}")
            return False
    
    @log_performance("WhatsApp Web Navigation")
    def navigate_to_whatsapp(self) -> bool:
        """
        Navigate to WhatsApp Web and handle login if needed.
        
        Returns:
            True if successfully navigated and logged in
            
        Raises:
            WhatsAppNavigationError: If navigation fails
            WhatsAppLoginError: If login fails
        """
        if not self.driver:
            raise WhatsAppNavigationError("WebDriver not initialized")
        
        try:
            self.logger.info("Navigating to WhatsApp Web...")
            self.driver.get(WHATSAPP_CONFIG['base_url'])
            
            # Wait for page to load
            WebDriverWait(self.driver, PERFORMANCE_CONFIG['page_load_timeout']).until(
                lambda driver: driver.execute_script("return document.readyState") == "complete"
            )
            
            # Check if already logged in
            if self._is_logged_in():
                self.logger.info("✅ Already logged in to WhatsApp Web")
                return True
            
            # Handle QR code login
            return self._handle_qr_login()
            
        except Exception as e:
            self.logger.error(f"❌ Failed to navigate to WhatsApp Web: {e}")
            raise WhatsAppNavigationError(f"Navigation failed: {e}")
    
    def _is_logged_in(self) -> bool:
        """Check if user is logged in to WhatsApp Web."""
        try:
            # Look for chat panel (indicates successful login)
            WebDriverWait(self.driver, 5).until(
                EC.presence_of_element_located((By.CSS_SELECTOR, WHATSAPP_CONFIG['chat_selector']))
            )
            return True
        except:
            return False
    
    def _handle_qr_login(self) -> bool:
        """
        Handle QR code scanning for WhatsApp Web login.
        
        Returns:
            True if login successful
            
        Raises:
            WhatsAppLoginError: If QR scan times out or fails
        """
        try:
            self.logger.info("⏳ Waiting for QR code scan...")
            
            # Wait for QR code to appear
            qr_selector = '[data-testid="qr-code"]'
            WebDriverWait(self.driver, 10).until(
                EC.presence_of_element_located((By.CSS_SELECTOR, qr_selector))
            )
            
            self.logger.info("📱 QR code displayed. Please scan with your phone...")
            
            # Wait for successful login (chat panel appears)
            WebDriverWait(self.driver, WHATSAPP_CONFIG['qr_scan_timeout']).until(
                EC.presence_of_element_located((By.CSS_SELECTOR, WHATSAPP_CONFIG['chat_selector']))
            )
            
            self.logger.info("✅ Successfully logged in to WhatsApp Web")
            return True
            
        except Exception as e:
            self.logger.error(f"❌ QR code login failed: {e}")
            raise WhatsAppLoginError(f"QR code scan failed or timed out: {e}")
    
    def navigate_to_chat(self, chat_name: str) -> bool:
        """
        Navigate to a specific chat.
        
        Args:
            chat_name: Name of the chat to navigate to
            
        Returns:
            True if successfully navigated to chat
        """
        if not self.driver or not self._is_logged_in():
            raise WhatsAppNavigationError("Not logged in to WhatsApp Web")
        
        try:
            self.logger.info(f"Navigating to chat: {chat_name}")
            
            # Search for the chat
            search_box = WebDriverWait(self.driver, 10).until(
                EC.element_to_be_clickable((By.CSS_SELECTOR, '[data-testid="chat-list-search"]'))
            )
            search_box.click()
            search_box.clear()
            search_box.send_keys(chat_name)
            
            # Wait for search results and click the first result
            time.sleep(2)  # Allow search to complete
            
            first_result = WebDriverWait(self.driver, 10).until(
                EC.element_to_be_clickable((By.CSS_SELECTOR, '[data-testid="cell-frame-container"]'))
            )
            first_result.click()
            
            # Wait for chat to load
            WebDriverWait(self.driver, 10).until(
                EC.presence_of_element_located((By.CSS_SELECTOR, WHATSAPP_CONFIG['message_selector']))
            )
            
            self.logger.info(f"✅ Successfully navigated to chat: {chat_name}")
            return True
            
        except Exception as e:
            self.logger.error(f"❌ Failed to navigate to chat {chat_name}: {e}")
            return False
    
    def _cleanup_existing_sessions(self):
        """Kill any existing Chrome processes using our session directory."""
        try:
            session_dir = os.path.abspath(self.session_dir)
            
            # Kill Chrome processes using our session directory
            try:
                result = subprocess.run(
                    ['pkill', '-f', f'user-data-dir={session_dir}'], 
                    capture_output=True, text=True
                )
                if result.returncode == 0:
                    self.logger.info("🧹 Killed existing Chrome processes")
                    time.sleep(2)  # Wait for processes to fully terminate
            except Exception as e:
                self.logger.warning(f"Could not kill existing processes: {e}")
                
        except Exception as e:
            self.logger.warning(f"Session cleanup failed: {e}")
    
    def _cleanup_driver(self):
        """Clean up WebDriver resources."""
        if self.driver:
            try:
                self.driver.quit()
                self.logger.info("WebDriver cleaned up")
            except Exception as e:
                self.logger.warning(f"Error during WebDriver cleanup: {e}")
            finally:
                self.driver = None
                self.is_initialized = False
    
    def restart_driver(self) -> webdriver.Chrome:
        """
        Restart the WebDriver (cleanup and reinitialize).
        
        Returns:
            New WebDriver instance
        """
        self.logger.info("Restarting WebDriver...")
        self._cleanup_driver()
        time.sleep(2)  # Brief pause before restart
        return self.initialize_driver()
    
    def health_check(self) -> dict:
        """
        Perform health check on WebDriver.
        
        Returns:
            Health status dictionary
        """
        status = {
            'driver_initialized': self.is_initialized,
            'driver_alive': False,
            'whatsapp_logged_in': False,
            'current_url': None,
            'session_dir_exists': self.session_dir.exists(),
        }
        
        if self.driver:
            status['driver_alive'] = self.is_driver_alive()
            
            if status['driver_alive']:
                try:
                    status['current_url'] = self.driver.current_url
                    status['whatsapp_logged_in'] = self._is_logged_in()
                except Exception as e:
                    self.logger.warning(f"Health check error: {e}")
        
        return status
    
    def __enter__(self):
        """Context manager entry."""
        return self.initialize_driver()
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit."""
        self._cleanup_driver()
    
    def __del__(self):
        """Destructor - ensure cleanup."""
        self._cleanup_driver()
