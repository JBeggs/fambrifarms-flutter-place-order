// Application Constants
// Business logic values, UI constants, and other fixed values

class AppConstants {
  // Business Logic Constants
  static const double defaultVatRate = 0.15;  // 15% VAT
  static const double defaultBaseMarkup = 1.25;  // 25% markup
  static const double defaultVolatilityAdjustment = 0.15;  // 15% volatility buffer
  static const double defaultTrendMultiplier = 1.10;  // 10% trend adjustment
  
  // Message Processing
  static const int maxMessagePreviewLength = 50;
  static const int maxMessageBatchSize = 50;
  static const double minClassificationConfidence = 0.3;
  static const double highClassificationConfidence = 0.7;
  
  // UI Constants
  static const double cardElevation = 2.0;
  static const double borderRadius = 8.0;
  static const double iconSize = 24.0;
  static const double avatarRadius = 20.0;
  
  // Spacing
  static const double spacingXSmall = 4.0;
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 24.0;
  static const double spacingXLarge = 32.0;
  
  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);
  
  // Snackbar and Toast Durations
  static const Duration snackbarDuration = Duration(seconds: 4);
  static const Duration errorSnackbarDuration = Duration(seconds: 6);
  static const Duration successSnackbarDuration = Duration(seconds: 3);
  
  // Form Validation
  static const int minPasswordLength = 6;
  static const int maxPasswordLength = 128;
  static const int minUsernameLength = 3;
  static const int maxUsernameLength = 50;
  
  // File and Data Limits
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB
  static const int maxImageSize = 5 * 1024 * 1024;  // 5MB
  static const int maxTextLength = 5000;
  
  // Pagination and Limits
  static const int defaultPageSize = 20;
  static const int maxBatchSize = 100;
  
  // Retry and Polling
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  static const Duration pollingInterval = Duration(seconds: 30);
  static const Duration statusCheckInterval = Duration(seconds: 10);
  
  // Cache and Storage
  static const Duration cacheExpiration = Duration(hours: 1);
  static const Duration longCacheExpiration = Duration(days: 1);
  static const int maxCacheSize = 100; // Number of items
  
  // Order and Business Constants
  static const List<String> orderDays = ['Monday', 'Tuesday', 'Thursday'];
  static const List<String> deliveryTimeSlots = [
    '08:00-10:00',
    '10:00-12:00', 
    '12:00-14:00',
    '14:00-16:00',
    '16:00-18:00'
  ];
  
  // Message Types
  static const List<String> messageTypes = [
    'order',
    'stock',
    'instruction',
    'demarcation',
    'image',
    'voice',
    'video',
    'document',
    'sticker',
    'other'
  ];
  
  // Customer Types
  static const List<String> customerTypes = [
    'restaurant',
    'hospitality',
    'institution',
    'private',
    'wholesale'
  ];
  
  // Product Categories
  static const List<String> productCategories = [
    'vegetables',
    'fruits',
    'herbs',
    'salads',
    'specialty',
    'organic'
  ];
  
  // Units of Measurement
  static const List<String> units = [
    'kg',
    'g',
    'boxes',
    'heads',
    'bunches',
    'pieces',
    'packets',
    'bags',
    'tubs',
    'trays'
  ];
  
  // Status Values
  static const List<String> orderStatuses = [
    'pending',
    'confirmed',
    'preparing',
    'ready',
    'delivered',
    'cancelled'
  ];
  
  static const List<String> messageProcessingStatuses = [
    'unprocessed',
    'processing',
    'processed',
    'failed',
    'manual_review'
  ];
  
  // Error Messages
  static const String networkErrorMessage = 'Network connection failed. Please check your internet connection.';
  static const String serverErrorMessage = 'Server error occurred. Please try again later.';
  static const String authenticationErrorMessage = 'Authentication failed. Please log in again.';
  static const String validationErrorMessage = 'Please check your input and try again.';
  static const String unknownErrorMessage = 'An unexpected error occurred. Please try again.';
  
  // Success Messages
  static const String loginSuccessMessage = 'Successfully logged in!';
  static const String logoutSuccessMessage = 'Successfully logged out!';
  static const String saveSuccessMessage = 'Changes saved successfully!';
  static const String deleteSuccessMessage = 'Item deleted successfully!';
  static const String processSuccessMessage = 'Processing completed successfully!';
  
  // WhatsApp Specific Constants
  static const String defaultWhatsAppGroup = 'ORDERS Restaurants';
  static const List<String> whatsAppMessageIndicators = [
    '…', '...', '…\n', '...\n'  // Truncation indicators
  ];
  
  static const List<String> orderKeywords = [
    'ORDER', 'NEED', 'WANT', 'REQUIRE', 'REQUEST',
    'KG', 'BOXES', 'HEADS', 'BUNCHES', 'PIECES'
  ];
  
  static const List<String> stockKeywords = [
    'STOCK', 'AVAILABLE', 'INVENTORY', 'SUPPLY', 'STOKE'
  ];
  
  static const List<String> instructionKeywords = [
    'GOOD MORNING', 'HELLO', 'THANKS', 'PLEASE', 'NOTE'
  ];
  
  // Regular Expressions (as strings for Dart)
  static const String emailRegex = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
  static const String phoneRegex = r'^\+?[1-9]\d{1,14}$';
  static const String quantityRegex = r'\d+\s*(kg|box|head|bunch|pcs|pieces|pkts|packets)';
  static const String timestampRegex = r'^\d{1,2}:\d{2}$';
  
  // Feature Flags (can be overridden by AppConfig)
  static const bool enableOfflineMode = false;
  static const bool enablePushNotifications = true;
  static const bool enableAnalytics = false;
  static const bool enableCrashReporting = false;
  
  // Development and Debug
  static const bool showDebugInfo = false;
  static const bool enablePerformanceProfiling = false;
  static const bool mockApiCalls = false;
  
  // Validation Helpers
  static bool isValidEmail(String email) {
    return RegExp(emailRegex).hasMatch(email);
  }
  
  static bool isValidPhone(String phone) {
    return RegExp(phoneRegex).hasMatch(phone);
  }
  
  static bool isValidQuantity(String text) {
    return RegExp(quantityRegex, caseSensitive: false).hasMatch(text);
  }
  
  static bool isTimestamp(String text) {
    return RegExp(timestampRegex).hasMatch(text);
  }
  
  // Utility Methods
  static String truncateText(String text, {int maxLength = maxMessagePreviewLength}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
  
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  
  static Duration getRetryDelay(int attemptNumber) {
    // Exponential backoff: 2s, 4s, 8s, etc.
    return Duration(seconds: retryDelay.inSeconds * (1 << (attemptNumber - 1)));
  }
}

