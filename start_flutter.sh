#!/bin/bash

# Start Flutter app with correct API configuration
echo "🚀 Starting Flutter app with correct API configuration..."
echo "📡 Django API: http://localhost:8000/api"
echo "🐍 Python API: http://localhost:5001/api"

flutter run \
  --dart-define=DJANGO_URL=http://localhost:8000/api \
  --dart-define=PYTHON_API_URL=http://localhost:5001/api \
  --web-port=3000
