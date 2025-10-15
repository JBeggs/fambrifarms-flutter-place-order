@echo off
REM Flutter Local Development Script
REM Connects Flutter app to local Django backend

echo 🚀 Starting Flutter app with LOCAL backend configuration...
echo 📡 Django API: http://localhost:8080/api
echo 🔧 Environment: development
echo.

REM Run Flutter with local backend configuration
flutter run ^
  --dart-define=DJANGO_URL=http://localhost:8080/api ^
  --dart-define=PYTHON_API_URL=http://localhost:8080/api ^
  --dart-define=FLUTTER_ENV=development ^
  --dart-define=ENABLE_DEBUG_LOGGING=true ^
  --dart-define=API_TIMEOUT_SECONDS=60 ^
  --web-port=3000
