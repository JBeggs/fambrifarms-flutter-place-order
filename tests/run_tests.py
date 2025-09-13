#!/usr/bin/env python3
"""
Test runner for the WhatsApp order processing system.
Runs unit tests, integration tests, and generates coverage reports.
"""

import os
import sys
import unittest
import argparse
import subprocess
from pathlib import Path

# Add project root to path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root / 'python'))


def run_unit_tests(verbose=False):
    """Run unit tests."""
    print("🧪 Running Unit Tests...")
    
    # Discover and run unit tests
    loader = unittest.TestLoader()
    start_dir = str(Path(__file__).parent / 'unit')
    suite = loader.discover(start_dir, pattern='test_*.py')
    
    runner = unittest.TextTestRunner(verbosity=2 if verbose else 1)
    result = runner.run(suite)
    
    return result.wasSuccessful()


def run_integration_tests(verbose=False):
    """Run integration tests."""
    print("🔗 Running Integration Tests...")
    
    # Set environment variable for integration tests
    os.environ['INTEGRATION_TESTS'] = 'true'
    
    loader = unittest.TestLoader()
    start_dir = str(Path(__file__).parent / 'integration')
    suite = loader.discover(start_dir, pattern='test_*.py')
    
    runner = unittest.TextTestRunner(verbosity=2 if verbose else 1)
    result = runner.run(suite)
    
    return result.wasSuccessful()


def run_media_tests(verbose=False):
    """Run media-specific tests using the real HTML data."""
    print("📷 Running Media Detection Tests...")
    
    # Create a specific test for media detection using messages.html
    test_script = f"""
import sys
import os
sys.path.insert(0, '{project_root / 'python'}')

from whatsapp_server import WhatsAppScraper
import json

def test_real_html_media_detection():
    '''Test media detection on real WhatsApp HTML.'''
    
    # Read the actual messages.html file
    html_file = '{project_root / 'messages.html'}'
    if not os.path.exists(html_file):
        print("❌ messages.html not found")
        return False
    
    with open(html_file, 'r', encoding='utf-8') as f:
        html_content = f.read()
    
    # Test that we can find image URLs
    image_urls = []
    voice_durations = []
    
    # Look for WhatsApp CDN URLs
    import re
    cdn_pattern = r'https://media-[^"]*whatsapp\.net[^"]*'
    image_urls = re.findall(cdn_pattern, html_content)
    
    # Look for voice message durations
    duration_pattern = r'aria-valuetext="[^"]*([0-9]+:[0-9]+)[^"]*"'
    voice_matches = re.findall(duration_pattern, html_content)
    
    print(f"📊 Found {{len(image_urls)}} image URLs")
    print(f"🎵 Found {{len(voice_matches)}} voice messages")
    
    if image_urls:
        print(f"📷 Sample image URL: {{image_urls[0][:80]}}...")
    
    if voice_matches:
        print(f"🎵 Sample voice duration: {{voice_matches[0]}}")
    
    # Test should pass if we found any media
    success = len(image_urls) > 0 or len(voice_matches) > 0
    
    if success:
        print("✅ Media detection test PASSED")
    else:
        print("❌ Media detection test FAILED - no media found")
    
    return success

if __name__ == '__main__':
    success = test_real_html_media_detection()
    sys.exit(0 if success else 1)
"""
    
    # Write and run the test script
    test_file = Path(__file__).parent / 'temp_media_test.py'
    with open(test_file, 'w') as f:
        f.write(test_script)
    
    try:
        result = subprocess.run([sys.executable, str(test_file)], 
                              capture_output=not verbose, text=True)
        
        if verbose and result.stdout:
            print(result.stdout)
        if result.stderr:
            print(result.stderr)
            
        return result.returncode == 0
    finally:
        # Clean up temp file
        if test_file.exists():
            test_file.unlink()


def check_system_health():
    """Check system health before running tests."""
    print("🏥 Checking System Health...")
    
    health_checks = []
    
    # Check if messages.html exists
    messages_file = project_root / 'messages.html'
    if messages_file.exists():
        print("✅ messages.html found")
        health_checks.append(True)
    else:
        print("❌ messages.html not found")
        health_checks.append(False)
    
    # Check if Python dependencies are available
    try:
        import selenium
        print("✅ Selenium available")
        health_checks.append(True)
    except ImportError:
        print("❌ Selenium not available")
        health_checks.append(False)
    
    try:
        import requests
        print("✅ Requests available")
        health_checks.append(True)
    except ImportError:
        print("❌ Requests not available")
        health_checks.append(False)
    
    # Check if Chrome is available (basic check)
    try:
        result = subprocess.run(['which', 'google-chrome'], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            print("✅ Chrome browser found")
            health_checks.append(True)
        else:
            print("❌ Chrome browser not found")
            health_checks.append(False)
    except:
        print("❌ Could not check Chrome availability")
        health_checks.append(False)
    
    return all(health_checks)


def main():
    """Main test runner."""
    parser = argparse.ArgumentParser(description='Run WhatsApp order processing tests')
    parser.add_argument('--unit', action='store_true', help='Run unit tests only')
    parser.add_argument('--integration', action='store_true', help='Run integration tests only')
    parser.add_argument('--media', action='store_true', help='Run media tests only')
    parser.add_argument('--health', action='store_true', help='Run health checks only')
    parser.add_argument('--verbose', '-v', action='store_true', help='Verbose output')
    parser.add_argument('--all', action='store_true', help='Run all tests (default)')
    
    args = parser.parse_args()
    
    # Default to running all tests if no specific test type is specified
    if not any([args.unit, args.integration, args.media, args.health]):
        args.all = True
    
    print("🚀 WhatsApp Order Processing System - Test Suite")
    print("=" * 50)
    
    results = []
    
    # Always run health checks first
    if args.health or args.all:
        health_ok = check_system_health()
        results.append(('Health Checks', health_ok))
        print()
    
    # Run unit tests
    if args.unit or args.all:
        unit_success = run_unit_tests(args.verbose)
        results.append(('Unit Tests', unit_success))
        print()
    
    # Run media tests
    if args.media or args.all:
        media_success = run_media_tests(args.verbose)
        results.append(('Media Tests', media_success))
        print()
    
    # Run integration tests (only if explicitly requested or all)
    if args.integration or (args.all and os.getenv('RUN_INTEGRATION_TESTS') == 'true'):
        integration_success = run_integration_tests(args.verbose)
        results.append(('Integration Tests', integration_success))
        print()
    
    # Print summary
    print("📊 Test Results Summary")
    print("=" * 30)
    
    all_passed = True
    for test_name, passed in results:
        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"{test_name}: {status}")
        if not passed:
            all_passed = False
    
    print()
    if all_passed:
        print("🎉 All tests passed!")
        return 0
    else:
        print("💥 Some tests failed!")
        return 1


if __name__ == '__main__':
    sys.exit(main())
