#!/bin/bash

# Bulk Stock Take Desktop Shortcut
# This launches the app directly to bulk stock take mode

echo "Starting Bulk Stock Take..."
echo

# Change to the app directory
cd "$(dirname "$0")"

# Launch the Flutter app with bulk stock take argument
# Try built executable first (fast), then fall back to source (slow)
if [ -f "build/linux/x64/release/bundle/fambri-farms-order-system" ]; then
    echo "Launching from built executable..."
    ./build/linux/x64/release/bundle/fambri-farms-order-system --bulk-stock-take
elif command -v flutter &> /dev/null; then
    echo "Built executable not found. Launching from Flutter source (this will be slower)..."
    flutter run -d linux --release --dart-define=BULK_STOCK_TAKE=true
else
    echo "Error: Neither built executable nor Flutter SDK found."
    echo "Please build the app first with: flutter build linux --release"
    echo "Or install Flutter SDK to run from source."
    exit 1
fi

echo "Bulk Stock Take launched."
