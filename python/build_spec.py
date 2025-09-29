# -*- mode: python ; coding: utf-8 -*-
"""
PyInstaller spec file for WhatsApp Crawler
This creates a standalone executable with all dependencies bundled
"""

import os
import sys
from pathlib import Path

# Get the current directory
current_dir = Path(__file__).parent

block_cipher = None

a = Analysis(
    ['main.py'],
    pathex=[str(current_dir)],
    binaries=[],
    datas=[
        ('config', 'config'),
        ('app', 'app'),
    ],
    hiddenimports=[
        'selenium',
        'selenium.webdriver',
        'selenium.webdriver.chrome',
        'selenium.webdriver.chrome.service',
        'selenium.webdriver.chrome.options',
        'selenium.webdriver.common.by',
        'selenium.webdriver.support.ui',
        'selenium.webdriver.support.expected_conditions',
        'selenium.common.exceptions',
        'webdriver_manager',
        'webdriver_manager.chrome',
        'flask',
        'flask_cors',
        'requests',
        'beautifulsoup4',
        'bs4',
        'json',
        'time',
        'datetime',
        'logging',
        'threading',
        'queue',
        'os',
        'sys',
        'pathlib',
        'urllib.parse',
        'urllib.request',
        'http.server',
        'socketserver',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        'tkinter',
        'matplotlib',
        'numpy',
        'pandas',
        'PIL',
        'PyQt5',
        'PyQt6',
        'PySide2',
        'PySide6',
    ],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='WhatsAppCrawler',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,  # Set to False for windowed app
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=None,  # Add icon file path if you have one
)
