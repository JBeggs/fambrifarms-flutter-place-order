// Simple test to verify environment variables are being read
void main() {
  print('🔧 Environment Variable Test:');
  print('FLUTTER_ENV: ${const String.fromEnvironment('FLUTTER_ENV', defaultValue: 'NOT_SET')}');
  print('DJANGO_URL: ${const String.fromEnvironment('DJANGO_URL', defaultValue: 'NOT_SET')}');
  print('PYTHON_API_URL: ${const String.fromEnvironment('PYTHON_API_URL', defaultValue: 'NOT_SET')}');
  print('API_TIMEOUT_SECONDS: ${const String.fromEnvironment('API_TIMEOUT_SECONDS', defaultValue: 'NOT_SET')}');
  print('ENABLE_DEBUG_LOGGING: ${const String.fromEnvironment('ENABLE_DEBUG_LOGGING', defaultValue: 'NOT_SET')}');
}
