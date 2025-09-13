#!/usr/bin/env python3
"""
Main entry point for WhatsApp Order Processing System
Demonstrates the new modular architecture with clean separation of concerns
"""

import sys
from pathlib import Path

# Add the parent directory to the path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from flask import Flask, jsonify
from flask_cors import CORS

from .config.settings import API_CONFIG, validate_config
from .config.logging_config import get_logger
from .core.webdriver_manager import WebDriverManager
from .core.exceptions import WhatsAppError

# Initialize logger
logger = get_logger(__name__)

def create_app() -> Flask:
    """
    Create and configure the Flask application.
    
    Returns:
        Configured Flask app instance
    """
    # Validate configuration
    try:
        validate_config()
        logger.info("✅ Configuration validated successfully")
    except Exception as e:
        logger.error(f"❌ Configuration validation failed: {e}")
        sys.exit(1)
    
    # Create Flask app
    app = Flask(__name__)
    CORS(app, origins=API_CONFIG['cors_origins'])
    
    # Initialize WebDriver manager (singleton pattern)
    webdriver_manager = WebDriverManager()
    
    @app.route('/health', methods=['GET'])
    def health_check():
        """Health check endpoint."""
        try:
            # Check WebDriver health
            driver_health = webdriver_manager.health_check()
            
            health_status = {
                'status': 'healthy' if driver_health['driver_alive'] else 'degraded',
                'timestamp': '2025-09-13T12:00:00Z',  # Current timestamp
                'version': '2.0.0-modular',
                'components': {
                    'webdriver': driver_health,
                    'configuration': 'ok',
                    'logging': 'ok'
                }
            }
            
            status_code = 200 if health_status['status'] == 'healthy' else 503
            return jsonify(health_status), status_code
            
        except Exception as e:
            logger.error(f"Health check failed: {e}")
            return jsonify({
                'status': 'unhealthy',
                'error': str(e),
                'timestamp': '2025-09-13T12:00:00Z'
            }), 500
    
    @app.route('/api/messages', methods=['GET'])
    def get_messages():
        """Get scraped messages (placeholder for now)."""
        try:
            # This will be implemented with the full scraper modules
            return jsonify({
                'messages': [],
                'total': 0,
                'status': 'WebDriver not yet integrated with scrapers',
                'note': 'Modular refactoring in progress - scrapers coming in Phase 2'
            })
        except Exception as e:
            logger.error(f"Get messages failed: {e}")
            return jsonify({'error': str(e)}), 500
    
    @app.route('/api/restart', methods=['POST'])
    def restart_webdriver():
        """Restart the WebDriver."""
        try:
            logger.info("Restarting WebDriver...")
            driver = webdriver_manager.restart_driver()
            
            return jsonify({
                'status': 'success',
                'message': 'WebDriver restarted successfully',
                'driver_alive': webdriver_manager.is_driver_alive()
            })
            
        except WhatsAppError as e:
            logger.error(f"WebDriver restart failed: {e}")
            return jsonify({
                'status': 'error',
                'error': str(e)
            }), 500
    
    @app.errorhandler(WhatsAppError)
    def handle_whatsapp_error(error):
        """Handle WhatsApp-specific errors."""
        logger.error(f"WhatsApp error: {error}")
        return jsonify({
            'error': str(error),
            'type': error.__class__.__name__
        }), 500
    
    @app.errorhandler(Exception)
    def handle_general_error(error):
        """Handle general errors."""
        logger.error(f"Unexpected error: {error}")
        return jsonify({
            'error': 'Internal server error',
            'message': str(error)
        }), 500
    
    return app

def main():
    """Main entry point."""
    logger.info("🚀 Starting WhatsApp Order Processing System (Modular Architecture)")
    logger.info("=" * 60)
    
    try:
        # Create Flask app
        app = create_app()
        
        # Start the server
        logger.info(f"Starting server on {API_CONFIG['host']}:{API_CONFIG['port']}")
        logger.info(f"Debug mode: {API_CONFIG['debug']}")
        
        app.run(
            host=API_CONFIG['host'],
            port=API_CONFIG['port'],
            debug=API_CONFIG['debug']
        )
        
    except KeyboardInterrupt:
        logger.info("👋 Server stopped by user")
    except Exception as e:
        logger.error(f"❌ Server startup failed: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
