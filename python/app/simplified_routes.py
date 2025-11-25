from flask import Flask, jsonify, request
import threading
import time
import os
from .simplified_whatsapp_crawler import SimplifiedWhatsAppCrawler

app = Flask(__name__)

# Global crawler instance
crawler = None
crawler_thread = None

@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'crawler_running': crawler.is_running if crawler else False,
        'timestamp': time.time()
    })

@app.route('/api/whatsapp/start', methods=['POST'])
def start_whatsapp():
    """Start the simplified WhatsApp crawler"""
    global crawler, crawler_thread
    
    try:
        if crawler and crawler.is_running:
            return jsonify({
                'status': 'already_running',
                'message': 'WhatsApp crawler is already running'
            })
        
        # Get Django URL from request, environment variable, or use default
        data = request.get_json() or {}
        django_url = data.get('django_url') or os.environ.get('DJANGO_BASE_URL') or os.environ.get('DJANGO_URL') or os.environ.get('PROD_DJANGO_URL') or 'http://localhost:8000'
        
        # Strip trailing /api if present (crawler adds /api/whatsapp/receive-html/)
        if django_url.endswith('/api'):
            django_url = django_url[:-4]
        check_interval = data.get('check_interval', 30)
        
        print(f"🚀 Starting simplified WhatsApp crawler...")
        print(f"📡 Django URL: {django_url}")
        print(f"⏰ Check interval: {check_interval}s")
        
        # Create new crawler instance
        crawler = SimplifiedWhatsAppCrawler(django_url=django_url)
        
        # Start WhatsApp session
        if not crawler.start_whatsapp_session():
            return jsonify({
                'status': 'error',
                'message': 'Failed to start WhatsApp session'
            }), 500
        
        # Start periodic checking in background thread
        def run_crawler():
            try:
                crawler.run_periodic_check(check_interval=check_interval)
            except Exception as e:
                print(f"❌ Crawler thread error: {e}")
        
        crawler_thread = threading.Thread(target=run_crawler, daemon=True)
        crawler_thread.start()
        
        return jsonify({
            'status': 'started',
            'message': 'WhatsApp crawler started successfully',
            'django_url': django_url,
            'check_interval': check_interval
        })
        
    except Exception as e:
        print(f"❌ Error starting crawler: {e}")
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

@app.route('/api/whatsapp/stop', methods=['POST'])
def stop_whatsapp():
    """Stop the WhatsApp crawler"""
    global crawler, crawler_thread
    
    try:
        if not crawler or not crawler.is_running:
            return jsonify({
                'status': 'not_running',
                'message': 'WhatsApp crawler is not running'
            })
        
        print("🛑 Stopping WhatsApp crawler...")
        crawler.stop()
        
        # Wait for thread to finish (with timeout)
        if crawler_thread and crawler_thread.is_alive():
            crawler_thread.join(timeout=5)
        
        crawler = None
        crawler_thread = None
        
        return jsonify({
            'status': 'stopped',
            'message': 'WhatsApp crawler stopped successfully'
        })
        
    except Exception as e:
        print(f"❌ Error stopping crawler: {e}")
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

@app.route('/api/whatsapp/status', methods=['GET'])
def get_status():
    """Get crawler status"""
    global crawler
    
    if not crawler:
        return jsonify({
            'status': 'not_initialized',
            'running': False,
            'message': 'Crawler not initialized'
        })
    
    return jsonify({
        'status': 'initialized',
        'running': crawler.is_running,
        'last_message_count': getattr(crawler, 'last_message_count', 0),
        'session_dir': getattr(crawler, 'session_dir', None)
    })

@app.route('/api/whatsapp/manual-scan', methods=['POST'])
def manual_scan():
    """Manually trigger a message scan"""
    global crawler
    
    try:
        if not crawler or not crawler.is_running:
            return jsonify({
                'status': 'error',
                'message': 'Crawler is not running'
            }), 400
        
        data = request.get_json() or {}
        scroll_to_load_more = data.get('scroll_to_load_more', True)
        days_back = data.get('days_back', 1)  # Default: 1 day (today + yesterday)
        
        print(f"🔍 Manual scan triggered (scroll={scroll_to_load_more}, days_back={days_back})")
        
        # Get messages
        messages = crawler.get_current_messages(scroll_to_load_more=scroll_to_load_more, days_back=days_back)
        
        if messages:
            # Send to Django
            success = crawler.send_to_django(messages)
            
            if success:
                crawler.last_message_count = len(messages)
                return jsonify({
                    'status': 'success',
                    'message_count': len(messages),
                    'sent_to_django': True
                })
            else:
                return jsonify({
                    'status': 'partial_success',
                    'message_count': len(messages),
                    'sent_to_django': False,
                    'message': 'Messages extracted but failed to send to Django'
                })
        else:
            return jsonify({
                'status': 'success',
                'message_count': 0,
                'message': 'No messages found'
            })
            
    except Exception as e:
        print(f"❌ Error during manual scan: {e}")
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

@app.route('/api/debug/test-django', methods=['POST'])
def test_django_connection():
    """Test connection to Django backend"""
    try:
        data = request.get_json() or {}
        django_url = data.get('django_url') or os.environ.get('DJANGO_BASE_URL') or os.environ.get('DJANGO_URL') or 'http://localhost:8000'
        
        # Test with a dummy message
        test_message = {
            'id': f'test_{int(time.time())}',
            'chat': 'TEST',
            'html': '<div class="copyable-text">Test message from Python crawler</div>',
            'timestamp': time.time(),
            'message_data': {
                'was_expanded': False,
                'expansion_failed': False
            }
        }
        
        import requests
        url = f"{django_url}/api/whatsapp/receive-html/"
        response = requests.post(url, json={'messages': [test_message]}, timeout=10)
        
        if response.status_code == 200:
            return jsonify({
                'status': 'success',
                'django_url': django_url,
                'response': response.json()
            })
        else:
            return jsonify({
                'status': 'error',
                'django_url': django_url,
                'status_code': response.status_code,
                'response': response.text
            }), 400
            
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

if __name__ == '__main__':
    print("🚀 Starting Simplified WhatsApp Crawler API...")
    print("📡 Available endpoints:")
    print("  POST /api/whatsapp/start - Start crawler")
    print("  POST /api/whatsapp/stop - Stop crawler") 
    print("  GET  /api/whatsapp/status - Get status")
    print("  POST /api/whatsapp/manual-scan - Manual scan")
    print("  POST /api/debug/test-django - Test Django connection")
    print("  GET  /api/health - Health check")
    
    app.run(host='0.0.0.0', port=5001, debug=True)

