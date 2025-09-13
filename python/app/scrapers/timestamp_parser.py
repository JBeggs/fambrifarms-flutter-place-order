#!/usr/bin/env python3
"""
WhatsApp timestamp parsing utilities
Handles extraction and parsing of timestamps from WhatsApp Web HTML
"""

import re
from datetime import datetime, timezone
from typing import Optional, Tuple

from selenium.webdriver.remote.webelement import WebElement
from selenium.webdriver.common.by import By

from ..config.logging_config import LoggerMixin
from ..core.exceptions import TimestampParsingError


class TimestampParser(LoggerMixin):
    """
    Handles parsing of WhatsApp timestamps from various HTML formats.
    
    WhatsApp Web uses different timestamp formats:
    - data-pre-plain-text="[12:46, 27/08/2025] Karl: "
    - Span elements with time text like "12:46"
    - Various CSS selectors for time elements
    """
    
    # Regex patterns for timestamp extraction
    TIMESTAMP_PATTERNS = [
        # [12:46, 27/08/2025] format from data-pre-plain-text
        r'\[(\d{1,2}:\d{2}),\s*(\d{1,2}/\d{1,2}/\d{4})\]',
        # [22:25, 27/08/2025] format
        r'\[(\d{1,2}:\d{2}),\s*(\d{1,2}/\d{1,2}/\d{4})\]',
        # Time only patterns for fallback
        r'(\d{1,2}:\d{2})',
    ]
    
    # CSS selectors for time elements (in order of preference)
    TIME_SELECTORS = [
        '.x1c4vz4f.x2lah0s',           # Primary time selector
        '.x1rg5ohu.x16dsc37',          # Secondary time selector  
        '[data-testid="msg-time"]',    # Message time test ID
        'span[dir="auto"]',            # Generic time span
        '.copyable-text span',         # Time in copyable text
    ]
    
    def extract_timestamp_from_element(self, message_element: WebElement) -> str:
        """
        Extract timestamp from a WhatsApp message element.
        
        Args:
            message_element: Selenium WebElement containing the message
            
        Returns:
            ISO format timestamp string
            
        Raises:
            TimestampParsingError: If timestamp extraction fails
        """
        try:
            # Method 1: Try to extract from data-pre-plain-text attribute
            timestamp = self._extract_from_data_attribute(message_element)
            if timestamp:
                return timestamp
            
            # Method 2: Try to extract from time span elements
            timestamp = self._extract_from_time_elements(message_element)
            if timestamp:
                return timestamp
            
            # Method 3: Fallback to current time with warning
            self.logger.warning("Could not extract timestamp, using current time")
            return datetime.now(timezone.utc).isoformat()
            
        except Exception as e:
            self.logger.error(f"Timestamp extraction failed: {e}")
            raise TimestampParsingError(f"Failed to extract timestamp: {e}")
    
    def _extract_from_data_attribute(self, element: WebElement) -> Optional[str]:
        """Extract timestamp from data-pre-plain-text attribute."""
        try:
            # Look for elements with data-pre-plain-text attribute
            pre_text_elems = element.find_elements(By.CSS_SELECTOR, '[data-pre-plain-text]')
            
            for elem in pre_text_elems:
                pre_text = elem.get_attribute('data-pre-plain-text')
                if not pre_text:
                    continue
                
                # Parse the timestamp from formats like "[12:46, 27/08/2025] Karl: "
                for pattern in self.TIMESTAMP_PATTERNS[:2]:  # Use full date patterns first
                    match = re.search(pattern, pre_text)
                    if match:
                        time_str, date_str = match.groups()
                        return self._parse_whatsapp_datetime(time_str, date_str)
            
            return None
            
        except Exception as e:
            self.logger.debug(f"Could not extract from data attribute: {e}")
            return None
    
    def _extract_from_time_elements(self, element: WebElement) -> Optional[str]:
        """Extract timestamp from time span elements."""
        try:
            # Try each time selector in order of preference
            for selector in self.TIME_SELECTORS:
                time_elems = element.find_elements(By.CSS_SELECTOR, selector)
                
                for time_elem in time_elems:
                    time_text = time_elem.text.strip()
                    
                    if not time_text or 'Edited' in time_text:
                        continue
                    
                    # Check if it looks like a time (contains colon)
                    if ':' in time_text and len(time_text) <= 8:  # e.g., "12:46" or "12:46 PM"
                        # Use current date with extracted time
                        return self._parse_time_with_current_date(time_text)
            
            return None
            
        except Exception as e:
            self.logger.debug(f"Could not extract from time elements: {e}")
            return None
    
    def _parse_whatsapp_datetime(self, time_str: str, date_str: str) -> str:
        """
        Parse WhatsApp date and time strings into ISO format.
        
        Args:
            time_str: Time string like "12:46"
            date_str: Date string like "27/08/2025"
            
        Returns:
            ISO format timestamp string
        """
        try:
            # Parse date (DD/MM/YYYY format)
            day, month, year = map(int, date_str.split('/'))
            
            # Parse time (HH:MM format)
            hour, minute = map(int, time_str.split(':'))
            
            # Create datetime object
            dt = datetime(year, month, day, hour, minute, tzinfo=timezone.utc)
            
            return dt.isoformat()
            
        except Exception as e:
            self.logger.warning(f"Failed to parse WhatsApp datetime {time_str}, {date_str}: {e}")
            raise TimestampParsingError(f"Invalid WhatsApp datetime format: {e}")
    
    def _parse_time_with_current_date(self, time_str: str) -> str:
        """
        Parse time string and combine with current date.
        
        Args:
            time_str: Time string like "12:46"
            
        Returns:
            ISO format timestamp string
        """
        try:
            # Clean up time string
            time_str = time_str.strip()
            
            # Handle 12-hour format (12:46 PM)
            if 'AM' in time_str.upper() or 'PM' in time_str.upper():
                dt = datetime.strptime(time_str.upper(), '%I:%M %p')
                hour, minute = dt.hour, dt.minute
            else:
                # 24-hour format (12:46)
                hour, minute = map(int, time_str.split(':'))
            
            # Use current date with extracted time
            now = datetime.now(timezone.utc)
            dt = datetime(now.year, now.month, now.day, hour, minute, tzinfo=timezone.utc)
            
            return dt.isoformat()
            
        except Exception as e:
            self.logger.warning(f"Failed to parse time {time_str}: {e}")
            # Fallback to current time
            return datetime.now(timezone.utc).isoformat()
    
    def parse_timestamp_string(self, timestamp_str: str) -> Optional[datetime]:
        """
        Parse a timestamp string into a datetime object.
        
        Args:
            timestamp_str: Timestamp string in various formats
            
        Returns:
            Parsed datetime object or None if parsing fails
        """
        if not timestamp_str:
            return None
        
        try:
            # Handle ISO format with Z suffix
            if timestamp_str.endswith('Z'):
                timestamp_str = timestamp_str[:-1] + '+00:00'
            
            # Parse ISO format
            return datetime.fromisoformat(timestamp_str)
            
        except Exception as e:
            self.logger.debug(f"Could not parse timestamp string {timestamp_str}: {e}")
            return None
    
    def validate_timestamp(self, timestamp_str: str) -> bool:
        """
        Validate that a timestamp string is properly formatted.
        
        Args:
            timestamp_str: Timestamp string to validate
            
        Returns:
            True if valid, False otherwise
        """
        try:
            parsed = self.parse_timestamp_string(timestamp_str)
            return parsed is not None
        except:
            return False
    
    def normalize_timestamp(self, timestamp_str: str) -> str:
        """
        Normalize a timestamp string to ISO format with UTC timezone.
        
        Args:
            timestamp_str: Timestamp string to normalize
            
        Returns:
            Normalized ISO format timestamp string
        """
        try:
            dt = self.parse_timestamp_string(timestamp_str)
            if dt:
                # Ensure UTC timezone
                if dt.tzinfo is None:
                    dt = dt.replace(tzinfo=timezone.utc)
                return dt.isoformat()
            else:
                # Fallback to current time
                return datetime.now(timezone.utc).isoformat()
                
        except Exception as e:
            self.logger.warning(f"Could not normalize timestamp {timestamp_str}: {e}")
            return datetime.now(timezone.utc).isoformat()
