#!/usr/bin/env python3
"""
Configuration settings for WhatsApp Order Processing System
Centralized configuration management with environment variable support
"""

import os
from pathlib import Path

# Base paths
PROJECT_ROOT = Path(__file__).parent.parent.parent
WHATSAPP_SESSION_DIR = PROJECT_ROOT / "whatsapp-session"

# Chrome/WebDriver Configuration
CHROME_CONFIG = {
    'headless': os.getenv('CHROME_HEADLESS', 'false').lower() == 'true',
    'user_data_dir': str(WHATSAPP_SESSION_DIR),
    'window_size': os.getenv('CHROME_WINDOW_SIZE', '1200,800'),
    'disable_gpu': True,
    'no_sandbox': True,
    'disable_dev_shm_usage': True,
    'disable_extensions': True,
    'disable_plugins': True,
    'disable_images': False,  # Keep images for media detection
    'disable_javascript': False,  # Need JS for WhatsApp Web
}

# WhatsApp Web Configuration
WHATSAPP_CONFIG = {
    'base_url': 'https://web.whatsapp.com',
    'chat_selector': '[data-testid="conversation-panel-messages"]',
    'message_selector': '[data-testid="msg-container"]',
    'scroll_pause_time': 2,
    'max_scroll_attempts': 50,
    'message_load_timeout': 30,
    'qr_scan_timeout': 60,
}

# Message Classification Patterns
MESSAGE_PATTERNS = {
    'order_keywords': [
        'order', 'please send', 'i need', 'can i get', 'may i order',
        'hi here is my order', 'good morning', 'hie pliz send'
    ],
    'stock_keywords': [
        'stock', 'available', 'do you have', 'in stock', 'availability'
    ],
    'instruction_keywords': [
        'note', 'instruction', 'please', 'remember', 'important'
    ],
    'company_indicators': [
        'for', 'send for', 'deliver to', 'order for'
    ]
}

# Quantity Detection Patterns
QUANTITY_PATTERNS = [
    r'(\d+)\s*x\s*(\w+)',           # "3x tomatoes"
    r'(\d+)\s*\*\s*(\w+)',          # "3*packets"  
    r'(\d+)\s*×\s*(\w+)',           # "3×5kg"
    r'(\w+)\s+(\d+)\s*(kg|g|l|ml)', # "bananas 2kg"
    r'(\d+)\s*(kg|g|l|ml|box|packet|punnet|head|bag)', # "10kg", "3box"
]

# Media Detection Configuration
MEDIA_CONFIG = {
    'image_selectors': [
        'img[src*="media-"][src*="whatsapp.net"]',  # WhatsApp CDN (priority)
        'img[src*="blob:"]',                        # Blob URLs
        'img[src*="data:image"]',                   # Base64 images
        'img.x15kfjtz',                            # WhatsApp image class
        'img[src*="https://"]',                    # Standard URLs
    ],
    'voice_selectors': [
        '[data-testid="audio-play"]',
        '[aria-label="Play voice message"]',
        'canvas[width="200"][height="24"]',  # Voice waveform
    ],
    'video_selectors': [
        '[data-testid="video-thumb"]',
        'video',
    ],
    'document_selectors': [
        '[data-testid="document-thumb"]',
        '[data-icon="document"]',
    ],
    'sticker_selectors': [
        '[data-testid="sticker"]',
        'img[src*="sticker"]',
    ],
    'url_priority_scores': {
        'whatsapp.net': 100,
        'media-': 90,
        'blob:': 80,
        'data:image': 70,
        'https://': 60,
        'http://': 50,
    }
}

# API Configuration
API_CONFIG = {
    'host': os.getenv('API_HOST', '0.0.0.0'),
    'port': int(os.getenv('API_PORT', 5000)),
    'debug': os.getenv('API_DEBUG', 'false').lower() == 'true',
    'cors_origins': os.getenv('CORS_ORIGINS', '*').split(','),
}

# Django Integration Configuration
DJANGO_CONFIG = {
    'base_url': os.getenv('DJANGO_BASE_URL', 'http://localhost:8000'),
    'api_endpoints': {
        'receive_messages': '/api/whatsapp/receive-messages/',
        'get_messages': '/api/whatsapp/messages/',
        'health': '/health/',
    },
    'timeout': int(os.getenv('DJANGO_TIMEOUT', 30)),
    'retry_attempts': int(os.getenv('DJANGO_RETRY_ATTEMPTS', 3)),
    'retry_delay': float(os.getenv('DJANGO_RETRY_DELAY', 1.0)),
}

