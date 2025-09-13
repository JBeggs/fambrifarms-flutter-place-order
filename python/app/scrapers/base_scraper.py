#!/usr/bin/env python3
"""
Base scraper class for WhatsApp message extraction
Provides common functionality for all scraper implementations
"""

from abc import ABC, abstractmethod
from typing import List, Dict, Any, Optional
from datetime import datetime

from ..config.logging_config import LoggerMixin
from ..core.webdriver_manager import WebDriverManager
from ..core.exceptions import ScrapingError


class BaseScraper(LoggerMixin, ABC):
    """
    Abstract base class for WhatsApp scrapers.
    
    Provides common functionality and interface for all scraper implementations.
    """
    
    def __init__(self, webdriver_manager: WebDriverManager):
        self.webdriver_manager = webdriver_manager
        self.messages: List[Dict[str, Any]] = []
        self.last_scrape_time: Optional[datetime] = None
    
    @abstractmethod
    def scrape_messages(self, chat_name: str = None, limit: int = None) -> List[Dict[str, Any]]:
        """
        Scrape messages from WhatsApp Web.
        
        Args:
            chat_name: Name of chat to scrape (None for current chat)
            limit: Maximum number of messages to scrape
            
        Returns:
            List of message dictionaries
            
        Raises:
            ScrapingError: If scraping fails
        """
        pass
    
    @abstractmethod
    def scroll_to_load_messages(self) -> int:
        """
        Scroll through chat to load all available messages.
        
        Returns:
            Number of messages loaded
        """
        pass
    
    def get_messages(self) -> List[Dict[str, Any]]:
        """
        Get the last scraped messages.
        
        Returns:
            List of message dictionaries
        """
        return self.messages.copy()
    
    def clear_messages(self):
        """Clear the stored messages."""
        self.messages.clear()
        self.logger.info("Cleared stored messages")
    
    def get_scrape_stats(self) -> Dict[str, Any]:
        """
        Get statistics about the last scrape operation.
        
        Returns:
            Dictionary with scrape statistics
        """
        return {
            'total_messages': len(self.messages),
            'last_scrape_time': self.last_scrape_time.isoformat() if self.last_scrape_time else None,
            'message_types': self._count_message_types(),
            'date_range': self._get_date_range(),
        }
    
    def _count_message_types(self) -> Dict[str, int]:
        """Count messages by type."""
        type_counts = {}
        for message in self.messages:
            msg_type = message.get('message_type', 'unknown')
            type_counts[msg_type] = type_counts.get(msg_type, 0) + 1
        return type_counts
    
    def _get_date_range(self) -> Dict[str, Optional[str]]:
        """Get the date range of scraped messages."""
        if not self.messages:
            return {'earliest': None, 'latest': None}
        
        timestamps = [msg.get('timestamp') for msg in self.messages if msg.get('timestamp')]
        if not timestamps:
            return {'earliest': None, 'latest': None}
        
        return {
            'earliest': min(timestamps),
            'latest': max(timestamps)
        }
    
    def validate_message(self, message: Dict[str, Any]) -> bool:
        """
        Validate a message dictionary has required fields.
        
        Args:
            message: Message dictionary to validate
            
        Returns:
            True if valid, False otherwise
        """
        required_fields = ['id', 'sender', 'content', 'timestamp']
        
        for field in required_fields:
            if field not in message or message[field] is None:
                self.logger.warning(f"Message missing required field: {field}")
                return False
        
        return True
    
    def deduplicate_messages(self, messages: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Remove duplicate messages based on ID and content.
        
        Args:
            messages: List of messages to deduplicate
            
        Returns:
            Deduplicated list of messages
        """
        seen_ids = set()
        seen_content = set()
        unique_messages = []
        
        for message in messages:
            msg_id = message.get('id')
            content = message.get('content', '')
            sender = message.get('sender', '')
            timestamp = message.get('timestamp', '')
            
            # Create a composite key for content-based deduplication
            content_key = f"{sender}:{content}:{timestamp}"
            
            # Skip if we've seen this ID or exact content
            if msg_id in seen_ids or content_key in seen_content:
                self.logger.debug(f"Skipping duplicate message: {msg_id}")
                continue
            
            seen_ids.add(msg_id)
            seen_content.add(content_key)
            unique_messages.append(message)
        
        if len(unique_messages) < len(messages):
            self.logger.info(f"Removed {len(messages) - len(unique_messages)} duplicate messages")
        
        return unique_messages
    
    def filter_messages_by_date(self, messages: List[Dict[str, Any]], 
                               start_date: datetime = None, 
                               end_date: datetime = None) -> List[Dict[str, Any]]:
        """
        Filter messages by date range.
        
        Args:
            messages: List of messages to filter
            start_date: Earliest date to include
            end_date: Latest date to include
            
        Returns:
            Filtered list of messages
        """
        if not start_date and not end_date:
            return messages
        
        filtered_messages = []
        
        for message in messages:
            timestamp_str = message.get('timestamp')
            if not timestamp_str:
                continue
            
            try:
                # Parse timestamp
                if timestamp_str.endswith('Z'):
                    timestamp_str = timestamp_str[:-1] + '+00:00'
                
                msg_datetime = datetime.fromisoformat(timestamp_str.replace('Z', '+00:00'))
                
                # Check date range
                if start_date and msg_datetime < start_date:
                    continue
                if end_date and msg_datetime > end_date:
                    continue
                
                filtered_messages.append(message)
                
            except Exception as e:
                self.logger.warning(f"Could not parse timestamp {timestamp_str}: {e}")
                continue
        
        if len(filtered_messages) < len(messages):
            self.logger.info(f"Filtered {len(messages) - len(filtered_messages)} messages by date")
        
        return filtered_messages
