#!/bin/bash

# Install Desktop Shortcut for Bulk Stock Take
# This script creates a desktop shortcut for quick access to bulk stock take

echo "Installing Bulk Stock Take Desktop Shortcut..."
echo

# Get the current directory (where the app is located)
APP_DIR="$(cd "$(dirname "$0")" && pwd)"
DESKTOP_FILE="$APP_DIR/Bulk_Stock_Take.desktop"

# Update the desktop file with correct paths
sed -i "s|Exec=.*|Exec=$APP_DIR/bulk_stock_take.sh|g" "$DESKTOP_FILE"
sed -i "s|Icon=.*|Icon=$APP_DIR/web/icons/Icon-192.png|g" "$DESKTOP_FILE"
sed -i "s|Path=.*|Path=$APP_DIR|g" "$DESKTOP_FILE"

# Make sure the desktop file is executable
chmod +x "$DESKTOP_FILE"

# Copy to desktop (if Desktop directory exists)
if [ -d "$HOME/Desktop" ]; then
    cp "$DESKTOP_FILE" "$HOME/Desktop/"
    chmod +x "$HOME/Desktop/Bulk_Stock_Take.desktop"
    
    # Try to mark as trusted (GNOME/Ubuntu method)
    if command -v gio &> /dev/null; then
        gio set "$HOME/Desktop/Bulk_Stock_Take.desktop" metadata::trusted true 2>/dev/null || true
    fi
    
    echo "✅ Desktop shortcut created: $HOME/Desktop/Bulk_Stock_Take.desktop"
    echo "📝 If you see 'Untrusted Application Launcher':"
    echo "   Right-click the desktop icon → 'Allow Launching' or 'Trust and Launch'"
else
    echo "⚠️  Desktop directory not found. You can manually copy the shortcut:"
    echo "   cp '$DESKTOP_FILE' ~/Desktop/"
fi

# Install to applications menu (optional)
APPLICATIONS_DIR="$HOME/.local/share/applications"
if [ -d "$APPLICATIONS_DIR" ]; then
    cp "$DESKTOP_FILE" "$APPLICATIONS_DIR/"
    echo "✅ Application menu entry created: $APPLICATIONS_DIR/Bulk_Stock_Take.desktop"
    
    # Update desktop database
    if command -v update-desktop-database &> /dev/null; then
        update-desktop-database "$APPLICATIONS_DIR"
        echo "✅ Desktop database updated"
    fi
else
    echo "⚠️  Applications directory not found: $APPLICATIONS_DIR"
fi

echo
echo "🎉 Installation complete!"
echo
echo "📋 IMPORTANT - First Time Setup:"
echo "If you see 'Untrusted Application Launcher' when clicking the desktop icon:"
echo
echo "Method 1 (Easiest):"
echo "• Right-click the desktop icon"
echo "• Select 'Allow Launching' or 'Trust and Launch'"
echo
echo "Method 2 (Command line):"
echo "• Run: gio set ~/Desktop/Bulk_Stock_Take.desktop metadata::trusted true"
echo
echo "Method 3 (File manager):"
echo "• Open file manager, go to Desktop folder"
echo "• Right-click Bulk_Stock_Take.desktop → Properties"
echo "• Check 'Allow executing file as program'"
echo
echo "✅ After trusting, you can:"
echo "1. Double-click the desktop shortcut to launch bulk stock take"
echo "2. Find 'Bulk Stock Take' in your applications menu"
echo "3. Pin it to your taskbar/dock for even quicker access"
echo
echo "🚀 The shortcut will:"
echo "• Open directly to bulk stock take (bypassing main app)"
echo "• Handle authentication automatically"
echo "• Close the app when stock take is complete"
