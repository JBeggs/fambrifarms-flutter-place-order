#!/bin/bash
# WhatsApp Server Launcher Script

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_DIR="$(dirname "$SCRIPT_DIR")"
VENV_DIR="$APP_DIR/../venv"

echo "🚀 Starting WhatsApp Server..."
echo "📁 Script directory: $SCRIPT_DIR"
echo "📁 App directory: $APP_DIR"
echo "📁 Venv directory: $VENV_DIR"

# Check if venv exists
if [ ! -d "$VENV_DIR" ]; then
    echo "❌ Virtual environment not found at: $VENV_DIR"
    echo "Please create it first with: python3 -m venv $VENV_DIR"
    read -p "Press Enter to exit..."
    exit 1
fi

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source "$VENV_DIR/bin/activate"

# Change to python directory
cd "$SCRIPT_DIR"

# Check if main.py exists
if [ ! -f "main.py" ]; then
    echo "❌ main.py not found in: $SCRIPT_DIR"
    read -p "Press Enter to exit..."
    exit 1
fi

# Run the server
echo "▶️  Running WhatsApp Server..."
python main.py

# Keep terminal open if there's an error
if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Server exited with error"
    read -p "Press Enter to exit..."
fi

