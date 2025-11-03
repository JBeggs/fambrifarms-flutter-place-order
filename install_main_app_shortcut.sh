#!/bin/bash

# Install Desktop Shortcut for Fambri Farms Main App
# This script creates a desktop shortcut for the main application with authentication

echo "Installing Fambri Farms Main App Desktop Shortcut..."
echo

# Get the current directory (where the app is located)
APP_DIR="$(cd "$(dirname "$0")" && pwd)"

# Create the desktop file content
DESKTOP_FILE_CONTENT="[Desktop Entry]
Version=1.0
Type=Application
Name=Fambri Farms
Comment=Launch Fambri Farms Place Order System
Exec=$APP_DIR/main_app.sh
Icon=$APP_DIR/web/icons/Icon-192.png
Terminal=false
Categories=Office;Business;
Keywords=fambri;farms;orders;inventory;
StartupNotify=true
Path=$APP_DIR"

# Write the desktop file
DESKTOP_FILE="$APP_DIR/Fambri_Farms.desktop"
echo "$DESKTOP_FILE_CONTENT" > "$DESKTOP_FILE"

# Make sure the desktop file is executable
chmod +x "$DESKTOP_FILE"

# Create the main app launcher script
MAIN_APP_SCRIPT="$APP_DIR/main_app.sh"
cat > "$MAIN_APP_SCRIPT" << 'EOF'
#!/bin/bash
# Fambri Farms Main App Desktop Shortcut
# This launches the full app with authentication

echo "Starting Fambri Farms..."
echo

# Change to the app directory
cd "$(dirname "$0")"

# Launch the Flutter app normally (with authentication)
# Try built executable first (fast), then fall back to source (slow)
if [ -f "build/linux/x64/release/bundle/place_order_final" ]; then
    echo "Launching from built executable..."
    ./build/linux/x64/release/bundle/place_order_final
elif command -v flutter &> /dev/null; then
    echo "Built executable not found. Launching from Flutter source (this will be slower)..."
    flutter run -d linux --release
else
    echo "Error: Neither built executable nor Flutter SDK found."
    echo "Please build the app first with: flutter build linux --release"
    echo "Or install Flutter SDK to run from source."
    exit 1
fi

echo "Fambri Farms launched."
EOF

# Make the launcher script executable
chmod +x "$MAIN_APP_SCRIPT"

# Copy to desktop (if Desktop directory exists)
if [ -d "$HOME/Desktop" ]; then
    cp "$DESKTOP_FILE" "$HOME/Desktop/"
    chmod +x "$HOME/Desktop/Fambri_Farms.desktop"
    
    # Try to mark as trusted (GNOME/Ubuntu method)
    if command -v gio &> /dev/null; then
        gio set "$HOME/Desktop/Fambri_Farms.desktop" metadata::trusted true 2>/dev/null || true
    fi
    
    echo "✅ Desktop shortcut created: $HOME/Desktop/Fambri_Farms.desktop"
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
    echo "✅ Application menu entry created: $APPLICATIONS_DIR/Fambri_Farms.desktop"
    
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
echo "• Run: gio set ~/Desktop/Fambri_Farms.desktop metadata::trusted true"
echo
echo "Method 3 (File manager):"
echo "• Open file manager, go to Desktop folder"
echo "• Right-click Fambri_Farms.desktop → Properties"
echo "• Check 'Allow executing file as program'"
echo
echo "✅ After trusting, you can:"
echo "1. Double-click the desktop shortcut to launch Fambri Farms"
echo "2. Find 'Fambri Farms' in your applications menu"
echo "3. Pin it to your taskbar/dock for quick access"
echo
echo "🚀 The shortcut will:"
echo "• Open the full Fambri Farms application"
echo "• Show the normal login screen"
echo "• Provide access to all features (orders, inventory, etc.)"
echo
echo "📦 You now have TWO shortcuts:"
echo "• 'Fambri Farms' - Full app with login"
echo "• 'Bulk Stock Take' - Direct to stock take (bypasses login)"
