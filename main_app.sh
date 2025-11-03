#!/bin/bash
# Fambri Farms Main App Desktop Shortcut
# This launches the full app with authentication

echo "Starting Fambri Farms..."
echo

# Change to the app directory
cd "$(dirname "$0")"

# Launch the Flutter app normally (with authentication)
# Try built executable first (fast), then fall back to source (slow)
if [ -f "build/linux/x64/release/bundle/fambri-farms-order-system" ]; then
    echo "Launching from built executable..."
    ./build/linux/x64/release/bundle/fambri-farms-order-system
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
