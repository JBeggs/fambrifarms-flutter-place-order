#!/bin/bash

# Flutter Local Development Script
# Connects Flutter app to local Django backend

echo "🚀 Starting Flutter app with LOCAL backend configuration..."
echo "📡 Django API: http://localhost:8000/api"
echo "🔧 Environment: development"
echo ""

# Run Flutter with local backend configuration
flutter run \
  --dart-define=DJANGO_URL=http://localhost:8000/api \
  --dart-define=PYTHON_API_URL=http://localhost:8000/api \
  --dart-define=FLUTTER_ENV=development \
  --dart-define=ENABLE_DEBUG_LOGGING=true \
  --dart-define=API_TIMEOUT_SECONDS=60 \
  --web-port=3000
