import os
import unittest
from pathlib import Path

try:
    from bs4 import BeautifulSoup
except ImportError:  # pragma: no cover
    BeautifulSoup = None

# Load environment from .env if present (fail fast expectation still applies if missing)
try:
    from dotenv import load_dotenv  # type: ignore
    load_dotenv()
except Exception:
    pass

# Make app core importable
import sys
PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT_ROOT / 'python'))

from app.core.whatsapp_crawler import WhatsAppCrawler


class SoupElement:
    def __init__(self, tag):
        self._tag = tag

    @property
    def text(self):
        # Join text nodes with spaces to approximate Selenium .text
        return self._tag.get_text(" ", strip=True)

    def get_attribute(self, key):
        # Map Selenium get_attribute to bs4 get
        return self._tag.get(key) or ''

    def find_elements(self, by, selector):
        # Only CSS selectors are used by the scraper
        # Use bs4 CSS selection within this element
        try:
            results = self._tag.select(selector)
        except Exception:
            results = []
        return [SoupElement(t) for t in results]


class SoupDriver:
    def __init__(self, soup):
        self._soup = soup

    def find_elements(self, by, selector):
        try:
            results = self._soup.select(selector)
        except Exception:
            results = []
        return [SoupElement(t) for t in results]

    # Selenium compatibility used by _scroll_to_load_all_messages
    def execute_script(self, script, element):  # no-op in tests
        return None


@unittest.skipIf(BeautifulSoup is None, "bs4 not installed; skipping HTML-based scraper tests")
class ScraperMessagesHtmlTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        html_path = PROJECT_ROOT / 'messages.html'
        if not html_path.exists():
            raise unittest.SkipTest("messages.html not found; attach file to run these tests")
        cls.html = html_path.read_text(encoding='utf-8', errors='ignore')
        cls.soup = BeautifulSoup(cls.html, 'html.parser')
        # Ensure required env is present
        if 'TARGET_GROUP_NAME' not in os.environ:
            raise unittest.SkipTest("TARGET_GROUP_NAME not set; define it in env or .env for tests")

    def setUp(self):
        # Build a crawler with a Soup-backed driver and call the internal scrape on the open chat
        self.crawler = WhatsAppCrawler()
        self.crawler.driver = SoupDriver(self.soup)

    def test_scrape_returns_messages(self):
        messages = self.crawler._scrape_from_open_chat()
        self.assertIsInstance(messages, list)
        self.assertGreater(len(messages), 0, "No messages were scraped from messages.html")

        # Basic schema checks on a sample
        sample = messages[0]
        for key in [
            'id','chat','sender','content','cleanedContent','timestamp',
            'scraped_at','message_type','items','instructions','media_type','media_url','media_info'
        ]:
            self.assertIn(key, sample)

    def test_images_have_http_media_urls(self):
        msgs = self.crawler._scrape_from_open_chat()
        image_msgs = [m for m in msgs if m.get('media_type') == 'image']
        for m in image_msgs:
            url = (m.get('media_url') or '').strip()
            self.assertTrue(url.startswith('http'), f"Image media_url must be http(s), got: {url}")

    def test_no_blob_urls_persisted_as_images(self):
        msgs = self.crawler._scrape_from_open_chat()
        for m in msgs:
            if m.get('media_type') == 'image':
                self.assertFalse((m.get('media_url') or '').startswith('blob:'), 'blob: URLs should not be persisted as image media_url')

    def test_voice_messages_detected_with_duration_if_present(self):
        msgs = self.crawler._scrape_from_open_chat()
        voice_msgs = [m for m in msgs if m.get('message_type') == 'voice']
        # Not all datasets include voice, so only assert duration format when present
        for m in voice_msgs:
            info = (m.get('media_info') or '')
            self.assertIn(':', info, f"Expected mm:ss-like duration in media_info, got: {info}")

    def test_timestamps_are_iso_strings(self):
        msgs = self.crawler._scrape_from_open_chat()
        for m in msgs[:50]:  # sample
            ts = m.get('timestamp')
            self.assertIsInstance(ts, str)
            # Minimal ISO sanity check
            self.assertIn('T', ts)

    def test_text_is_deduplicated_per_row(self):
        msgs = self.crawler._scrape_from_open_chat()
        # Ensure no immediate duplicate lines after join
        for m in msgs[:50]:
            lines = [ln.strip() for ln in (m.get('content') or '').split('\n') if ln.strip()]
            for a, b in zip(lines, lines[1:]):
                self.assertNotEqual(a, b, f"Consecutive duplicate lines found in message content: {a}")


if __name__ == '__main__':
    unittest.main()