# Logging Configuration
LOGGING_CONFIG = {
    'level': os.getenv('LOG_LEVEL', 'INFO'),
    'format': '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    'file_path': PROJECT_ROOT / 'logs' / 'whatsapp_server.log',
    'max_file_size': int(os.getenv('LOG_MAX_FILE_SIZE', 10 * 1024 * 1024)),  # 10MB
    'backup_count': int(os.getenv('LOG_BACKUP_COUNT', 5)),
}

# Performance Configuration
PERFORMANCE_CONFIG = {
    'max_messages_per_request': int(os.getenv('MAX_MESSAGES_PER_REQUEST', 100)),
    'scroll_delay': float(os.getenv('SCROLL_DELAY', 0.5)),
    'element_wait_timeout': int(os.getenv('ELEMENT_WAIT_TIMEOUT', 10)),
    'page_load_timeout': int(os.getenv('PAGE_LOAD_TIMEOUT', 30)),
    'implicit_wait': int(os.getenv('IMPLICIT_WAIT', 10)),
}

# Development/Testing Configuration
DEV_CONFIG = {
    'mock_chrome': os.getenv('MOCK_CHROME', 'false').lower() == 'true',
    'test_mode': os.getenv('TEST_MODE', 'false').lower() == 'true',
    'debug_screenshots': os.getenv('DEBUG_SCREENSHOTS', 'false').lower() == 'true',
    'screenshot_dir': PROJECT_ROOT / 'debug_screenshots',
}

def get_chrome_options():
    """Get Chrome options based on configuration."""
    from selenium.webdriver.chrome.options import Options
    options = Options()
    
    if CHROME_CONFIG['headless']:
        options.add_argument('--headless')
    
    options.add_argument(f'--user-data-dir={CHROME_CONFIG["user_data_dir"]}')
    options.add_argument(f'--window-size={CHROME_CONFIG["window_size"]}')
    
    if CHROME_CONFIG['disable_gpu']:
        options.add_argument('--disable-gpu')
    
    if CHROME_CONFIG['no_sandbox']:
        options.add_argument('--no-sandbox')
    
    if CHROME_CONFIG['disable_dev_shm_usage']:
        options.add_argument('--disable-dev-shm-usage')
    
    if CHROME_CONFIG['disable_extensions']:
        options.add_argument('--disable-extensions')
    
    if CHROME_CONFIG['disable_plugins']:
        options.add_argument('--disable-plugins')
    
    # Additional stability options
    options.add_argument('--disable-background-timer-throttling')
    options.add_argument('--disable-backgrounding-occluded-windows')
    options.add_argument('--disable-renderer-backgrounding')
    options.add_argument('--disable-features=TranslateUI')
    options.add_argument('--disable-ipc-flooding-protection')
    
    return options

def ensure_directories():
    """Ensure required directories exist."""
    directories = [
        WHATSAPP_SESSION_DIR,
        LOGGING_CONFIG['file_path'].parent,
        DEV_CONFIG['screenshot_dir'],
    ]
    
    for directory in directories:
        directory.mkdir(parents=True, exist_ok=True)

def validate_config():
    """Validate configuration settings."""
    errors = []
    
    # Check required directories are writable
    try:
        ensure_directories()
    except Exception as e:
        errors.append(f"Cannot create required directories: {e}")
    
    # Validate port range
    if not (1024 <= API_CONFIG['port'] <= 65535):
        errors.append(f"API port {API_CONFIG['port']} is not in valid range (1024-65535)")
    
    # Validate timeout values
    if DJANGO_CONFIG['timeout'] <= 0:
        errors.append("Django timeout must be positive")
    
    if PERFORMANCE_CONFIG['scroll_delay'] < 0:
        errors.append("Scroll delay cannot be negative")
    
    if errors:
        raise ValueError(f"Configuration validation failed: {'; '.join(errors)}")

# Initialize configuration on import
try:
    validate_config()
except Exception as e:
    print(f"⚠️ Configuration warning: {e}")
