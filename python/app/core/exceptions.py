#!/usr/bin/env python3
"""
Custom exceptions for WhatsApp Order Processing System
Provides specific exception types for better error handling and debugging
"""

class WhatsAppError(Exception):
    """Base exception for WhatsApp-related errors."""
    pass

class WebDriverError(WhatsAppError):
    """Errors related to Chrome WebDriver management."""
    pass

class WebDriverInitializationError(WebDriverError):
    """Failed to initialize Chrome WebDriver."""
    pass

class WebDriverConnectionError(WebDriverError):
    """Lost connection to Chrome WebDriver."""
    pass

class WebDriverTimeoutError(WebDriverError):
    """WebDriver operation timed out."""
    pass

class WhatsAppWebError(WhatsAppError):
    """Errors related to WhatsApp Web interface."""
    pass

class WhatsAppLoginError(WhatsAppWebError):
    """Failed to login to WhatsApp Web (QR code scan failed)."""
    pass

class WhatsAppNavigationError(WhatsAppWebError):
    """Failed to navigate to WhatsApp Web or chat."""
    pass

class WhatsAppElementNotFoundError(WhatsAppWebError):
    """Required WhatsApp Web element not found."""
    pass

class ScrapingError(WhatsAppError):
    """Errors during message scraping process."""
    pass

class MessageParsingError(ScrapingError):
    """Failed to parse message content."""
    pass

class MediaExtractionError(ScrapingError):
    """Failed to extract media URLs or information."""
    pass

class TimestampParsingError(ScrapingError):
    """Failed to parse WhatsApp timestamp."""
    pass

class APIError(WhatsAppError):
    """Errors related to API operations."""
    pass

class DjangoIntegrationError(APIError):
    """Failed to communicate with Django backend."""
    pass

class FlutterIntegrationError(APIError):
    """Failed to communicate with Flutter app."""
    pass

class ConfigurationError(WhatsAppError):
    """Configuration-related errors."""
    pass

class InvalidConfigurationError(ConfigurationError):
    """Invalid configuration values."""
    pass

class MissingConfigurationError(ConfigurationError):
    """Required configuration missing."""
    pass
