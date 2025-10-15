#!/bin/bash

# Flutter Production Connection Script
# Connects Flutter app to production Django backend

echo "🚀 Connecting Flutter app to PRODUCTION backend..."
echo "📡 Production API: https://fambridevops.pythonanywhere.com/api"
echo "🌍 Environment: production"
echo ""

# Check if production API is accessible
echo "🔍 Testing production API connection..."
if curl -s --head https://fambridevops.pythonanywhere.com/api/ | grep -q "200\|405\|404"; then
    echo "✅ Production API is accessible!"
else
    echo "❌ Production API is not accessible. Check your internet connection or backend status."
    exit 1
fi

echo ""
echo "🔧 Starting Flutter app with PRODUCTION configuration..."
echo ""

# Run Flutter with production backend configuration
flutter run \
  --dart-define=DJANGO_URL=https://fambridevops.pythonanywhere.com/api \
  --dart-define=PYTHON_API_URL=https://fambridevops.pythonanywhere.com/api \
  --dart-define=FLUTTER_ENV=production \
  --dart-define=ENABLE_DEBUG_LOGGING=false \
  --dart-define=ENABLE_PERFORMANCE_MONITORING=true \
  --dart-define=API_TIMEOUT_SECONDS=30 \
  --dart-define=CONNECTION_TIMEOUT_SECONDS=15 \
  --web-port=3000

echo ""
echo "📱 Flutter app should now be connected to production!"
echo "🔗 Production API: https://fambridevops.pythonanywhere.com/api"
echo "🌐 Flutter Web: http://localhost:3000 (if web build)"
