// Centralized Application Configuration
// Replaces hardcoded URLs and environment-specific values

class AppConfig {
  // API Endpoints - Environment configurable
  static const String djangoBaseUrl = String.fromEnvironment(
    'DJANGO_URL',
    defaultValue: 'https://fambridevops.pythonanywhere.com/api'
  );
  
  static const String pythonApiUrl = String.fromEnvironment(
    'PYTHON_API_URL',
    defaultValue: 'http://localhost:5001/api'
  );
  
  // WhatsApp Configuration
  static const int whatsappCheckInterval = int.fromEnvironment(
    'WHATSAPP_CHECK_INTERVAL',
    defaultValue: 30  // seconds
  );
  
  static const int whatsappStatusCheckInterval = int.fromEnvironment(
    'WHATSAPP_STATUS_CHECK_INTERVAL',
    defaultValue: 10  // seconds
  );
  
  // API Timeouts
  static const int apiTimeoutSeconds = int.fromEnvironment(
    'API_TIMEOUT_SECONDS',
    defaultValue: 90  // Increased for production stability
  );
  
  static const int connectionTimeoutSeconds = int.fromEnvironment(
    'CONNECTION_TIMEOUT_SECONDS',
    defaultValue: 60  // Increased for backend stability
  );
  
  // Development/Debug Settings
  static const bool enableDebugLogging = bool.fromEnvironment(
    'ENABLE_DEBUG_LOGGING',
    defaultValue: false  // Disabled for production
  );
  
  static const bool enablePerformanceMonitoring = bool.fromEnvironment(
    'ENABLE_PERFORMANCE_MONITORING',
    defaultValue: false
  );
  
  // Feature Flags
  static const bool enableWhatsAppIntegration = bool.fromEnvironment(
    'ENABLE_WHATSAPP_INTEGRATION',
    defaultValue: true
  );
  
  static const bool enableBackgroundProcessing = bool.fromEnvironment(
    'ENABLE_BACKGROUND_PROCESSING',
    defaultValue: true
  );
  
  static const bool enableAdvancedAnalytics = bool.fromEnvironment(
    'ENABLE_ADVANCED_ANALYTICS',
    defaultValue: false
  );
  
  // Pagination and Limits
  static const int defaultPageSize = int.fromEnvironment(
    'DEFAULT_PAGE_SIZE',
    defaultValue: 20
  );
  
  static const int maxBatchSize = int.fromEnvironment(
    'MAX_BATCH_SIZE',
    defaultValue: 100
  );
  
  // Authentication
  static const int tokenRefreshThresholdMinutes = int.fromEnvironment(
    'TOKEN_REFRESH_THRESHOLD_MINUTES',
    defaultValue: 5
  );
  
  static const int sessionTimeoutMinutes = int.fromEnvironment(
    'SESSION_TIMEOUT_MINUTES',
    defaultValue: 480  // 8 hours
  );
  
  // Environment Detection
  static bool get isDevelopment => 
    const String.fromEnvironment('FLUTTER_ENV', defaultValue: 'production') == 'development';
  
  static bool get isProduction => 
    const String.fromEnvironment('FLUTTER_ENV', defaultValue: 'production') == 'production';
  
  static bool get isTesting => 
    const String.fromEnvironment('FLUTTER_ENV', defaultValue: 'production') == 'testing';
  
  // Computed Properties
  static Duration get apiTimeout => Duration(seconds: apiTimeoutSeconds);
  static Duration get connectionTimeout => Duration(seconds: connectionTimeoutSeconds);
  static Duration get whatsappCheckDuration => Duration(seconds: whatsappCheckInterval);
  static Duration get whatsappStatusCheckDuration => Duration(seconds: whatsappStatusCheckInterval);
  static Duration get tokenRefreshThreshold => Duration(minutes: tokenRefreshThresholdMinutes);
  static Duration get sessionTimeout => Duration(minutes: sessionTimeoutMinutes);
  
  // Validation
  static void validateConfiguration() {
    assert(djangoBaseUrl.isNotEmpty, 'Django base URL cannot be empty');
    assert(pythonApiUrl.isNotEmpty, 'Python API URL cannot be empty');
    assert(whatsappCheckInterval > 0, 'WhatsApp check interval must be positive');
    assert(apiTimeoutSeconds > 0, 'API timeout must be positive');
    assert(defaultPageSize > 0, 'Default page size must be positive');
  }
  
  // Debug Information
  static Map<String, dynamic> getDebugInfo() {
    return {
      'environment': isDevelopment ? 'development' : (isProduction ? 'production' : 'testing'),
      'django_url': djangoBaseUrl,
      'python_api_url': pythonApiUrl,
      'whatsapp_check_interval': whatsappCheckInterval,
      'api_timeout': apiTimeoutSeconds,
      'debug_logging': enableDebugLogging,
      'whatsapp_integration': enableWhatsAppIntegration,
      'background_processing': enableBackgroundProcessing,
    };
  }
}

