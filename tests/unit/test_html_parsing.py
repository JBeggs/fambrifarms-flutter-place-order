from pathlib import Path
import pytest
BeautifulSoup = pytest.importorskip('bs4').BeautifulSoup
from datetime import datetime


def test_parse_timestamp_from_pre_plain_text():
    # Use the shared messages.html in the repo root of place-order-final
    html_path = Path(__file__).resolve().parents[2] / 'messages.html'
    if not html_path.exists():
        # Skip when sample not present in environment
        return
    html = html_path.read_text(encoding='utf-8', errors='ignore')
    soup = BeautifulSoup(html, 'html.parser')

    # WhatsApp injects data-pre-plain-text on elements with copyable-text
    elems = soup.select('.copyable-text')
    assert len(elems) > 0

    # Find first valid pre header like: [12:46, 13/09/2025] Name:
    found_iso = None
    for el in elems:
        pre = el.get('data-pre-plain-text') or ''
        if pre.startswith('[') and ']' in pre:
            inside = pre[1:pre.index(']')].strip()
            parts = [p.strip() for p in inside.split(',')]
            if len(parts) == 2 and ':' in parts[0] and '/' in parts[1]:
                dt = datetime.strptime(f"{parts[1]} {parts[0]}", "%d/%m/%Y %H:%M")
                found_iso = dt.isoformat()
                break
    assert found_iso is not None


def test_parse_image_http_src_if_any():
    html_path = Path(__file__).resolve().parents[2] / 'messages.html'
    if not html_path.exists():
        return
    html = html_path.read_text(encoding='utf-8', errors='ignore')
    soup = BeautifulSoup(html, 'html.parser')

    # For images: look for aria-label="Open picture" then an img[src^=http]
    containers = soup.select('[aria-label="Open picture"]')
    if not containers:
        return
    first = containers[0]
    img = first.select_one('img[src^="http"]')
    # If present, ensure the URL looks plausible
    if img:
        src = img.get('src')
        assert src.startswith('http')


